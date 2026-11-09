-- Physician-prescribed healthy-habit plans and patient self-reported adherence.
-- Synthetic staging only. Apply after migrations 0001-0003.
create table if not exists public.habit_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  doctor_id uuid not null references public.profiles(id),
  title text not null check (length(trim(title)) between 2 and 120),
  habit_type text not null check (habit_type in ('activity','hydration','nutrition','sleep','measurement','other')),
  instruction text not null check (length(trim(instruction)) between 2 and 1000),
  unit_label text not null check (length(trim(unit_label)) between 1 and 40),
  target_min numeric(12,3),
  target_max numeric(12,3),
  target_description text not null default '' check (length(target_description) <= 300),
  frequency_per_day integer not null default 1 check (frequency_per_day between 1 and 24),
  active_days text[] not null default array['sat','sun','mon','tue','wed','thu','fri'],
  starts_at date not null default current_date,
  ends_at date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (target_min is null or target_max is null or target_min <= target_max),
  check (ends_at is null or ends_at >= starts_at)
);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.habit_plans(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  reported_by uuid not null references public.profiles(id),
  measured_value numeric(12,3),
  completed boolean not null default true,
  note text not null default '' check (length(note) <= 500),
  occurred_at timestamptz not null default now(),
  range_result text not null default 'pending' check (range_result in ('pending','within_range','outside_range','not_applicable')),
  points_awarded integer not null default 0 check (points_awarded between 0 and 1),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  doctor_feedback text not null default '' check (length(doctor_feedback) <= 1000),
  created_at timestamptz not null default now()
);

create index if not exists habit_plans_patient_idx on public.habit_plans(patient_id, active, starts_at);
create index if not exists habit_logs_plan_time_idx on public.habit_logs(plan_id, occurred_at desc);

alter table public.habit_plans enable row level security;
alter table public.habit_logs enable row level security;

create policy habit_plans_patient_doctor_read on public.habit_plans
for select to authenticated using (
  public.is_patient_owner(patient_id)
  or (doctor_id=auth.uid() and public.has_patient_access(patient_id,array['doctor'])
      and public.has_patient_consent(patient_id,'clinical_record'))
);
create policy habit_plans_doctor_insert on public.habit_plans
for insert to authenticated with check (
  doctor_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='doctor')
  and public.has_patient_access(patient_id,array['doctor'])
  and public.has_patient_consent(patient_id,'clinical_record')
);
create policy habit_plans_doctor_update on public.habit_plans
for update to authenticated using (
  doctor_id=auth.uid()
  and public.has_patient_access(patient_id,array['doctor'])
  and public.has_patient_consent(patient_id,'clinical_record')
) with check (
  doctor_id=auth.uid()
  and public.has_patient_access(patient_id,array['doctor'])
  and public.has_patient_consent(patient_id,'clinical_record')
);

create policy habit_logs_patient_doctor_read on public.habit_logs
for select to authenticated using (
  public.is_patient_owner(patient_id)
  or exists (
    select 1 from public.habit_plans hp
    where hp.id=habit_logs.plan_id and hp.doctor_id=auth.uid()
      and public.has_patient_access(hp.patient_id,array['doctor'])
      and public.has_patient_consent(hp.patient_id,'clinical_record')
  )
);
create policy habit_logs_patient_insert on public.habit_logs
for insert to authenticated with check (
  reported_by=auth.uid()
  and public.is_patient_owner(patient_id)
  and exists (
    select 1 from public.habit_plans hp
    where hp.id=habit_logs.plan_id and hp.patient_id=habit_logs.patient_id and hp.active
      and current_date between hp.starts_at and coalesce(hp.ends_at,'infinity'::date)
  )
  and range_result='pending'
  and points_awarded=0
  and reviewed_by is null
  and reviewed_at is null
  and doctor_feedback=''
);
-- Only the prescribing doctor can review, award the adherence point, or send guidance.
create policy habit_logs_doctor_review on public.habit_logs
for update to authenticated using (
  exists (
    select 1 from public.habit_plans hp
    where hp.id=habit_logs.plan_id and hp.doctor_id=auth.uid()
      and public.has_patient_access(hp.patient_id,array['doctor'])
      and public.has_patient_consent(hp.patient_id,'clinical_record')
  )
) with check (
  exists (
    select 1 from public.habit_plans hp
    where hp.id=habit_logs.plan_id and hp.doctor_id=auth.uid()
      and public.has_patient_access(hp.patient_id,array['doctor'])
      and public.has_patient_consent(hp.patient_id,'clinical_record')
  )
  and reviewed_by=auth.uid()
  and reviewed_at is not null
  and points_awarded = case when range_result='within_range' then 1 else 0 end
);

-- Prevent patient clients from forging the computed score or doctor review fields.
revoke update on public.habit_logs from anon, authenticated;
-- Review fields are writable only through the SECURITY DEFINER review_habit_log function.
-- Authenticated clients receive no direct UPDATE privilege on habit_logs.
-- Trigger computes the range classification and score only from physician-authored plan thresholds.
create or replace function public.compute_habit_log_result()
returns trigger language plpgsql set search_path = ''
as $$
begin
  -- Patient-submitted values are never trusted to assign scores or a clinical status.
  -- The prescribing doctor reviews and classifies every submission explicitly.
  new.range_result := 'pending';
  new.points_awarded := 0;
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.doctor_feedback := '';
  return new;
end $$;
drop trigger if exists habit_log_compute_result on public.habit_logs;
create trigger habit_log_compute_result before insert on public.habit_logs
for each row execute function public.compute_habit_log_result();

-- Review function recalculates from the stored doctor-authored plan limits; patients cannot call it.
create or replace function public.review_habit_log(
  p_log_id uuid, p_feedback text default ''
) returns void language plpgsql security definer set search_path = ''
as $$
declare hp public.habit_plans%rowtype; lg public.habit_logs%rowtype; outside_target boolean;
begin
  select * into lg from public.habit_logs where id=p_log_id;
  if not found then raise exception 'Habit log not found'; end if;
  select * into hp from public.habit_plans where id=lg.plan_id;
  if hp.doctor_id <> auth.uid()
    or not public.has_patient_access(hp.patient_id,array['doctor'])
    or not public.has_patient_consent(hp.patient_id,'clinical_record') then
    raise exception 'Not authorized to review this habit log';
  end if;
  outside_target := not lg.completed or (lg.measured_value is not null and
    ( (hp.target_min is not null and lg.measured_value < hp.target_min)
      or (hp.target_max is not null and lg.measured_value > hp.target_max) ));
  if outside_target and length(trim(coalesce(p_feedback,''))) = 0 then
    raise exception 'Doctor feedback is required when the reported habit is outside the prescribed range';
  end if;
  update public.habit_logs set
    range_result = case
      when not lg.completed then 'outside_range'
      when lg.measured_value is null or (hp.target_min is null and hp.target_max is null) then 'not_applicable'
      when (hp.target_min is null or lg.measured_value >= hp.target_min)
       and (hp.target_max is null or lg.measured_value <= hp.target_max) then 'within_range'
      else 'outside_range' end,
    points_awarded = case
      when lg.completed and lg.measured_value is not null
       and (hp.target_min is not null or hp.target_max is not null)
       and (hp.target_min is null or lg.measured_value >= hp.target_min)
       and (hp.target_max is null or lg.measured_value <= hp.target_max) then 1 else 0 end,
    reviewed_by=auth.uid(), reviewed_at=now(), doctor_feedback=left(coalesce(p_feedback,''),1000)
  where id=p_log_id;
end $$;
revoke all on function public.review_habit_log(uuid,text) from public;
grant execute on function public.review_habit_log(uuid,text) to authenticated;
revoke all on function public.compute_habit_log_result() from public;
