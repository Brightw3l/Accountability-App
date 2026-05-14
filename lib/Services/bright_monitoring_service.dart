import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrightMonitoringService {
  BrightMonitoringService({
    SupabaseClient? client,
  }) : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const Set<String> missedStatuses = {
    'missed',
    'failed',
    'rejected',
  };

  static const Set<String> completedStatuses = {
    'done',
    'approved',
  };

  Future<List<Map<String, dynamic>>> getOpenEvents({
    required String userId,
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('bright_events')
        .select('''
          event_id,
          user_id,
          habit_id,
          log_id,
          event_type,
          severity,
          title,
          message,
          payload,
          status,
          created_at,
          habits (
            habit_id,
            title,
            duration_minutes,
            verification_type,
            preferred_time_of_day
          )
        ''')
        .eq('user_id', userId)
        .inFilter('status', ['unread', 'seen'])
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getRecentCheckins({
    required String userId,
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('bright_checkins')
        .select('''
          checkin_id,
          user_id,
          habit_id,
          log_id,
          event_id,
          reason_category,
          user_note,
          partner_visible_summary,
          share_with_partners,
          shared_at,
          created_at,
          habits (
            habit_id,
            title
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markEventSeen({
    required String eventId,
  }) async {
    await _supabase
        .from('bright_events')
        .update({'status': 'seen'})
        .eq('event_id', eventId);
  }

  Future<void> resolveEvent({
    required String eventId,
  }) async {
    await _supabase
        .from('bright_events')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('event_id', eventId);
  }

  Future<void> dismissEvent({
    required String eventId,
  }) async {
    await _supabase
        .from('bright_events')
        .update({'status': 'dismissed'})
        .eq('event_id', eventId);
  }

  Future<void> monitorMissedTasks({
    required String userId,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = now.subtract(const Duration(days: 14));

      final logsResponse = await _supabase
          .from('habit_logs')
          .select('''
            log_id,
            user_id,
            habit_id,
            log_date,
            status,
            scheduled_start,
            scheduled_end,
            habits (
              habit_id,
              title,
              duration_minutes,
              verification_type,
              preferred_time_of_day
            )
          ''')
          .eq('user_id', userId)
          .gte('log_date', _dateOnly(fromDate))
          .inFilter('status', missedStatuses.toList())
          .order('log_date', ascending: false)
          .order('scheduled_start', ascending: false);

      final missedLogs = List<Map<String, dynamic>>.from(logsResponse);

      for (final log in missedLogs) {
        await _createEventsForMissedLog(
          userId: userId,
          log: log,
        );
      }

      await _createReviewEventsForStrugglingHabits(userId: userId);
      await _createReviewEventsForStrongHabits(userId: userId);
    } catch (e, st) {
      debugPrint('BRIGHT monitor error: $e');
      debugPrintStack(stackTrace: st);

      // Important: never rethrow here.
      // BRIGHT monitoring should not crash the main app flow.
      return;
    }
  }

  Future<void> recordMissedTaskReason({
    required String userId,
    required String habitId,
    required String logId,
    required String reasonCategory,
    required String rawReason,
    String? eventId,
    bool shareWithPartners = true,
  }) async {
    final trimmedReason = rawReason.trim();

    if (trimmedReason.isEmpty) {
      throw Exception('Reason cannot be empty.');
    }

    final safeCategory = _normalizeReasonCategory(reasonCategory);

    final insert = {
      'user_id': userId,
      'habit_id': habitId,
      'log_id': logId,
      'event_id': eventId,
      'reason_category': safeCategory,
      'user_note': trimmedReason,
      'partner_visible_summary': trimmedReason,
      'share_with_partners': shareWithPartners,
      'shared_at': shareWithPartners
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    };

    await _supabase.from('bright_checkins').insert(insert);

    if (eventId != null) {
      await resolveEvent(eventId: eventId);
    }

    await _maybeCreateAdjustmentEventAfterCheckin(
      userId: userId,
      habitId: habitId,
      logId: logId,
      reasonCategory: safeCategory,
      rawReason: trimmedReason,
    );
  }

  Future<List<Map<String, dynamic>>> getPartnerSharedCheckins({
    required String partnerUserId,
    int limit = 30,
  }) async {
    final response = await _supabase
        .from('bright_checkins')
        .select('''
          checkin_id,
          user_id,
          habit_id,
          log_id,
          reason_category,
          user_note,
          partner_visible_summary,
          share_with_partners,
          shared_at,
          created_at,
          habits (
            habit_id,
            title
          ),
          profiles (
            id,
            username,
            public_handle
          )
        ''')
        .eq('user_id', partnerUserId)
        .eq('share_with_partners', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _createEventsForMissedLog({
    required String userId,
    required Map<String, dynamic> log,
  }) async {
    final logId = log['log_id']?.toString();
    final habitId = log['habit_id']?.toString();

    if (logId == null || logId.isEmpty) return;
    if (habitId == null || habitId.isEmpty) return;

    final habit = _asMap(log['habits']);
    final habitTitle = (habit['title'] ?? 'Task').toString();

    final existingFirstMiss = await _eventExists(
      userId: userId,
      logId: logId,
      eventType: 'missed_task_first',
    );

    if (!existingFirstMiss) {
      await _insertEvent(
        userId: userId,
        habitId: habitId,
        logId: logId,
        eventType: 'missed_task_first',
        severity: 'nudge',
        title: 'Missed task',
        message: 'You missed $habitTitle. What got in the way?',
        payload: {
          'habit_title': habitTitle,
          'log_status': log['status'],
          'log_date': log['log_date'],
          'scheduled_start': log['scheduled_start'],
          'scheduled_end': log['scheduled_end'],
          'needs_checkin': true,
        },
      );
    }

    final missStreak = await _getRecentMissStreak(
      userId: userId,
      habitId: habitId,
    );

    if (missStreak >= 2) {
      final existingStreakEvent = await _recentOpenEventExists(
        userId: userId,
        habitId: habitId,
        eventType: 'missed_task_streak',
        withinDays: 3,
      );

      if (!existingStreakEvent) {
        await _insertEvent(
          userId: userId,
          habitId: habitId,
          logId: logId,
          eventType: 'missed_task_streak',
          severity: missStreak >= 3 ? 'critical' : 'warning',
          title: '$habitTitle is slipping',
          message:
              'You missed $habitTitle $missStreak times in a row. This may need a schedule or difficulty adjustment.',
          payload: {
            'habit_title': habitTitle,
            'miss_streak': missStreak,
            'recommendation_options': [
              'move_time',
              'reduce_duration_temporarily',
              'split_task',
              'change_verification',
              'add_reminder',
            ],
            'needs_checkin': true,
            'needs_adjustment_review': true,
          },
        );
      }
    }
  }

  Future<void> _createReviewEventsForStrugglingHabits({
    required String userId,
  }) async {
    final performance = await _getHabitPerformance(
      userId: userId,
      days: 14,
    );

    for (final item in performance) {
      final habitId = item.habitId;
      final habitTitle = item.habitTitle;

      if (item.totalCount < 4) continue;
      if (item.completionRate >= 0.5) continue;

      final exists = await _recentOpenEventExists(
        userId: userId,
        habitId: habitId,
        eventType: 'habit_completion_declining',
        withinDays: 7,
      );

      if (exists) continue;

      await _insertEvent(
        userId: userId,
        habitId: habitId,
        logId: null,
        eventType: 'habit_completion_declining',
        severity: 'warning',
        title: '$habitTitle needs adjustment',
        message:
            'Your completion rate for $habitTitle is under 50% over the last 14 days. BRIGHT recommends reviewing the schedule or difficulty.',
        payload: {
          'habit_title': habitTitle,
          'completion_rate_14d': item.completionRate,
          'done_count_14d': item.doneCount,
          'missed_count_14d': item.missedCount,
          'total_count_14d': item.totalCount,
          'needs_adjustment_review': true,
        },
      );
    }
  }

  Future<void> _createReviewEventsForStrongHabits({
    required String userId,
  }) async {
    final performance = await _getHabitPerformance(
      userId: userId,
      days: 14,
    );

    for (final item in performance) {
      final habitId = item.habitId;
      final habitTitle = item.habitTitle;

      if (item.totalCount < 5) continue;
      if (item.completionRate < 0.85) continue;

      final exists = await _recentOpenEventExists(
        userId: userId,
        habitId: habitId,
        eventType: 'habit_completion_strong',
        withinDays: 10,
      );

      if (exists) continue;

      await _insertEvent(
        userId: userId,
        habitId: habitId,
        logId: null,
        eventType: 'habit_completion_strong',
        severity: 'info',
        title: '$habitTitle is getting consistent',
        message:
            'You completed ${item.doneCount}/${item.totalCount} recent sessions. BRIGHT can recommend a small progression soon.',
        payload: {
          'habit_title': habitTitle,
          'completion_rate_14d': item.completionRate,
          'done_count_14d': item.doneCount,
          'total_count_14d': item.totalCount,
          'can_progress': true,
        },
      );
    }
  }

  Future<void> _maybeCreateAdjustmentEventAfterCheckin({
    required String userId,
    required String habitId,
    required String logId,
    required String reasonCategory,
    required String rawReason,
  }) async {
    final missStreak = await _getRecentMissStreak(
      userId: userId,
      habitId: habitId,
    );

    if (missStreak < 2) return;

    final exists = await _recentOpenEventExists(
      userId: userId,
      habitId: habitId,
      eventType: 'habit_adjustment_prompt',
      withinDays: 5,
    );

    if (exists) return;

    final habit = await _getHabit(habitId);
    final habitTitle = (habit['title'] ?? 'This habit').toString();

    await _insertEvent(
      userId: userId,
      habitId: habitId,
      logId: logId,
      eventType: 'habit_adjustment_prompt',
      severity: 'warning',
      title: 'Adjust $habitTitle?',
      message:
          '$habitTitle has been missed repeatedly. Based on your reason, BRIGHT can help adjust the plan.',
      payload: {
        'habit_title': habitTitle,
        'miss_streak': missStreak,
        'reason_category': reasonCategory,
        'raw_reason': rawReason,
        'recommendation_options': _recommendationOptionsForReason(
          reasonCategory,
        ),
        'needs_ai_help': true,
      },
    );
  }

  Future<bool> _eventExists({
    required String userId,
    required String logId,
    required String eventType,
  }) async {
    final response = await _supabase
        .from('bright_events')
        .select('event_id')
        .eq('user_id', userId)
        .eq('log_id', logId)
        .eq('event_type', eventType)
        .limit(1)
        .maybeSingle();

    return response != null;
  }

  Future<bool> _recentOpenEventExists({
    required String userId,
    required String habitId,
    required String eventType,
    required int withinDays,
  }) async {
    final since = DateTime.now()
        .subtract(Duration(days: withinDays))
        .toUtc()
        .toIso8601String();

    final response = await _supabase
        .from('bright_events')
        .select('event_id')
        .eq('user_id', userId)
        .eq('habit_id', habitId)
        .eq('event_type', eventType)
        .inFilter('status', ['unread', 'seen'])
        .gte('created_at', since)
        .limit(1)
        .maybeSingle();

    return response != null;
  }

  Future<void> _insertEvent({
    required String userId,
    required String habitId,
    required String? logId,
    required String eventType,
    required String severity,
    required String title,
    required String message,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase.from('bright_events').insert({
      'user_id': userId,
      'habit_id': habitId,
      'log_id': logId,
      'event_type': eventType,
      'severity': severity,
      'title': title,
      'message': message,
      'payload': payload,
      'status': 'unread',
    });
  }

  Future<int> _getRecentMissStreak({
    required String userId,
    required String habitId,
  }) async {
    final response = await _supabase
        .from('habit_logs')
        .select('log_id, status, log_date, scheduled_start')
        .eq('user_id', userId)
        .eq('habit_id', habitId)
        .order('log_date', ascending: false)
        .order('scheduled_start', ascending: false)
        .limit(10);

    final logs = List<Map<String, dynamic>>.from(response);

    int streak = 0;

    for (final log in logs) {
      final status = (log['status'] ?? '').toString();

      if (missedStatuses.contains(status)) {
        streak++;
      } else if (completedStatuses.contains(status)) {
        break;
      }
    }

    return streak;
  }

  Future<List<_HabitPerformance>> _getHabitPerformance({
    required String userId,
    required int days,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));

    final response = await _supabase
        .from('habit_logs')
        .select('''
          log_id,
          habit_id,
          status,
          log_date,
          habits (
            habit_id,
            title
          )
        ''')
        .eq('user_id', userId)
        .gte('log_date', _dateOnly(since));

    final logs = List<Map<String, dynamic>>.from(response);

    final Map<String, _HabitPerformanceBuilder> builders = {};

    for (final log in logs) {
      final habitId = log['habit_id']?.toString();
      if (habitId == null || habitId.isEmpty) continue;

      final habit = _asMap(log['habits']);
      final habitTitle = (habit['title'] ?? 'Habit').toString();
      final status = (log['status'] ?? '').toString();

      builders.putIfAbsent(
        habitId,
        () => _HabitPerformanceBuilder(
          habitId: habitId,
          habitTitle: habitTitle,
        ),
      );

      builders[habitId]!.addStatus(status);
    }

    return builders.values.map((builder) => builder.build()).toList();
  }

  Future<Map<String, dynamic>> _getHabit(String habitId) async {
    final response = await _supabase
        .from('habits')
        .select('habit_id, title, duration_minutes, verification_type')
        .eq('habit_id', habitId)
        .limit(1)
        .maybeSingle();

    if (response == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(response);
  }

  List<String> _recommendationOptionsForReason(String reasonCategory) {
    switch (reasonCategory) {
      case 'bad_timing':
        return ['move_time', 'change_days', 'add_reminder'];
      case 'too_tired':
        return [
          'move_earlier',
          'reduce_duration_temporarily',
          'split_task',
        ];
      case 'forgot':
        return ['add_reminder', 'change_notification_tone'];
      case 'too_long':
        return [
          'reduce_duration_temporarily',
          'split_task',
          'lower_friction',
        ];
      case 'unexpected_event':
        return ['reschedule_once', 'add_recovery_window'];
      case 'unclear_task':
        return ['make_task_specific', 'split_task'];
      case 'low_motivation':
        return [
          'make_verification_stricter',
          'add_partner_check',
          'reduce_starting_friction',
        ];
      case 'environment_issue':
        return ['change_location', 'prepare_environment'];
      case 'verification_problem':
        return ['change_verification', 'fix_verification_setup'];
      case 'other':
      default:
        return ['review_schedule', 'split_task', 'adjust_difficulty'];
    }
  }

  String _normalizeReasonCategory(String value) {
    const allowed = {
      'bad_timing',
      'too_tired',
      'forgot',
      'too_long',
      'unexpected_event',
      'unclear_task',
      'low_motivation',
      'environment_issue',
      'verification_problem',
      'other',
    };

    return allowed.contains(value) ? value : 'other';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _HabitPerformanceBuilder {
  _HabitPerformanceBuilder({
    required this.habitId,
    required this.habitTitle,
  });

  final String habitId;
  final String habitTitle;

  int doneCount = 0;
  int missedCount = 0;
  int totalCount = 0;

  void addStatus(String status) {
    if (status == 'pending' ||
        status == 'submitted' ||
        status == 'pending_verification') {
      return;
    }

    totalCount++;

    if (BrightMonitoringService.completedStatuses.contains(status)) {
      doneCount++;
      return;
    }

    if (BrightMonitoringService.missedStatuses.contains(status)) {
      missedCount++;
    }
  }

  _HabitPerformance build() {
    final completionRate = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return _HabitPerformance(
      habitId: habitId,
      habitTitle: habitTitle,
      doneCount: doneCount,
      missedCount: missedCount,
      totalCount: totalCount,
      completionRate: completionRate,
    );
  }
}

class _HabitPerformance {
  _HabitPerformance({
    required this.habitId,
    required this.habitTitle,
    required this.doneCount,
    required this.missedCount,
    required this.totalCount,
    required this.completionRate,
  });

  final String habitId;
  final String habitTitle;
  final int doneCount;
  final int missedCount;
  final int totalCount;
  final double completionRate;
}