# RxBridge Presentation Staging (synthetic-only)

## Purpose
The offline localDemo mode is a separate in-app presentation. The Supabase staging mode is
**authenticated**, and shows only data permitted by PostgreSQL RLS. Neither is suitable for
clinical care or real patient information.

## Setup (in order)
1. In the isolated Supabase staging project, run migrations:
   - `infra/supabase/migrations/0001_staging_core.sql`
   - `infra/supabase/migrations/0002_consent_policy_hardening.sql`
   - `infra/supabase/migrations/0003_prescriptions_staging.sql`
2. In Supabase Authentication > Users, create five **synthetic** email/password users:
   - `doctor01@rxbridge.test`
   - `patient01@rxbridge.test`
   - `pharmacy01@rxbridge.test`
   - `insurer01@rxbridge.test`
   - `lab01@rxbridge.test`
   Avoid reusing personal passwords. For Auth users, confirm email in the test project when needed.
3. Run `infra/supabase/seeds/0001_presentation_demo.sql` in SQL Editor.
   It fails without the five accounts and only inserts synthetic staging records.
   The sample clinical consent is only a pre-authorized test fixture; actual consent
   handling remains under development.
4. Get the **Project URL** and **publishable key** from Supabase project settings.
   NEVER distribute service_role, database password, JWT secret, or admin token.
5. Build a separate authenticated staging app:
   ```sh
   cd apps/mobile
   flutter run --dart-define=RXBRIDGE_BACKEND=supabaseStaging \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
   ```
   The public key is only safe alongside tested RLS.
6. Log in as doctor; select the synthetic patient. The staging doctor form
   currently takes a pharmacist **UUID** (from the seed's final SELECT),
   not the pharmacy username.
7. Log in from another device as pharmacist; refresh authorized prescriptions;
   mark 'dispensed' or 'unavailable'. The doctor and patient accounts can refresh
   and see the updated status.

## Important boundaries
- Offline demo mode has its own synthetic in-memory prescription store.
- The staging portal never falls back to offline demo on initialization failure.
- The staging UI currently supports prescriptions only for doctor/patient/pharmacist.
  Laboratory, glucose and insurer staging screens are not yet connected.
- The schema is for one drug item per demo prescription; no prescribing guidance.
- Do not give access to live patients or clinicians until authorization, data
  encryption, audit trail, storage, and formal risk review are completed.
- Retest project connectivity on the intended Iran-based network before presenting.

## Verification checklist
- RLS on all staging tables, including `prescriptions`.
- Unauthenticated users cannot list prescriptions.
- Different accounts cannot read another patient's prescriptions.
- Pharmacist cannot change drug, dose, doctor, patient or quantity.
- No doctor can prescribe for a patient without a recorded active relationship
  and clinical_record consent.
- The current CI workflow validates code/builds with local demo configuration;
  staging sign-in and RLS still require a real integration test against the
  configured staging project.
