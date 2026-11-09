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

## Added schedule, calendar and progress features
- A physician can attach up to eight daily local-time reminder slots to a habit plan.
- The patient explicitly enables OS notifications on their own device; the app asks for notification permission.
- Notifications use generic lock-screen wording and do not reveal the habit or health data.
- Reminders are local to the patient's device; they are not sent by a server and are not proof of completion.
- The weekly calendar visualizes self-reported log entries for the last seven local days.
- The progress summary reports submitted logs, doctor-reviewed logs, approved points, and adherence percentage among reviewed logs only.
- Pending logs are excluded from the adherence denominator. Out-of-range and missed reports remain zero-point and require clinician feedback.
- Time-zone scheduling uses the device's current local time zone. Patients must re-enable reminders after reinstalling the app or changing devices.

## Patient adherence badges
- Bronze: 5 physician-approved adherence points.
- Silver: 20 physician-approved adherence points.
- Gold: 50 physician-approved adherence points.
- Only points awarded by the clinician review workflow count. Pending, self-reported, out-of-range and missed entries do not count.
- Badges are motivational indicators of recorded adherence, not clinical outcomes, treatment quality, or a measure of disease control.
- Thresholds are presentation defaults and should be configurable by product governance before production launch.
