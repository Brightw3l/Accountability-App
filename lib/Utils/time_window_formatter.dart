class TimeWindowFormatter {
  TimeWindowFormatter._();

  static String formatTimeValue(dynamic value) {
    if (value == null) return '';

    final raw = value.toString().trim();
    if (raw.isEmpty) return '';

    final parts = raw.split(':');
    if (parts.length < 2) return raw;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return raw;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String formatWindow({
    required dynamic start,
    required dynamic end,
    String fallback = 'No time set',
  }) {
    final startText = formatTimeValue(start);
    final endText = formatTimeValue(end);

    if (startText.isEmpty && endText.isEmpty) return fallback;
    if (startText.isNotEmpty && endText.isEmpty) return startText;
    if (startText.isEmpty && endText.isNotEmpty) return endText;

    return '$startText → $endText';
  }

  static int? durationMinutes({
    required dynamic start,
    required dynamic end,
  }) {
    final startMinutes = _minutesFromTime(start);
    final endMinutes = _minutesFromTime(end);

    if (startMinutes == null || endMinutes == null) return null;
    if (endMinutes <= startMinutes) return null;

    return endMinutes - startMinutes;
  }

  static int? _minutesFromTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }
}