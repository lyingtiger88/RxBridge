# RxBridge — Patient Records, Doctor Profiles & Consent Architecture

**Status:** Product/architecture specification. Not a production implementation. No real patient or clinician data may be entered in the current demo.

## 1. Product direction
RxBridge evolves from a prescription/pharmacy workflow into a multi-sided health platform with:
- verified clinician professional records and a carefully limited public profile;
- a patient portal and longitudinal, detailed health record;
- secure care-team communication and treatment follow-up;
- a separately protected confidential/sensitive-health compartment;
- pharmacy fulfillment and insurance workflows that receive only the minimum data needed for their task.

The patient is the data subject and controls optional sharing. The platform must not describe itself as the legal owner of patient health information.

## 2. Roles and trust boundaries
- Patient: reads own record, manages granular consents, sees access history, communicates with care team, rates verified care encounters.
- Treating clinician: accesses the ordinary record only while an active care relationship exists and the access policy permits it; accesses confidential compartment only with separate explicit consent.
- Pharmacist/pharmacy: receives only a valid prescription and the minimum dispensing context; no general chart access by default.
- Insurer: receives only the data legally required for eligibility/claims; analytics are aggregate/de-identified. No access to confidential compartment.
- Clinic administrator: operational metadata only; no clinical content unless separately authorized for a defined task.
- Platform security administrator: cannot browse clinical content by virtue of admin role. Support access is time-limited, approved, logged and content-minimized.

Role selection in the UI is not authentication. Production identity must be verified and every API call authorized server-side.

## 3. Record compartments

### A. Patient longitudinal record
Patient-visible and available to the currently authorized treating clinician:
- demographics and patient-reported history;
- conditions/problems and encounter diagnoses;
- allergies and adverse reactions;
- medications, prescriptions and dispensing events;
- procedures, immunizations, admissions and discharge summaries;
- laboratory and imaging reports;
- clinical notes, care plans, referrals and follow-up;
- attachments and provenance/source of every item.

Each entry has author, organization, encounter, timestamp, status, source, correction/amendment history and signature where required. Corrections append a new version; never silently overwrite a signed clinical entry.

### B. Confidential/sensitive compartment
A separate security boundary for sensitive diagnoses, notes, documents and related observations. Access policy:
1. Patient can view and manage this compartment, subject to applicable law and capacity/representative rules.
2. Only the specifically assigned treating clinician can request access.
3. A separate, explicit, informed, granular consent is required for each purpose/category, with recipient, purpose, scope, start/end and revocation.
4. No pharmacist, insurer, public-profile visitor, ordinary clinic operator or generic admin access.
5. Every view, export, amendment and failed access attempt is immutably audited and visible to the patient.
6. Revocation blocks future access; it cannot retroactively erase a lawful access already performed.
7. No emergency bypass is included in the product policy by default. Any legally required exception must be separately specified, justified, notified and audited after legal/clinical review.

Sensitive data should be encrypted with separate keys/key hierarchy, and ideally separately partitioned at storage and service layers. A UI tab alone is not a security boundary.

### C. Public clinician profile
Only verified, approved fields may be public:
- display name, verified specialty/subspecialty, professional registration verification status;
- clinic/work locations and appointment/contact options;
- professional biography and voluntarily published credentials;
- rating and moderated reviews linked to verified care encounters.

Private identity documents, personal address/phone, disciplinary material not legally public, patient lists and all patient data remain private. Clearly distinguish verified facts from self-reported claims.

## 4. Doctor evaluation and patient reviews
- Ratings may be submitted only after a verified encounter or completed service, not by arbitrary accounts.
- Separate dimensions (communication, explanation, punctuality, care experience) from clinical outcome claims.
- No incentives for positive reviews; detect duplicate, coercive, defamatory or privacy-violating content.
- Never show the patient's diagnosis, medication or visit details on the public profile.
- Doctor may respond publicly only without confirming patient identity or disclosing any health information.
- Provide moderation, appeal, fraud detection and correction workflow.
- Do not rank doctors solely by raw average; show sample size, date range and verified-review proportion.

## 5. Patient portal and communication
- Patient can inspect their longitudinal record, prescriptions, lab/imaging results, visit summaries, care plan and access history.
- Secure asynchronous messaging is scoped to a care relationship, with attachments, read status, retention policy and clinician response-time expectations.
- Treatment follow-up uses structured check-ins and reminders approved by the care team; it is not an emergency service.
- Push notifications must be privacy-preserving (e.g. “New message” rather than diagnosis or medicine name).
- Provide clear emergency guidance and prohibit the interface from implying continuous monitoring unless staffed and contracted.

## 6. Consent and access-control model
Consent is a first-class, versioned domain object, not a boolean:
- subject/patient;
- recipient clinician/practitioner identity and organization;
- data categories (ordinary chart vs named sensitive categories);
- purpose (treatment, referral, second opinion, research, etc.);
- permitted actions (view, add, download, share);
- effective-from, expires-at, status, revocation timestamp;
- consent text/version, language, capture method, authentication strength and evidence;
- guardian/representative basis when applicable.

Enforce authorization on the server for every resource and every request (deny by default). Verify active treating relationship separately from consent. Use least privilege and minimum necessary access. A consent for ordinary records must never implicitly grant sensitive-compartment access.

## 7. Audit, security and privacy
- Append-only, tamper-evident audit events for reads, searches, exports, edits, consent grants/revocations, role changes and failed attempts.
- Patient-facing access history with actor, time, purpose, data category and outcome.
- TLS in transit; encryption at rest; separate key domains for sensitive data; managed KMS/HSM in production.
- MFA for clinicians and privileged roles; verified credentials; session/device controls.
- No PHI in analytics, crash logs, URLs, push payloads or ordinary application logs.
- Data minimization, retention/deletion policy, backups, breach response, threat modeling and penetration tests.
- De-identification for aggregate reporting; small-cell suppression to reduce re-identification risk.
- No real patient data in demo builds, sample screenshots, CI artifacts or test fixtures.

## 8. Interoperability and deployment
Use FHIR R4/R5-compatible resources and mappings, subject to the national implementation guide:
- Patient, Practitioner, PractitionerRole, Organization, HealthcareService, Encounter;
- Condition, AllergyIntolerance, Observation, DiagnosticReport, ImagingStudy;
- MedicationRequest, MedicationDispense, MedicationStatement;
- CarePlan, ServiceRequest, DocumentReference, Communication;
- Consent, Provenance, AuditEvent.

Keep a modular monolith initially (identity/access, clinician registry, patient record, consent, messaging, prescriptions, pharmacy, insurer reporting) with clear bounded contexts. Do not split into microservices prematurely.

For Iran, implement an adapter to the Ministry's authorized national health exchange/operator and the current national code systems. Do not assume direct national APIs are publicly available. International expansion requires jurisdiction-specific data residency, consent, terminology, retention and regulatory adapters.

## 9. Critical Iran compliance gate
The Cabinet-approved National Electronic Health Roadmap (approval 1404/06/30; notification 1404/07/23, no. 118675/ت63328هـ) describes a citizen portal to view health history and share it with selected clinicians; granular consent by data type, recipient, purpose and duration; and immutable access logs. It also specifies role-based provider access and secure exchange.
The implementing regulation for electronic-health operators (approved 1404/11/01) requires explicit informed consent or a specific legal basis for health-data processing, defined purposes, necessity and confidentiality; it also assigns identity verification and data exchange responsibilities to authorized operators. Its data-handling and no-storage clauses require legal analysis before RxBridge chooses its operating role or stores national health data.

Before production:
- obtain specialist Iranian health-regulatory/privacy counsel review;
- determine whether RxBridge is a health e-business, licensed operator, provider system, or integration vendor;
- secure required Ministry/authorized-operator approvals and contracts;
- confirm applicable national consent, data residency, retention, security and interoperability specifications;
- conduct clinical safety and privacy impact assessments.

Sources:
- National Electronic Health Roadmap, Cabinet resolution no. 118675/ت63328هـ: https://www.irancodify.com/b/%D9%85%D8%B5%D9%88%D8%A8%D9%87_%D8%B3%D9%86%D8%AF_%D9%86%D9%82%D8%B4%D9%87_%D8%B1%D8%A7%D9%87_%D8%B3%D9%84%D8%A7%D9%85%D8%AA_%D8%A7%D9%84%DA%A9%D8%AA%D8%B1%D9%88%D9%86%DB%8C%DA%A9_%DA%A9%D8%B4%D9%88%D8%B1_%D9%85%D8%B5%D9%88%D8%A8_1404-06-30
- Electronic-health operator regulation, 1404/11/01: https://hoghogh.ai/circulars/c-d4948f61
- Medical Council professional confidentiality, Articles 76–79 (secondary report): https://www.pezeshkanoghanoon.ir/97112600301054/%D8%A7%D8%B1%D8%A7%D8%A6%D9%87-%D8%A7%D8%B7%D9%84%D8%A7%D8%B9%D8%A7%D8%AA-%D8%A8%DB%8C%D9%85%D8%A7%D8%B1-%D8%A8%D9%87-%D9%85%D8%B1%D8%A7%D8%AC%D8%B9-%D9%82%D8%B6%D8%A7%DB%8C%DB%8C-%D9%85%D8%B4%D8%B1%D9%88%D8%B7-%D8%A7%D8%B3%D8%AA

## 10. Delivery roadmap
1. **Architecture gate:** approve roles, data compartments, consent semantics, public/private clinician fields and legal operating model.
2. **Prototype UX (synthetic data only):** patient portal, clinician profile, consent manager, access-history screen and record timeline.
3. **Backend foundation:** verified identity, practitioner credential verification, active care relationship, server-side authorization, append-only audit.
4. **Patient record:** structured FHIR-compatible ordinary record and patient access.
5. **Sensitive compartment:** separate storage/key boundary, explicit consent and denial tests.
6. **Messaging/follow-up:** secure care-team communication and privacy-safe notifications.
7. **Ratings:** verified-encounter review, moderation, appeal and anti-fraud.
8. **Integration and release:** authorized national operator, insurer/pharmacy integration, security/clinical/legal review.

## 11. Acceptance criteria (non-negotiable)
- A pharmacist cannot access a patient's chart by changing a client-side role.
- An insurer cannot access individual confidential records or infer them from reports.
- A clinician without an active care relationship is denied access.
- A treating clinician without explicit valid sensitive-data consent is denied access to the confidential compartment.
- Revoking consent blocks subsequent access and creates an audit event.
- Patient can see all access events and manage grants.
- Public clinician profile never exposes patient or private credential data.
- CI tests prove both allowed and denied access paths.
- All demo fixtures are synthetic and visibly labelled.
