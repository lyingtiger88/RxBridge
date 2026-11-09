# Physician-guided healthy habits (staging)

## Workflow
1. A doctor with an active patient relationship and active clinical-record consent creates a plan.
2. The plan contains a title, category, explicit instruction, unit, optional numeric lower/upper bounds, frequency per day and active period.
3. The patient sees the plan and submits a self-reported completion/value.
4. Every submission remains `pending` and earns zero points until the prescribing doctor reviews it.
5. The doctor reviews the reported value against the stored physician-authored bounds. Within-range adherence earns one positive point. Out-of-range or missed activity earns zero and requires written clinician feedback before review can be completed.
6. The patient sees the review outcome and clinician's guidance.

## Scoring and safety rules
- There are no negative points, streak penalties, diagnoses or automatic treatment changes.
- An in-range result is an adherence signal, not proof of clinical benefit or treatment success.
- A patient log is self-reported and must be labelled as such; it is not sensor-verified.
- Plans without numeric bounds are marked not applicable for scoring; they do not earn points.
- Numeric thresholds are authored by the treating clinician. The app does not recommend targets or infer them from diagnoses.
- A clinician must review any out-of-range or missed entry and provide guidance.
- This feature is not an emergency monitoring service. Urgent symptoms should follow local emergency pathways.
- Synthetic records only until full privacy/security review and deployment approval.

## Apply
Run `infra/supabase/migrations/0004_physician_habit_programs.sql` after migrations 0001–0003 in the isolated staging project. Then use doctor and patient accounts linked by active patient_access and clinical_record consent.
