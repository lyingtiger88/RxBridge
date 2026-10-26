/// Deterministic calendar-independent clock schedule for synthetic demonstrations.
/// Does not prescribe or validate the therapeutic suitability of an interval.
List<String> exampleTimes({required int intervalHours, required String start}) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(start);
  if (match == null) throw FormatException('Use HH:mm');
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59 || intervalHours <= 0 || 24 % intervalHours != 0) {
    throw ArgumentError('Unsupported interval or start');
  }
  return List.generate(24 ~/ intervalHours, (i) {
    final h = (hour + i * intervalHours) % 24;
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  });
}
