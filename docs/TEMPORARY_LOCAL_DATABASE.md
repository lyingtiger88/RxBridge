# RxBridge — Temporary Local Demo Database

**ONLY for synthetic test fixtures. NOT for clinical use.**

## Current design
Flutter mobile starts with `SqliteCareSnapshotStorage` from `lib/sqlite_care_storage.dart`.
Database filename: `rxbridge_demo_only.db` in the application's private database directory.
Table: `demo_state(state_key TEXT PRIMARY KEY, payload TEXT)`.
Payload contains one versioned JSON snapshot with:
- synthetic laboratory orders and laboratory results;
- synthetic home blood-glucose entries with measurement timestamps/context;
- a sample clinician-specified daily glucose monitoring schedule.

The database is saved after each change and restored at next app start.
The database is **not encrypted**. Do not enter any real patient's data, diagnosis,
glucose results, documents, identifiers, or messages in this prototype.

Other current UI cards (patients, inventories, ratings, insurer figures, and example prescriptions)
remain sample-only hardcoded mock data; those modules are not yet persisted.
Notifications are scheduled by the OS and not stored in this database.

## Dependency boundary
- `lib/care_storage.dart`: pure `CareSnapshotStorage` contract + memory test adapter.
- `lib/sqlite_care_storage.dart`: disposable native SQLite implementation.
- `lib/care_demo_store.dart`: domain state; imports the contract only.
- `lib/main.dart`: bootstrap selects SQLite, loads data, then starts the UI.
- `test/care_storage_test.dart`: demonstrates read/write/restore using an independent fake adapter.

The UI and domain layer **must never import sqflite or know table names**.
Only the bootstrap and the SQLite adapter know about the local database.

## Migration to server-only mode
1. Design an authorized server API, persistent patient identities, roles, consent enforcement,
   auth, audit, clinical provenance and securely versioned data contracts.
2. Implement an authenticated `ServerCareSnapshotStorage` that satisfies
   `CareSnapshotStorage` (prefer structured API endpoints over whole snapshot replacement
   for production). Do not upload the local demo database as clinical history.
3. In the production bootstrap, instantiate the server adapter only.
4. Remove `lib/sqlite_care_storage.dart`, `sqflite` and `path` dependencies,
   and delete this temporary SQLite migration route from build configuration.
5. Remove test fixtures and invalidate/clean the local demo database when moving to the
   server-only application version, following a user-facing notice. Historical demo data
   must never be imported into real patient records.
6. CI should enforce that release builds contain no local persistent patient-store dependency;
   test that network denial produces an explicit offline state rather than opening SQLite.

No server integration exists yet; switching to production mode is **not** a simple
configuration change. The future secure API is a separate implementation task.
