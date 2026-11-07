-- RxBridge staging prescriptions, synthetic records only.
-- Requires 0001_staging_core.sql and 0002_consent_policy_hardening.sql.
create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  doctor_id uuid not null references public.profiles(id),
  pharmacy_id uuid references public.profiles(id),
  medicine_name text not null check (length(trim(medicine_name)) between 1 and 150),
  pharmaceutical_form text not null check (length(trim(pharmaceutical_form)) between 1 and 60),
  dose_label text not null check (length(trim(dose_label)) between 1 and 80),
  frequency_label text not null check (length(trim(frequency_label)) between 1 and 80),
  duration_label text not null check (length(trim(duration_label)) between 1 and 80),
  instructions text not null default '' check (length(instructions) <= 500),
  quantity integer not null check (quantity between 1 and 1000),
  status text not null default 'sent' check (status in ('sent','dispensed','unavailable')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists prescriptions_patient_idx on public.prescriptions(patient_id, created_at desc);
create index if not exists prescriptions_pharmacy_idx on public.prescriptions(pharmacy_id, created_at desc);

alter table public.prescriptions enable row level security;

-- Supabase projects may grant broad table UPDATE privileges by default.
-- Limit authenticated clients to status changes, not prescription contents.
revoke update on public.prescriptions from anon, authenticated;
grant update(status) on public.prescriptions to authenticated;

create policy prescriptions_authorized_read on public.prescriptions
for select to authenticated using (
  public.is_patient_owner(patient_id)
  or (
    doctor_id = auth.uid()
    and public.has_patient_access(patient_id, array['doctor'])
    and public.has_patient_consent(patient_id, 'clinical_record')
  )
  or (
    pharmacy_id = auth.uid()
    and public.has_patient_access(patient_id, array['pharmacist'])
    and public.has_patient_consent(patient_id, 'clinical_record')
  )
);

create policy prescriptions_doctor_insert on public.prescriptions
for insert to authenticated with check (
  doctor_id = auth.uid()
  and status = 'sent'
  and public.has_patient_access(patient_id, array['doctor'])
  and public.has_patient_consent(patient_id, 'clinical_record')
  and exists (
    select 1 from public.profiles pr
    where pr.id=auth.uid() and pr.role='doctor'
  )
  and (
    pharmacy_id is null
    or exists (
      select 1 from public.patient_access a
      join public.profiles pr on pr.id=a.user_id
      where a.patient_id=prescriptions.patient_id
        and a.user_id=prescriptions.pharmacy_id
        and a.access_role='pharmacist' and a.active and pr.role='pharmacist'
    )
  )
);

create policy prescriptions_pharmacist_status_update on public.prescriptions
for update to authenticated
using (
  pharmacy_id = auth.uid()
  and status = 'sent'
  and public.has_patient_access(patient_id, array['pharmacist'])
  and public.has_patient_consent(patient_id, 'clinical_record')
  and exists (select 1 from public.profiles pr where pr.id=auth.uid() and pr.role='pharmacist')
)
with check (
  pharmacy_id = auth.uid()
  and status in ('dispensed','unavailable')
  and public.has_patient_access(patient_id, array['pharmacist'])
  and public.has_patient_consent(patient_id, 'clinical_record')
);

-- No automatic dispensing decisions; statuses are only manual demo entries.
