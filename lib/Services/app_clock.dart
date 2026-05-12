import 'package:flutter/foundation.dart';

class AppClock {
  static final ValueNotifier<DateTime?> debugNowNotifier =
      ValueNotifier<DateTime?>(null);

  static DateTime now() {
    return debugNowNotifier.value ?? DateTime.now();
  }

  static DateTime today() {
    final nowValue = now();
    return DateTime(nowValue.year, nowValue.month, nowValue.day);
  }

  static bool get isDebugClockEnabled => debugNowNotifier.value != null;

  static DateTime? get debugNow => debugNowNotifier.value;

  static void setDebugTime(DateTime value) {
    debugNowNotifier.value = value;
    debugPrint('APP CLOCK: debug time set to ${debugNowNotifier.value}');
  }

  static void clearDebugTime() {
    debugPrint('APP CLOCK: debug time cleared');
    debugNowNotifier.value = null;
  }

  static String debugLabel() {
    final value = debugNowNotifier.value;
    if (value == null) return 'Real Time';

    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$year-$month-$day  $hour:$minute';
  }
}