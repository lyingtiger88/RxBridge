# RxBridge — Architecture & safety contract

## Current milestone
v0.1.0 is a static demo. No real medical data, no operational prescription, no clinical decision support, no genuine user authentication.

## Proposed production architecture
- Next.js + TypeScript frontend (RTL + i18n)
- ASP.NET Core modular monolith backend
- PostgreSQL, encrypted storage, per-organization scoped access, audit events
- Modules: Identity, Organization, Patient, Formulary, Prescription, ClinicalValidation, PharmacyReview, Dispense, CountryAdapter, FHIR
- Date persisted in ISO 8601 UTC; Iranian Jalali calendar only a view-layer representation
- Formal national integration only after approved API access, credentials and legal review

## Minimum future entities
`Organization`, `Practitioner`, `Membership`, `Patient`, `Allergy`, `Ingredient`, `MedicationProduct`, `Route`, `Prescription`, `PrescriptionItem`, `CustomFieldConfirmation`, `Review`, `Dispense`, `AuditEvent`, `IntegrationEvent`

## Prescription transitions
`DRAFT → SIGNED → PHARMACIST_APPROVED → DISPENSED`
Rejection/return to prescriber and partial fills are next-stage workflows. No silent modification after signing; use amendment/revision links.

## Custom-field contract
Store field name, original canonical selection (if any), custom text, stated rationale, actor identity, timestamp, form version, exact value digest, confirmation and independent clinical review outcome. Confirmation is invalidated on any relevant edit. Confirmation of intentional entry never overrides safety rules, prohibited route/product mismatches, professional responsibility, or legal requirements. Human-readable unstructured entries cannot be trusted as computation inputs.

## Clinical safety boundary
Route lists in prototype are illustrative only. Product-specific route/strength verification, interaction/allergy checks, pediatric/renal adjustments, injection dilution/rate and dose recommendations are NOT implemented. Do not use prototype for patient care. Avoid entering identifiers or confidential medical data in browser storage.

## Production exit criteria
Authenticated practitioner licenses; permissions and audit guarantees; versioned sourced drug catalog; secure deployment and backup; validated calculation/rule test suite with pharmacist sign-off; interoperability tests; usability and safety evaluation; regulator and integration permissions.
