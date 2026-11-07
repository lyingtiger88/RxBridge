-- RxBridge presentation seed: synthetic data only.
-- Prerequisite: create these 5 Auth users via Authentication > Users first.
-- doctor01@rxbridge.test, patient01@rxbridge.test,
-- pharmacy01@rxbridge.test, insurer01@rxbridge.test, lab01@rxbridge.test
-- Run in SQL Editor after migration 0003. NEVER run against real patient data.
do $$
declare
  doctor_uid uuid;
  patient_uid uuid;
  pharmacy_uid uuid;
  insurer_uid uuid;
  lab_uid uuid;
  sample_patient uuid;
begin
  select id into doctor_uid from auth.users where email='doctor01@rxbridge.test';
  select id into patient_uid from auth.users where email='patient01@rxbridge.test';
  select id into pharmacy_uid from auth.users where email='pharmacy01@rxbridge.test';
  select id into insurer_uid from auth.users where email='insurer01@rxbridge.test';
  select id into lab_uid from auth.users where email='lab01@rxbridge.test';
  if doctor_uid is null or patient_uid is null or pharmacy_uid is null
      or insurer_uid is null or lab_uid is null then
    raise exception 'First create all 5 synthetic Auth accounts in Supabase Authentication.';
  end if;

  insert into public.profiles (id,role,display_name) values
    (doctor_uid,'doctor','پزشک آزمایشی'),
    (patient_uid,'patient','بیمار آزمایشی'),
    (pharmacy_uid,'pharmacist','داروساز آزمایشی'),
    (insurer_uid,'insurer','کارشناس بیمه آزمایشی'),
    (lab_uid,'laboratory','آزمایشگاه آزمایشی')
  on conflict (id) do update set role=excluded.role,display_name=excluded.display_name;

  insert into public.patients (auth_user_id,display_code,display_name)
  values (patient_uid,'RXBRIDGE-PRESENTATION-001','بیمار آزمایشی')
  on conflict (display_code) do update
  set auth_user_id=excluded.auth_user_id,display_name=excluded.display_name
  returning id into sample_patient;

  insert into public.patient_access (patient_id,user_id,access_role,active)
  values
    (sample_patient,doctor_uid,'doctor',true),
    (sample_patient,pharmacy_uid,'pharmacist',true)
  on conflict (patient_id,user_id,access_role) do update set active=true;

  insert into public.patient_consents
    (patient_id,grantee_user_id,scope,granted)
  select sample_patient,doctor_uid,'clinical_record',true
  where not exists (
    select 1 from public.patient_consents
    where patient_id=sample_patient and grantee_user_id=doctor_uid and scope='clinical_record'
  );
  insert into public.patient_consents
    (patient_id,grantee_user_id,scope,granted)
  select sample_patient,pharmacy_uid,'clinical_record',true
  where not exists (
    select 1 from public.patient_consents
    where patient_id=sample_patient and grantee_user_id=pharmacy_uid and scope='clinical_record'
  );

  raise notice 'Synthetic presentation patient: %, pharmacist UUID: %',sample_patient,pharmacy_uid;
end $$;

-- Copy the pharmacist_id from the result into the doctor's staging form.
select p.role, p.display_name, p.id
from public.profiles p
where p.role in ('doctor','patient','pharmacist','insurer','laboratory')
order by p.role;
