-- Pharmacy discovery, geolocation, inventory and transparent price comparison.
-- Synthetic staging only. Coordinates are opt-in; never expose patient coordinates in result rows.
-- Apply after migrations 0001-0005.

create table if not exists public.pharmacies (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references public.profiles(id) on delete cascade,
  pharmacy_name text not null check (length(trim(pharmacy_name)) between 2 and 160),
  license_number text,
  address text not null check (length(trim(address)) between 3 and 500),
  city text not null check (length(trim(city)) between 2 and 100),
  province text not null check (length(trim(province)) between 2 and 100),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  location_verified boolean not null default false,
  is_published boolean not null default false,
  accepts_reservations boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pharmacy_inventory (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  medicine_key text not null check (length(trim(medicine_key)) between 2 and 180),
  medicine_name text not null check (length(trim(medicine_name)) between 2 and 180),
  pharmaceutical_form text not null check (length(trim(pharmaceutical_form)) between 1 and 80),
  strength text not null default '',
  package_label text not null default '',
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  unit_price_irr bigint not null check (unit_price_irr >= 0),
  price_updated_at timestamptz not null default now(),
  stock_updated_at timestamptz not null default now(),
  is_listed boolean not null default true,
  unique(pharmacy_id, medicine_key, pharmaceutical_form, strength, package_label)
);

create index if not exists pharmacies_public_geo_idx
  on public.pharmacies(is_published, city, province);
create index if not exists pharmacy_inventory_match_idx
  on public.pharmacy_inventory(medicine_key, pharmaceutical_form, is_listed);
create index if not exists pharmacy_inventory_pharmacy_idx
  on public.pharmacy_inventory(pharmacy_id);

alter table public.pharmacies enable row level security;
alter table public.pharmacy_inventory enable row level security;

create policy pharmacies_public_directory_read on public.pharmacies
for select to authenticated using (is_published or owner_user_id=auth.uid());
create policy pharmacies_owner_insert on public.pharmacies
for insert to authenticated with check (
  owner_user_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='pharmacist')
);
create policy pharmacies_owner_update on public.pharmacies
for update to authenticated using (owner_user_id=auth.uid())
with check (owner_user_id=auth.uid());

create policy pharmacy_inventory_public_read on public.pharmacy_inventory
for select to authenticated using (
  is_listed and exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.is_published)
  or exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.owner_user_id=auth.uid())
);
create policy pharmacy_inventory_owner_insert on public.pharmacy_inventory
for insert to authenticated with check (
  exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.owner_user_id=auth.uid())
);
create policy pharmacy_inventory_owner_update on public.pharmacy_inventory
for update to authenticated using (
  exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.owner_user_id=auth.uid())
) with check (
  exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.owner_user_id=auth.uid())
);
create policy pharmacy_inventory_owner_delete on public.pharmacy_inventory
for delete to authenticated using (
  exists(select 1 from public.pharmacies ph where ph.id=pharmacy_id and ph.owner_user_id=auth.uid())
);

-- Patient coordinates are supplied only to the matching RPC and are not persisted.
-- Results disclose pharmacy location, coverage and prices, never the patient's coordinates.
create or replace function public.find_pharmacies_for_prescriptions(
  p_patient_id uuid,
  p_prescription_ids uuid[],
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 20
)
returns table (
  pharmacy_id uuid,
  pharmacy_name text,
  address text,
  city text,
  province text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  total_items integer,
  available_items integer,
  coverage_percent integer,
  fully_available boolean,
  available_subtotal_irr bigint,
  complete_basket_total_irr bigint,
  prices_last_updated_at timestamptz,
  inventory_last_updated_at timestamptz,
  accepts_reservations boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_patient_owner(p_patient_id) then
    raise exception 'Only the patient can search pharmacies for this prescription';
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'Invalid search coordinates';
  end if;
  if p_radius_km <= 0 or p_radius_km > 100 then
    raise exception 'Search radius must be between 0 and 100 km';
  end if;
  if coalesce(array_length(p_prescription_ids,1),0)=0 then
    raise exception 'Select at least one prescription';
  end if;
  if exists (
    select 1 from unnest(p_prescription_ids) requested(id)
    where not exists (
      select 1 from public.prescriptions rx
      where rx.id=requested.id and rx.patient_id=p_patient_id and rx.status='sent'
    )
  ) then
    raise exception 'Prescription selection is invalid or no longer active';
  end if;

  return query
  with requested as (
    select rx.id, lower(trim(rx.medicine_name)) as medicine_key,
      lower(trim(rx.pharmaceutical_form)) as form_key, rx.quantity
    from public.prescriptions rx
    where rx.id=any(p_prescription_ids) and rx.patient_id=p_patient_id and rx.status='sent'
  ),
  candidates as (
    select ph.id, ph.pharmacy_name, ph.address, ph.city, ph.province,
      ph.latitude, ph.longitude, ph.accepts_reservations,
      (6371.0 * 2 * asin(sqrt(
        power(sin(radians(ph.latitude-p_latitude)/2),2)
        + cos(radians(p_latitude))*cos(radians(ph.latitude))
        * power(sin(radians(ph.longitude-p_longitude)/2),2)
      ))) as distance,
      count(r.id)::integer as item_count,
      count(i.id) filter (where i.id is not null and i.stock_quantity>=r.quantity)::integer as available_count,
      coalesce(sum(i.unit_price_irr*r.quantity) filter (where i.id is not null and i.stock_quantity>=r.quantity),0)::bigint as subtotal,
      max(i.price_updated_at) as price_updated,
      max(i.stock_updated_at) as stock_updated,
      coalesce(bool_and(i.id is not null and i.stock_quantity>=r.quantity),false) as all_available,
      coalesce(sum(i.unit_price_irr*r.quantity) filter (where i.id is not null and i.stock_quantity>=r.quantity),0)::bigint as complete_total
    from public.pharmacies ph
    cross join requested r
    left join public.pharmacy_inventory i
      on i.pharmacy_id=ph.id and i.is_listed
      and lower(trim(i.medicine_key))=r.medicine_key
      and lower(trim(i.pharmaceutical_form))=r.form_key
    where ph.is_published
    group by ph.id,ph.pharmacy_name,ph.address,ph.city,ph.province,
      ph.latitude,ph.longitude,ph.accepts_reservations
  )
  select c.id,c.pharmacy_name,c.address,c.city,c.province,c.latitude,c.longitude,
    round(c.distance::numeric,2)::double precision,
    c.item_count,c.available_count,
    round(100.0*c.available_count/nullif(c.item_count,0))::integer,
    c.all_available,c.subtotal,
    case when c.all_available then c.complete_total else null end,
    c.price_updated,c.stock_updated,c.accepts_reservations
  from candidates c
  where c.distance<=p_radius_km
  order by c.all_available desc,
    c.available_count desc,
    case when c.all_available then c.complete_total else null end asc nulls last,
    c.distance asc;
end;
$$;

revoke all on function public.find_pharmacies_for_prescriptions(uuid,uuid[],double precision,double precision,double precision) from public;
grant execute on function public.find_pharmacies_for_prescriptions(uuid,uuid[],double precision,double precision,double precision) to authenticated;

-- A published pharmacy must have verified location and complete public identity/address.
create or replace function public.guard_pharmacy_publication()
returns trigger language plpgsql set search_path=''
as $$
begin
  if new.is_published and (not new.location_verified or trim(new.address)='' or trim(new.pharmacy_name)='') then
    raise exception 'Verify pharmacy location and complete its address before publishing';
  end if;
  new.updated_at=now();
  return new;
end $$;
drop trigger if exists pharmacies_publication_guard on public.pharmacies;
create trigger pharmacies_publication_guard before insert or update on public.pharmacies
for each row execute function public.guard_pharmacy_publication();
