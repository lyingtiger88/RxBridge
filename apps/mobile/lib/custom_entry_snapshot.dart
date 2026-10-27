import 'dart:convert';

/// Stable snapshot of every field that must remain unchanged after custom-entry review.
/// JSON encoding avoids collisions that can occur when joining arbitrary user input with a delimiter.
String buildCustomEntrySnapshot({
  required String patient,
  required String drug,
  required String amount,
  required String days,
  required String instructions,
  required String form,
  required String route,
  required String frequency,
  required String interval,
  required String startTime,
  required String custom,
  required String reason,
}) => jsonEncode([
  patient,
  drug,
  amount,
  days,
  instructions,
  form,
  route,
  frequency,
  interval,
  startTime,
  custom,
  reason,
]);
