// ignore_for_file: unintended_html_in_doc_comment

import 'package:flutter/foundation.dart';

class AppClock {
  AppClock._();

  /// Existing widgets expect this to be ValueListenable<DateTime?>.
  ///
  /// null = live real time
  /// non-null = debug clock enabled
  static final ValueNotifier<DateTime?> debugNowNotifier =
      ValueNotifier<DateTime?>(null);

  static Duration _debugOffset = Duration.zero;
  static bool _debugEnabled = false;

  /// Main app clock.
  ///
  /// This always keeps moving because it is based on real DateTime.now()
  /// plus an optional debug offset.
  static DateTime now() {
    final realNow = DateTime.now();

    if (!_debugEnabled) {
      return realNow;
    }

    return realNow.add(_debugOffset);
  }

  static DateTime today() {
    final current = now();

    return DateTime(
      current.year,
      current.month,
      current.day,
    );
  }

  /// New preferred name.
  static bool get isDebugEnabled => _debugEnabled;

  /// Old compatibility name used by dashboard_screen.dart.
  static bool get isDebugClockEnabled => _debugEnabled;

  /// New preferred offset getter.
  static Duration get debugOffset => _debugOffset;

  /// Old compatibility getter used by dashboard_screen.dart.
  ///
  /// Important: this returns the moving debug clock time, not a frozen value.
  static DateTime? get debugNow {
    if (!_debugEnabled) return null;
    return now();
  }

  static void _notifyDebugClockChanged() {
    debugNowNotifier.value = _debugEnabled ? now() : null;
  }

  /// Set the app clock to a specific target DateTime.
  ///
  /// Example:
  /// real time = 10:00
  /// targetAppTime = 14:30
  /// offset = +4h30m
  ///
  /// One real second later, AppClock.now() becomes 14:30:01.
  static void setDebugNow(DateTime targetAppTime) {
    final realNow = DateTime.now();

    _debugOffset = targetAppTime.difference(realNow);
    _debugEnabled = true;

    _notifyDebugClockChanged();
  }

  /// Old compatibility method used by dashboard_screen.dart.
  static void setDebugTime(DateTime targetAppTime) {
    setDebugNow(targetAppTime);
  }

  /// Set debug clock by today's clock time.
  ///
  /// This supports any hour/minute value your UI allows.
  static void setDebugClockTime({
    required int hour,
    required int minute,
    int second = 0,
  }) {
    final realNow = DateTime.now();

    final targetAppTime = DateTime(
      realNow.year,
      realNow.month,
      realNow.day,
      hour,
      minute,
      second,
    );

    setDebugNow(targetAppTime);
  }

  /// Directly set the offset.
  ///
  /// Supports any duration: minutes, hours, days, negative values, etc.
  static void setDebugOffset(Duration offset) {
    _debugOffset = offset;
    _debugEnabled = offset != Duration.zero;

    _notifyDebugClockChanged();
  }

  /// Move app time by any amount.
  ///
  /// Examples:
  /// AppClock.addDebugOffset(Duration(minutes: 56));
  /// AppClock.addDebugOffset(Duration(hours: 4));
  /// AppClock.addDebugOffset(Duration(hours: -2, minutes: -30));
  static void addDebugOffset(Duration delta) {
    _debugOffset += delta;
    _debugEnabled = _debugOffset != Duration.zero;

    _notifyDebugClockChanged();
  }

  static void jumpForward(Duration delta) {
    addDebugOffset(delta);
  }

  static void jumpBackward(Duration delta) {
    addDebugOffset(-delta);
  }

  static void clearDebugNow() {
    _debugOffset = Duration.zero;
    _debugEnabled = false;

    _notifyDebugClockChanged();
  }

  /// Old compatibility method used by dashboard_screen.dart.
  static void clearDebugTime() {
    clearDebugNow();
  }

  static String debugLabel() {
    if (!_debugEnabled) return 'Live time';

    final absolute = _debugOffset.abs();
    final sign = _debugOffset.isNegative ? '-' : '+';

    final days = absolute.inDays;
    final hours = absolute.inHours % 24;
    final minutes = absolute.inMinutes % 60;
    final seconds = absolute.inSeconds % 60;

    if (days > 0) {
      return 'Debug time $sign${days}d ${hours}h ${minutes}m';
    }

    if (hours > 0) {
      return 'Debug time $sign${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return 'Debug time $sign${minutes}m ${seconds}s';
    }

    return 'Debug time $sign${seconds}s';
  }
}