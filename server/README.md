# RxBridge Staging Backend
Synthetic test data only. Not for clinical use.

## Local run
1. Copy .env.example to .env and replace every secret with unique random values.
2. Start: docker compose up --build -d
3. Seed accounts by running: docker compose exec api python -m app.seed
4. Health: curl http://127.0.0.1:8000/health
5. API docs: http://127.0.0.1:8000/docs (local only)

Accounts: admin01, doctor01, doctor02, patient01, patient02, pharmacy01, insurer01, lab01. One unique DEMO_SEED_PASSWORD is used for initial seed; rotate before inviting testers.

## Oracle Always Free
Create a Free Tier tenancy; choose an ARM Ampere A1 Ubuntu 24.04 VM within current Always Free quota. Verify linux/arm64 image compatibility. Restrict SSH to admin IPs; expose only 80/443; never expose PostgreSQL 5432. Put Caddy/Nginx in front for TLS, bind API to localhost, keep DB on private Docker network. Configure firewall, security updates, off-instance encrypted backups and monitoring. Check regional capacity and test DNS/TLS/latency from multiple Iranian ISPs before choosing region. Free compute has no SLA and availability may vary.

## Pharmacy network API

The pharmacy-network and reservation schemas are created automatically on a fresh Docker volume. For an existing database, apply both migrations once, in order:

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/002_pharmacy_network.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/003_pharmacy_reservations.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/004_pharmacy_audit.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/005_pharmacy_orders.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/006_reservation_expiry.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/007_app_notifications.sql`

`docker compose exec -T db psql -U rxbridge -d rxbridge < db/008_supabase_auth_identity.sql`

Authenticated pharmacist endpoints: `GET/PUT /v1/pharmacies/me` and `PUT /v1/pharmacies/me/inventory`. Admin review: `GET /v1/admin/pharmacies/pending`; verification: `PATCH /v1/admin/pharmacies/{pharmacy_id}/verification`. After verification, the pharmacist controls publication through `PATCH /v1/pharmacies/me/publication`. Patient matching: `POST /v1/pharmacies/search` with GPS coordinates and exact prescription item details. Matching is strict on medicine, dosage form, strength and package; substitutions are never automatic. Only verified and published pharmacies are searchable. Partial basket subtotals are returned separately and never represented as a complete prescription total. Reservation endpoints: `POST /v1/pharmacies/{pharmacy_id}/reservations` (patient, requires a client-generated UUID idempotency key), `GET /v1/pharmacies/reservations/me` (patient), `GET /v1/pharmacies/me/reservations` (pharmacist), `POST /v1/pharmacies/reservations/{reservation_id}/confirm` (owning pharmacist), and `POST /v1/pharmacies/reservations/{reservation_id}/cancel` (owning patient). A hold expires after 10 minutes; active holds are deducted from searchable availability. Confirmation deducts stock and snapshots the agreed unit prices. Concurrent reservations serialize on inventory rows; duplicate submissions with the same patient/idempotency key and same payload return the original reservation; reusing the key with a different payload is rejected. Pharmacy audit timeline: `GET /v1/pharmacies/me/activity` (last 100 events).

Order lifecycle: patient creates an order from an active reservation with `POST /v1/pharmacies/orders`; patient order history `GET /v1/pharmacies/orders/me`; pharmacy queue `GET /v1/pharmacies/me/orders`. Pharmacy transitions: `accept`, `start_preparing`, `mark_ready`; patient pickup confirmation: `dispense`; cancellation is allowed to the patient before acceptance and to the owning pharmacy before dispensing. Accepting an order atomically deducts the reserved quantities; pharmacy cancellation before dispensing restores stock. Admin-only expiry maintenance: `POST /v1/admin/maintenance/expire-reservations` processes up to 500 expired holds per call.

In-app notifications: `GET /v1/notifications/me` returns the caller's private inbox and unread count; `POST /v1/notifications/{notification_id}/read` marks only the caller's own notification as read. Order lifecycle events create generic notifications without medicine names or clinical details. These are in-app notifications; mobile push delivery is not configured.

## Supabase Auth integration

The API supports two explicit authentication modes. Keep `AUTH_PROVIDER=local` for the isolated synthetic username/password staging flow. To switch the API to Supabase Auth, set `AUTH_PROVIDER=supabase`, `SUPABASE_URL`, and `SUPABASE_PUBLISHABLE_KEY`; use the same project URL and publishable key in the Flutter build. The API then accepts Supabase user access tokens, validates ES256/RS256 signatures using the project's JWKS endpoint, and validates legacy HS256 tokens by calling the Supabase Auth `/user` endpoint. Local `/v1/auth/token` login is disabled in this mode. The API's database role is always read from its own `app_users` record, never from user-editable JWT metadata.

For each authorized Supabase Auth user, an administrator must provision a corresponding `app_users` record in the API database with `id` exactly equal to the Auth user's UUID, the approved application `role`, the display name, and their email as username. Do not expose an endpoint that lets users assign their own roles. `password_hash` can remain NULL for Supabase-managed identities. Use the Auth dashboard to create users and the private API database connection to provision role mappings. Never put a Supabase secret/service-role key in a mobile app or public environment variable.

The API container has outbound network access for JWKS/Auth token verification; PostgreSQL remains isolated on its private network. This configuration is not yet activated because the connected Supabase account currently has no RxBridge project. Do not point it at the unrelated Zurvan project.

## Limitations
Staging scaffold: basic login, current-user, health, aggregate synthetic summary, synthetic consent event, and initial pharmacy profile/inventory/matching endpoints. Object-level patient authorization, complete CRUD, token revocation, rate limits, complete cross-module audit, tested backups, file scanning and security review remain outstanding. Do not invite external testers until those controls are complete. Use fictitious data only.
