# RxBridge Android development roadmap

**Updated: 2026-10-27.** A Flutter demo workspace exists in `apps/mobile`, including a Persian RTL UI, synthetic workflow, unit/widget tests, and a GitHub Actions job configured to build a debug APK. Successful build status and downloadable artifacts must be verified from the corresponding Actions run; no production APK or release signing is claimed.

## Platform strategy
- **Flutter/Dart** Android-first for shared future iOS support.
- API contracts backed by planned ASP.NET Core / PostgreSQL backend.
- Keep prescription calculation/validation on an independently tested server service; local UI validation is not clinical authorization.
- Distinct builds/environments: demo (synthetic records) and production (only once reviewed and approved).

## Milestones
The initial UI and demo workflow exist. The following are remaining milestones; they are not claims of completed production functionality.

| Target | Scope | Acceptance |
| --- | --- | --- |
| v0.2.0 | Stabilize existing Flutter demo, design system, Persian RTL, About & Roadmap | CI debug APK build passes; navigation and accessibility basics tested |
| v0.3.0 | Structured medication fields, administration route, dosing schedule, custom-field rationale and reconfirmation | Widget/unit tests for input and invalidation on edit |
| v0.4.0 | Backend API client, scoped login, draft sync, offline read-only strategy, audit | Auth and role tests; no real health data in debug/demo |
| v0.5.0 | Versioned drug catalog, product-specific route constraints, safety rule provenance | Pharmacist review and automated verification suite |
| v0.9.0 | Security, accessibility, localization, end-to-end workflow, clinical QA and legal review | No release-blocking findings |
| v1.0.0 | Production release candidate | Licensed integrations and regulatory/legal obligations fulfilled |

## Android screens
1. Splash and environment indicator
2. Professional login and organization selection
3. Role-scoped dashboard
4. Patient (test data only until production approval)
5. Prescription editor, item details and variable fields
6. Explicit confirmation dialog: field/value/reason; confirmation reset on modification
7. Pharmacist review inbox
8. Dispensing record
9. About app: feature inventory, current installed version, roadmap, safety and credits
10. Settings: Persian/English, Jalali display, accessibility and privacy

## Engineering and safety
- Version name follows completed releases; `versionCode` monotonic.
- No embedded tokens/credentials; Android Keystore for sensitive key material when implemented.
- Secure transport, no plaintext PHI logs, lifecycle-safe state and least-privilege permissions.
- Never treat user confirmation as overriding incompatible administration routes, missing dosages or hard safety stops.
- No claim of real prescribing/dispensing without clinician authorization and legal integrations.
- Offline edit/sync requires conflict resolution, provenance and audit; not part of early MVP.

## Next implementation handoff
Initialize Flutter workspace in `apps/android` with Android SDK/Gradle config, reusable widgets and navigation. Add CI lint, unit/widget tests and build artefact workflow. Keep existing static web demo intact.
