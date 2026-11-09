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

Authenticated pharmacist endpoints: `GET/PUT /v1/pharmacies/me` and `PUT /v1/pharmacies/me/inventory`. Admin verification: `PATCH /v1/admin/pharmacies/{pharmacy_id}/verification`. Patient matching: `POST /v1/pharmacies/search` with GPS coordinates and exact prescription item details. Matching is strict on medicine, dosage form, strength and package; substitutions are never automatic. Only verified and published pharmacies are searchable. Partial basket subtotals are returned separately and never represented as a complete prescription total. Reservation endpoints: `POST /v1/pharmacies/{pharmacy_id}/reservations` (patient, requires a client-generated UUID idempotency key), `GET /v1/pharmacies/reservations/me` (patient), `GET /v1/pharmacies/me/reservations` (pharmacist), `POST /v1/pharmacies/reservations/{reservation_id}/confirm` (owning pharmacist), and `POST /v1/pharmacies/reservations/{reservation_id}/cancel` (owning patient). A hold expires after 10 minutes; active holds are deducted from searchable availability. Confirmation deducts stock and snapshots the agreed unit prices. Concurrent reservations serialize on inventory rows; duplicate submissions with the same patient/idempotency key return the original reservation.

## Limitations
Staging scaffold: basic login, current-user, health, aggregate synthetic summary, synthetic consent event, and initial pharmacy profile/inventory/matching endpoints. Object-level patient authorization, complete CRUD, token revocation, rate limits, full audit, tested backups, file scanning and security review remain outstanding. Do not invite external testers until those controls are complete. Use fictitious data only.
