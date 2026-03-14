import 'package:achievr_app/Services/app_clock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitLogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> generateTodayLogs() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final today = AppClock.today();
    final dateString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    await _supabase.rpc(
      'generate_daily_habit_logs',
      params: {
        'p_user_id': user.id,
        'p_date': dateString,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchTodayLogs() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final today = AppClock.today();
    final dateString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    final response = await _supabase
        .from('habit_logs')
        .select('''
          log_id,
          log_date,
          status,
          scheduled_start,
          scheduled_end,
          verification_type,
          habits (
            habit_id,
            title,
            goal_id,
            goals (
              goal_id,
              title
            )
          )
        ''')
        .eq('user_id', user.id)
        .eq('log_date', dateString)
        .order('scheduled_start');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markLogDone({
    required String logId,
  }) async {
    await _supabase
        .from('habit_logs')
        .update({
          'status': 'done',
          'closed_at': AppClock.now().toIso8601String(),
        })
        .eq('log_id', logId);
  }
}