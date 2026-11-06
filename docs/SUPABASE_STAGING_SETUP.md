# Supabase staging setup

1. Create a separate Supabase project named `rxbridge-staging`; do not reuse production credentials.
2. Select the closest available region only after network tests from several Iranian ISPs. The project must contain synthetic data only.
3. Open SQL Editor and apply `infra/supabase/migrations/0001_staging_core.sql` to a fresh project.
4. Create test users through Supabase Auth dashboard. Add matching `public.profiles` rows with approved roles. Never expose the service_role key in the client.
5. For a patient test account, set `patients.auth_user_id` to that Auth user's UUID. Create `patient_access` rows to explicitly link a doctor/lab user to a synthetic patient. A doctor needs an active access row and an active patient consent for the requested scope.
6. Configure a test build using only the project URL and anon/publishable key:
   ```bash
   flutter build apk --debug \
     --dart-define=RXBRIDGE_BACKEND=supabaseStaging \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
   ```
7. Verify Auth, patient isolation and consent policies with separate patient and doctor accounts before inviting testers.

## Important current limitations
- This is a staging foundation, not a complete clinical system.
- Flutter app initializes Supabase when selected, but existing role dashboards and care screens have not yet been refactored to call the repositories. Do not claim all app data is cloud-synced.
- The current Supabase adapter covers authentication, patient reads, lab-order reads/writes and glucose reading reads/writes. DTOs and database columns are intentionally provider-neutral.
- Profiles/role provisioning and patient-access/consent workflows must be completed through a trusted administrative process. Never let a client self-assign a privileged role.
- Confidential payload encryption/key management, audited consent changes, full audit event writing, realtime, storage adapter, full prescription/pharmacy/insurance repositories, Iranian REST adapter and migration automation remain outstanding.
- SQL policies are a starting point and require independent security review and adversarial tests before any external access. Synthetic records only.
