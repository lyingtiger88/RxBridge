# RxBridge backend and Supabase integration boundary

## Current verified state
- The repository contains a FastAPI backend and PostgreSQL schema/migrations.
- GitHub Actions validates migrations against an isolated PostgreSQL 16 service and builds the backend container.
- The connected Supabase account currently exposes the project `zurvan-license-server`; no RxBridge Supabase project is available in the connected project list.
- Therefore no RxBridge Supabase database, Auth configuration, RLS policy, Storage bucket, or Edge Function has been changed by this work.

## Target architecture
- Flutter clients authenticate through Supabase Auth.
- FastAPI remains the business-logic boundary for pharmacy matching, reservations, order transitions, inventory accounting, and audit events.
- FastAPI validates Supabase access tokens against the project's configured JWT/JWKS verification mechanism. It must not trust client-supplied role metadata.
- PostgreSQL is the source of truth. A deployment can use Supabase-hosted Postgres or a compatible Iranian PostgreSQL server.
- Supabase Realtime and Storage are optional integrations, never authorization boundaries by themselves.

## Migration plan when the RxBridge Supabase project is connected
1. Confirm the exact RxBridge project reference and environment (staging vs production).
2. Inspect existing tables, extensions, migration history, and current RLS policies before applying DDL.
3. Generate proper ordered Supabase migrations from the repository SQL using the Supabase CLI workflow.
4. Reconcile identity: `auth.users.id` must be the canonical user ID; pharmacy and order ownership must reference that ID.
5. Enable RLS on every exposed table. Define role and relationship policies using trusted server-managed claims or relational membership tables; never authorize from user-editable metadata.
6. Keep service-role/secret keys exclusively on the server. Do not expose them to Flutter or web clients.
7. Run security and performance advisors and integration tests before connecting any client.
8. Keep a repeatable export/migration path for a future Iranian PostgreSQL deployment.

## Not yet complete
- Supabase Auth token validation in FastAPI.
- Supabase-hosted database migration and RLS deployment.
- Supabase Realtime events and Storage policies.
- External push notifications.
- Scheduled execution of reservation expiry maintenance.
- Production security review and operational backups.
