// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:async';
import 'package:achievr_app/Services/app_clock.dart';
import 'package:achievr_app/Widgets/hold_to_refresh_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  final SupabaseClient supabase = Supabase.instance.client;

  RealtimeChannel? _progressChannel;
  Timer? _timeRefreshTimer;
  Timer? _realtimeRefreshDebounce;

String _logHabitTitle(Map<String, dynamic> log) {
  final nestedHabit = log['habits'];

  if (nestedHabit is Map<String, dynamic>) {
    return (nestedHabit['title'] ?? 'Completed task').toString();
  }

  if (nestedHabit is Map) {
    return (nestedHabit['title'] ?? 'Completed task').toString();
  }

  return (log['habit_title'] ??
          log['title'] ??
          log['habit_name'] ??
          'Completed task')
      .toString();
}

Widget _buildRecentCompletionsCard() {
  return _glassCard(
    margin: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Recent wins',
          subtitle: _recentCompletedLogs.isEmpty
              ? 'Completed tasks and reflections will appear here.'
              : 'Your latest completed commitments and reflections.',
        ),
        const SizedBox(height: 14),
        if (_recentCompletedLogs.isEmpty)
          const Text(
            'No completed tasks recorded yet for this week.',
            style: TextStyle(
              color: Color(0xFF9D9DA8),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Column(
            children: _recentCompletedLogs.map((log) {
              final title = _logHabitTitle(log);
              final goal = _logGoalTitle(log);
              final reflection = _logReflection(log);
              final dateLabel = _formatLogDate(log);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2B2B32)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25252B),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFFF8F8F8),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFF8F8F8),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (goal.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              goal,
                              style: const TextStyle(
                                color: Color(0xFF8C8C96),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (reflection != null) ...[
                            const SizedBox(height: 9),
                            Text(
                              '“$reflection”',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA9A9B3),
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              color: Color(0xFF70707A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    ),
  );
}

String _logGoalTitle(Map<String, dynamic> log) {
  final nestedHabit = log['habits'];

  if (nestedHabit is Map<String, dynamic>) {
    final nestedGoal = nestedHabit['goals'];

    if (nestedGoal is Map<String, dynamic>) {
      return (nestedGoal['title'] ?? '').toString();
    }

    if (nestedGoal is Map) {
      return (nestedGoal['title'] ?? '').toString();
    }
  }

  return (log['goal_title'] ?? '').toString();
}

String? _logReflection(Map<String, dynamic> log) {
  final possibleKeys = [
    'reflection',
    'reflection_text',
    'completion_reflection',
    'completion_note',
    'note',
    'notes',
    'evidence_note',
    'verification_note',
  ];

  for (final key in possibleKeys) {
    final value = log[key];

    if (value == null) continue;

    final text = value.toString().trim();

    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }

  return null;
}

String _formatLogDate(Map<String, dynamic> log) {
  final rawDate = log['log_date']?.toString();
  if (rawDate == null || rawDate.isEmpty) return '';

  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) return rawDate;

  final now = AppClock.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(parsed.year, parsed.month, parsed.day);

  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';

  return '${parsed.month}/${parsed.day}/${parsed.year}';
}

  bool _isLoading = true;
  String? _error;

  int _totalToday = 0;
  int _doneToday = 0;
  int _upcomingToday = 0;
  int _availableNowToday = 0;
  int _missedToday = 0;

  int _totalThisWeek = 0;
  int _doneThisWeek = 0;
  int _remainingThisWeek = 0;
  int _missedThisWeek = 0;

  int _totalDoneAllTime = 0;
  int _currentStreak = 0;

  List<Map<String, dynamic>> _recentCompletedLogs = [];

  static const Duration _gracePeriod = Duration(minutes: 30);

  DateTime get _screenNow => AppClock.now();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    AppClock.debugNowNotifier.addListener(_handleClockChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProgressRealtime();
      _startTimeRefresh();
      _loadProgressData();
    });
  }

  void _startProgressRealtime() {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  _progressChannel?.unsubscribe();

  _progressChannel = supabase
      .channel('progress_habit_logs_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'habit_logs',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (_) {
          _scheduleRealtimeRefresh();
        },
      )
      .subscribe();
}

  void _scheduleRealtimeRefresh() {
    if (!mounted) return;

    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted) return;
        _loadProgressData(showLoading: false);
      },
    );
  }

  void _startTimeRefresh() {
    _timeRefreshTimer?.cancel();

    _timeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) return;
        _loadProgressData(showLoading: false);
      },
    );
  }

  void _handleClockChange() {
    if (!mounted) return;
    _loadProgressData(showLoading: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppClock.debugNowNotifier.removeListener(_handleClockChange);

    _timeRefreshTimer?.cancel();
    _realtimeRefreshDebounce?.cancel();
    _progressChannel?.unsubscribe();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startProgressRealtime();
      _loadProgressData(showLoading: false);
    }
  }

  String _toDateString(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  DateTime? _logStartDateTime(Map<String, dynamic> log) {
    final logDateRaw = log['log_date']?.toString();
    final startRaw = log['scheduled_start']?.toString();

    if (logDateRaw == null || startRaw == null || startRaw.isEmpty) {
      return null;
    }

    final dateParts = logDateRaw.split('-');
    final timeParts = startRaw.split(':');

    if (dateParts.length != 3 || timeParts.length < 2) return null;

    final year = int.tryParse(dateParts[0]) ?? 0;
    final month = int.tryParse(dateParts[1]) ?? 1;
    final day = int.tryParse(dateParts[2]) ?? 1;
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    return DateTime(year, month, day, hour, minute);
  }
  
  DateTime? _logEndDateTime(Map<String, dynamic> log) {
    final logDateRaw = log['log_date']?.toString();
    final endRaw = log['scheduled_end']?.toString();

    if (logDateRaw == null || endRaw == null || endRaw.isEmpty) {
      return null;
    }

    final dateParts = logDateRaw.split('-');
    final timeParts = endRaw.split(':');

    if (dateParts.length != 3 || timeParts.length < 2) return null;

    final year = int.tryParse(dateParts[0]) ?? 0;
    final month = int.tryParse(dateParts[1]) ?? 1;
    final day = int.tryParse(dateParts[2]) ?? 1;
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    return DateTime(year, month, day, hour, minute);
  }

  String _classifyLogStatus(Map<String, dynamic> log, DateTime now) {
    final rawStatus = (log['status'] ?? 'pending').toString().toLowerCase();

    if (rawStatus == 'done' || rawStatus == 'completed') {
      return 'done';
    }

    if (rawStatus == 'missed' ||
        rawStatus == 'failed' ||
        rawStatus == 'rejected') {
      return 'missed';
    }

    if (rawStatus == 'submitted' || rawStatus == 'pending_verification') {
      return 'remaining';
    }

    final start = _logStartDateTime(log);
    final end = _logEndDateTime(log);

    if (start == null || end == null) return 'remaining';

    final latestAllowed = end.add(_gracePeriod);

    if (now.isBefore(start)) return 'upcoming';
    if (now.isAfter(latestAllowed)) return 'missed';

    return 'available';
  }

  Future<void> _loadProgressData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No authenticated user found.';
          _isLoading = false;
        });
        return;
      }

      final now = _screenNow;
      final todayString = _toDateString(now);

      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final startOfWeekString = _toDateString(startOfWeek);
      final endOfWeekString = _toDateString(endOfWeek);

      final todayLogsResponse = await supabase
          .from('habit_logs')
          .select('''
            *,
            habits(
              title,
              goals(
                title
              )
            )
          ''')
          .eq('user_id', user.id)
          .eq('log_date', todayString)
          .order('scheduled_start', ascending: true);

      final todayLogs = List<Map<String, dynamic>>.from(todayLogsResponse);

      final weeklyLogsResponse = await supabase
          .from('habit_logs')
          .select('''
            *,
            habits(
              title,
              goals(
                title
              )
            )
          ''')
          .eq('user_id', user.id)
          .gte('log_date', startOfWeekString)
          .lte('log_date', endOfWeekString)
          .order('log_date', ascending: false);

      final weeklyLogs = List<Map<String, dynamic>>.from(weeklyLogsResponse);

      final allDoneResponse = await supabase
          .from('habit_logs')
          .select('log_id')
          .eq('user_id', user.id)
          .eq('status', 'done');

      final allDoneLogs = List<Map<String, dynamic>>.from(allDoneResponse);

      final allLogsForStreakResponse = await supabase
          .from('habit_logs')
          .select('status, log_date')
          .eq('user_id', user.id)
          .lte('log_date', todayString)
          .order('log_date', ascending: false);

      final allLogsForStreak =
          List<Map<String, dynamic>>.from(allLogsForStreakResponse);

      final recentCompletedLogs = weeklyLogs.where((log) {
        return _classifyLogStatus(log, now) == 'done';
      }).toList();

      recentCompletedLogs.sort((a, b) {
        final aCompleted = DateTime.tryParse(
              a['completed_at']?.toString() ??
                  a['updated_at']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            _logEndDateTime(a) ??
            DateTime(1970);

        final bCompleted = DateTime.tryParse(
              b['completed_at']?.toString() ??
                  b['updated_at']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            _logEndDateTime(b) ??
            DateTime(1970);

        return bCompleted.compareTo(aCompleted);
      });

      final totalToday = todayLogs.length;

      final doneToday = todayLogs
          .where((log) => _classifyLogStatus(log, now) == 'done')
          .length;

      final upcomingToday = todayLogs
          .where((log) => _classifyLogStatus(log, now) == 'upcoming')
          .length;

      final availableNowToday = todayLogs
          .where((log) => _classifyLogStatus(log, now) == 'available')
          .length;

      final missedToday = todayLogs
          .where((log) => _classifyLogStatus(log, now) == 'missed')
          .length;

      final totalThisWeek = weeklyLogs.length;

      final doneThisWeek = weeklyLogs
          .where((log) => _classifyLogStatus(log, now) == 'done')
          .length;

      final missedThisWeek = weeklyLogs
          .where((log) => _classifyLogStatus(log, now) == 'missed')
          .length;

      final remainingThisWeek = weeklyLogs.where((log) {
        final status = _classifyLogStatus(log, now);
        return status == 'upcoming' ||
            status == 'available' ||
            status == 'remaining';
      }).length;

      final streak = _calculateCurrentStreak(allLogsForStreak, todayString);

      if (!mounted) return;

      setState(() {
        _totalToday = totalToday;
        _doneToday = doneToday;
        _upcomingToday = upcomingToday;
        _availableNowToday = availableNowToday;
        _missedToday = missedToday;

        _totalThisWeek = totalThisWeek;
        _doneThisWeek = doneThisWeek;
        _remainingThisWeek = remainingThisWeek;
        _missedThisWeek = missedThisWeek;

        _totalDoneAllTime = allDoneLogs.length;
        _currentStreak = streak;

        _recentCompletedLogs = recentCompletedLogs.take(5).toList();

        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('PROGRESS SCREEN ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load progress.\n$e';
        _isLoading = false;
      });
    }
  }

  int _calculateCurrentStreak(
    List<Map<String, dynamic>> logs,
    String todayString,
  ) {
    if (logs.isEmpty) return 0;

    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};

    for (final log in logs) {
      final date = log['log_date']?.toString();
      if (date == null) continue;
      groupedByDate.putIfAbsent(date, () => []).add(log);
    }

    int streak = 0;
    var cursor = AppClock.today();

    while (true) {
      final dateString = _toDateString(cursor);

      if (dateString.compareTo(todayString) > 0) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }

      final dayLogs = groupedByDate[dateString];

      if (dayLogs == null || dayLogs.isEmpty) break;

      final hasDone = dayLogs.any((log) {
        final status = log['status']?.toString().toLowerCase();
        return status == 'done';
      });

      if (hasDone) {
        streak++;
      } else {
        break;
      }

      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  double get _todayCompletionRate {
    if (_totalToday == 0) return 0;
    return _doneToday / _totalToday;
  }

  double get _weekCompletionRate {
    if (_totalThisWeek == 0) return 0;
    return _doneThisWeek / _totalThisWeek;
  }

  double get _todayRecoverabilityRate {
    if (_totalToday == 0) return 0;
    return (_doneToday + _availableNowToday + _upcomingToday) / _totalToday;
  }

  double get _weekRecoverabilityRate {
    if (_totalThisWeek == 0) return 0;
    return (_doneThisWeek + _remainingThisWeek) / _totalThisWeek;
  }

  int get _todayPercent => (_todayCompletionRate * 100).round();

  String get _heroTitle {
    if (_totalToday == 0) return 'No commitments today';
    if (_availableNowToday > 0) return 'You have work open now';
    if (_missedToday > 0 && _upcomingToday == 0 && _availableNowToday == 0) {
      return 'Today needs a reset';
    }
    if (_doneToday == _totalToday) return 'Today is complete';
    if (_doneToday > 0) return 'Momentum is active';
    return 'Today is waiting';
  }

  String get _heroMessage {
    if (_totalToday == 0) {
      return 'Nothing is scheduled today. Use the space deliberately or plan the next commitment.';
    }

    if (_availableNowToday > 0) {
      return '$_availableNowToday commitment${_availableNowToday == 1 ? '' : 's'} can be executed right now.';
    }

    if (_doneToday == _totalToday) {
      return 'All scheduled commitments for today are complete.';
    }

    if (_missedToday > 0 && _upcomingToday == 0) {
      return '$_missedToday commitment${_missedToday == 1 ? '' : 's'} missed the execution window today.';
    }

    if (_upcomingToday > 0) {
      return '$_upcomingToday commitment${_upcomingToday == 1 ? '' : 's'} still scheduled later today.';
    }

    return 'Keep the day controlled and protect the streak.';
  }

  String get _recommendation {
    if (_availableNowToday > 0) {
      return 'Do the available commitment now. This is the highest-leverage action because it directly improves today before the window closes.';
    }

    if (_missedToday > 0 && _remainingThisWeek > 0) {
      return 'Today took a hit, but the week is still recoverable. Prioritize the next remaining weekly commitment.';
    }

    if (_doneToday == _totalToday && _totalToday > 0) {
      return 'You finished today cleanly. Avoid adding noise; protect recovery, sleep, and tomorrow’s first commitment.';
    }

    if (_upcomingToday > 0) {
      return 'Prepare for the next scheduled window. The goal is to make execution feel automatic when it opens.';
    }

    if (_currentStreak >= 7) {
      return 'Your streak is becoming an asset. Keep the system boring, repeatable, and hard to break.';
    }

    return 'Start with one clear commitment. Consistency compounds when the next action is obvious.';
  }

  String _plural(int value, String word) {
    return '$value $word${value == 1 ? '' : 's'}';
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.26),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeroCard() {
    return _glassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        color: Color(0xFFF8F8F8),
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _heroTitle,
                      style: const TextStyle(
                        color: Color(0xFFF8F8F8),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _heroMessage,
                      style: const TextStyle(
                        color: Color(0xFF9D9DA8),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _ProgressRing(
                value: _todayCompletionRate,
                centerText: '$_todayPercent%',
                footerText: 'today',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '$_currentStreak',
                  label: 'day streak',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  value: '$_totalDoneAllTime',
                  label: 'all-time done',
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    return _glassCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Today',
            subtitle: _totalToday == 0
                ? 'No scheduled execution data.'
                : '${_plural(_doneToday, 'done')} of ${_plural(_totalToday, 'commitment')}',
          ),
          const SizedBox(height: 16),
          _BigProgressBar(
            value: _todayCompletionRate,
            label: 'Completion',
            trailing: '$_doneToday / $_totalToday',
          ),
          const SizedBox(height: 12),
          _BigProgressBar(
            value: _todayRecoverabilityRate,
            label: 'Still recoverable',
            trailing: '${(_todayRecoverabilityRate * 100).round()}%',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatusPill(
                  label: 'Now',
                  value: '$_availableNowToday',
                  icon: Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusPill(
                  label: 'Later',
                  value: '$_upcomingToday',
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusPill(
                  label: 'Missed',
                  value: '$_missedToday',
                  icon: Icons.close_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard() {
    return _glassCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'This week',
            subtitle: _totalThisWeek == 0
                ? 'No weekly commitments recorded.'
                : '${_plural(_doneThisWeek, 'complete')} across ${_plural(_totalThisWeek, 'scheduled item')}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WeekNumber(
                  value: '$_doneThisWeek',
                  label: 'Done',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekNumber(
                  value: '$_remainingThisWeek',
                  label: 'Recoverable',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekNumber(
                  value: '$_missedThisWeek',
                  label: 'Missed',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BigProgressBar(
            value: _weekCompletionRate,
            label: 'Weekly completion',
            trailing: '${(_weekCompletionRate * 100).round()}%',
          ),
          const SizedBox(height: 12),
          _BigProgressBar(
            value: _weekRecoverabilityRate,
            label: 'Weekly recoverability',
            trailing: '${(_weekRecoverabilityRate * 100).round()}%',
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return _glassCard(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF202026),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF303038)),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFF8F8F8),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Best next move',
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _recommendation,
                  style: const TextStyle(
                    color: Color(0xFFA9A9B3),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _glassCard(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(28),
      child: const Column(
        children: [
          Icon(
            Icons.insights_rounded,
            color: Color(0xFF777780),
            size: 38,
          ),
          SizedBox(height: 14),
          Text(
            'No progress data yet',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Once you complete scheduled commitments, your streaks and execution patterns will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9D9DA8),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF8F8F8),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB8B8C0),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final hasAnyData = _totalToday > 0 ||
        _totalThisWeek > 0 ||
        _totalDoneAllTime > 0 ||
        _currentStreak > 0;

    return HoldToRefreshWrapper(
      onRefresh: _loadProgressData,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            if (hasAnyData) ...[
              _buildTodayCard(),
              _buildRecentCompletionsCard(),
              _buildWeekCard(),
              _buildRecommendationCard(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.centerText,
    required this.footerText,
  });

  final double value;
  final String centerText;
  final String footerText;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return SizedBox(
      width: 106,
      height: 106,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(106, 106),
            painter: _RingPainter(value: safeValue),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerText,
                style: const TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                footerText,
                style: const TextStyle(
                  color: Color(0xFF8C8C96),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;

    final trackPaint = Paint()
      ..color = const Color(0xFF25252B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF8F8F8),
          Color(0xFF9D9DA8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B32)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFF8F8F8),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8C8C96),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8C8C96),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigProgressBar extends StatelessWidget {
  const _BigProgressBar({
    required this.value,
    required this.label,
    required this.trailing,
  });

  final double value;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFA9A9B3),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                color: Color(0xFFF8F8F8),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 11,
            backgroundColor: const Color(0xFF25252B),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFFF8F8F8),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B32)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFF8F8F8),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekNumber extends StatelessWidget {
  const _WeekNumber({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B32)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}