import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

enum AppTone {
  taskStart,
  success,
  submittedForReview,
  approved,
  rejected,
  graceWarning,
  appViolation,
  locationViolation,
  safeAgain,
}

class ToneService {
  ToneService._();

  static final ToneService instance = ToneService._();

  final AudioPlayer _oneShotPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();

  AppTone? _activeAlarmTone;
  bool _isAlarmPlaying = false;
  bool _enabled = true;

  bool get enabled => _enabled;
  bool get isAlarmPlaying => _isAlarmPlaying;

  void setEnabled(bool value) {
    _enabled = value;

    if (!value) {
      stopAlarm();
    }
  }

  Future<void> dispose() async {
    await _oneShotPlayer.dispose();
    await _alarmPlayer.dispose();
  }

  String _assetPath(AppTone tone) {
    switch (tone) {
      case AppTone.taskStart:
        return 'sounds/task_start.mp3';
      case AppTone.success:
        return 'sounds/success_ping.mp3';
      case AppTone.submittedForReview:
        return 'sounds/submitted_review.mp3';
      case AppTone.approved:
        return 'sounds/approved_reward.mp3';
      case AppTone.rejected:
        return 'sounds/rejected_fail.mp3';
      case AppTone.graceWarning:
        return 'sounds/grace_warning.mp3';
      case AppTone.appViolation:
        return 'sounds/app_violation_alarm.mp3';
      case AppTone.locationViolation:
        return 'sounds/location_violation_alarm.mp3';
      case AppTone.safeAgain:
        return 'sounds/safe_again.mp3';
    }
  }

  Future<void> play(AppTone tone) async {
    if (!_enabled) return;

    try {
      await _oneShotPlayer.stop();
      await _oneShotPlayer.setReleaseMode(ReleaseMode.release);
      await _oneShotPlayer.play(AssetSource(_assetPath(tone)));

      await _vibrateForTone(tone);
    } catch (e, st) {
      debugPrint('TONE PLAY ERROR: $e');
      debugPrint('$st');
    }
  }

  Future<void> startAlarm(AppTone tone) async {
    if (!_enabled) return;

    if (_isAlarmPlaying && _activeAlarmTone == tone) {
      return;
    }

    try {
      _activeAlarmTone = tone;
      _isAlarmPlaying = true;

      await _alarmPlayer.stop();
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.play(AssetSource(_assetPath(tone)));

      await _startViolationVibration(tone);
    } catch (e, st) {
      debugPrint('TONE ALARM START ERROR: $e');
      debugPrint('$st');
      _isAlarmPlaying = false;
      _activeAlarmTone = null;
    }
  }

  Future<void> stopAlarm({bool playSafeTone = true}) async {
    if (!_isAlarmPlaying && _activeAlarmTone == null) return;

    try {
      await _alarmPlayer.stop();
      await Vibration.cancel();

      _isAlarmPlaying = false;
      _activeAlarmTone = null;

      if (playSafeTone && _enabled) {
        await play(AppTone.safeAgain);
      }
    } catch (e, st) {
      debugPrint('TONE ALARM STOP ERROR: $e');
      debugPrint('$st');
    }
  }

  Future<void> _vibrateForTone(AppTone tone) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      switch (tone) {
        case AppTone.taskStart:
          await Vibration.vibrate(duration: 70);
          break;
        case AppTone.success:
        case AppTone.approved:
          await Vibration.vibrate(pattern: [0, 60, 40, 90]);
          break;
        case AppTone.submittedForReview:
          await Vibration.vibrate(duration: 45);
          break;
        case AppTone.rejected:
          await Vibration.vibrate(pattern: [0, 130, 70, 130]);
          break;
        case AppTone.graceWarning:
          await Vibration.vibrate(pattern: [0, 80, 60, 80, 60, 120]);
          break;
        case AppTone.appViolation:
        case AppTone.locationViolation:
          await _startViolationVibration(tone);
          break;
        case AppTone.safeAgain:
          await Vibration.vibrate(duration: 45);
          break;
      }
    } catch (_) {
      // Vibration is non-critical.
    }
  }

  Future<void> _startViolationVibration(AppTone tone) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      if (tone == AppTone.locationViolation) {
        await Vibration.vibrate(
          pattern: [0, 250, 120, 250, 120, 600],
          repeat: 0,
        );
      } else {
        await Vibration.vibrate(
          pattern: [0, 180, 100, 180, 100, 500],
          repeat: 0,
        );
      }
    } catch (_) {
      // Vibration is non-critical.
    }
  }
}