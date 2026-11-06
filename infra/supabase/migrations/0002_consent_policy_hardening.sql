-- Fix patient consent grantee validation without relying on caller-visible RLS rows.
-- Apply after 0001_staging_core.sql.
create or replace function public.is_valid_consent_grantee(
  p_patient uuid, p_grantee uuid, p_scope text
) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.patient_access a
    join public.profiles pr on pr.id = a.user_id
    where a.patient_id = p_patient
      and a.user_id = p_grantee
      and a.active
      and (
        p_scope <> 'confidential_record'
        or (a.access_role = 'doctor' and pr.role = 'doctor')
      )
      and (
        p_scope <> 'lab_results'
        or a.access_role in ('doctor','laboratory')
      )
  )
$$;

drop policy if exists consents_owner_insert on public.patient_consents;
create policy consents_owner_insert
on public.patient_consents
for insert to authenticated
with check (
  public.is_patient_owner(patient_id)
  and public.is_valid_consent_grantee(patient_id, grantee_user_id, scope)
);

-- Patients may revoke consent. A new grant must pass the insert policy.
drop policy if exists consents_owner_update on public.patient_consents;
create policy consents_owner_revoke
on public.patient_consents
for update to authenticated
using (public.is_patient_owner(patient_id))
with check (
  public.is_patient_owner(patient_id)
  and granted = false
  and revoked_at is not null
);

-- Avoid exposing function execution to anonymous users.
revoke all on function public.is_valid_consent_grantee(uuid, uuid, text) from public;
grant execute on function public.is_valid_consent_grantee(uuid, uuid, text) to authenticated;
