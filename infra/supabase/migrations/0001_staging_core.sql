-- RxBridge portable staging schema (PostgreSQL). Synthetic records only.
-- Apply to a NEW Supabase staging project. Never expose service_role credentials to clients.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','doctor','patient','pharmacist','insurer','laboratory')),
  display_name text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_code text unique not null,
  display_name text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.patient_access (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  access_role text not null check (access_role in ('doctor','laboratory','pharmacist','insurer')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(patient_id,user_id,access_role)
);
create table if not exists public.patient_consents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  grantee_user_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null check (scope in ('clinical_record','confidential_record','lab_results')),
  granted boolean not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);
create table if not exists public.confidential_records (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null unique references public.patients(id) on delete cascade,
  encrypted_payload text not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.lab_orders (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  ordered_by uuid not null references public.profiles(id),
  assigned_lab_id uuid references public.profiles(id),
  test_code text not null,
  scheduled_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','collected','reported','cancelled')),
  created_at timestamptz not null default now()
);
create table if not exists public.glucose_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  value_mg_dl integer not null check (value_mg_dl between 1 and 1000),
  measured_at timestamptz not null,
  context text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id),
  patient_id uuid references public.patients(id),
  action text not null,
  resource_type text not null,
  resource_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists patient_access_user_idx on public.patient_access(user_id,patient_id) where active;
create index if not exists lab_orders_patient_time_idx on public.lab_orders(patient_id,scheduled_at desc);
create index if not exists glucose_patient_time_idx on public.glucose_readings(patient_id,measured_at desc);

create or replace function public.has_patient_access(p_patient uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (
   select 1 from public.patient_access a
   where a.patient_id = p_patient and a.user_id = auth.uid() and a.active
     and (p_roles is null or a.access_role = any(p_roles))
 )
$$;
create or replace function public.has_patient_consent(p_patient uuid, p_scope text)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (
   select 1 from public.patient_consents c
   where c.patient_id = p_patient and c.grantee_user_id = auth.uid()
     and c.scope = p_scope and c.granted and c.revoked_at is null
 )
$$;
create or replace function public.is_patient_owner(p_patient uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (select 1 from public.patients p where p.id=p_patient and p.auth_user_id=auth.uid())
$$;

alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.patient_access enable row level security;
alter table public.patient_consents enable row level security;
alter table public.confidential_records enable row level security;
alter table public.lab_orders enable row level security;
alter table public.glucose_readings enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using (id=auth.uid());
create policy patients_owner_or_assigned_read on public.patients for select to authenticated
using (auth_user_id=auth.uid() or (public.has_patient_access(id,array['doctor','laboratory','pharmacist','insurer']) and public.has_patient_consent(id,'clinical_record')));
create policy access_self_read on public.patient_access for select to authenticated using (user_id=auth.uid());
create policy consents_owner_or_grantee_read on public.patient_consents for select to authenticated
using (public.is_patient_owner(patient_id) or grantee_user_id=auth.uid());
create policy consents_owner_insert on public.patient_consents for insert to authenticated
with check (public.is_patient_owner(patient_id) and grantee_user_id in (
  select a.user_id from public.patient_access a where a.patient_id=patient_consents.patient_id and a.active
));
create policy consents_owner_update on public.patient_consents for update to authenticated
using (public.is_patient_owner(patient_id)) with check (public.is_patient_owner(patient_id));
create policy confidential_owner_or_consented_doctor_read on public.confidential_records for select to authenticated
using (public.is_patient_owner(patient_id) or (public.has_patient_access(patient_id,array['doctor']) and public.has_patient_consent(patient_id,'confidential_record')));
create policy lab_orders_authorized_read on public.lab_orders for select to authenticated
using (public.is_patient_owner(patient_id) or ordered_by=auth.uid() or assigned_lab_id=auth.uid() or (public.has_patient_access(patient_id,array['doctor']) and public.has_patient_consent(patient_id,'lab_results')));
create policy lab_orders_doctor_insert on public.lab_orders for insert to authenticated
with check (ordered_by=auth.uid() and public.has_patient_access(patient_id,array['doctor']));
create policy glucose_owner_or_consented_doctor_read on public.glucose_readings for select to authenticated
using (public.is_patient_owner(patient_id) or (public.has_patient_access(patient_id,array['doctor']) and public.has_patient_consent(patient_id,'clinical_record')));
create policy glucose_patient_insert on public.glucose_readings for insert to authenticated
with check (public.is_patient_owner(patient_id));
create policy audit_actor_read on public.audit_events for select to authenticated using (actor_user_id=auth.uid());
-- No client write policy for audit_events: append through trusted server-side function only.
