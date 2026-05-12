import 'package:achievr_app/Services/ai_onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Widgets/primary_button.dart';
import 'time_constraint_screen.dart';

class AiGeneratedPlanReviewScreen extends StatefulWidget {
  const AiGeneratedPlanReviewScreen({
    super.key,
    required this.userId,
    required this.plan,
    required this.originalDesire,
  });

  final String userId;
  final AiGeneratedPlan plan;
  final String originalDesire;

  @override
  State<AiGeneratedPlanReviewScreen> createState() =>
      _AiGeneratedPlanReviewScreenState();
}

class _AiGeneratedPlanReviewScreenState
    extends State<AiGeneratedPlanReviewScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isApplying = false;

  Future<void> _usePlan() async {
    if (_isApplying) return;

    setState(() {
      _isApplying = true;
    });

    try {
      await supabase.from('goals').delete().eq('user_id', widget.userId);
      await supabase
          .from('fixed_time_blocks')
          .delete()
          .eq('user_id', widget.userId);

      final List<Map<String, dynamic>> detailedGoals = [];

      for (final aiGoal in widget.plan.goals) {
        final insertedGoalRaw = await supabase
            .from('goals')
            .insert({
              'user_id': widget.userId,
              'goal_template_id': null,
              'title': aiGoal.title,
              'category': aiGoal.category,
              'description': aiGoal.description,
              'why': aiGoal.why,
              'success_metric': aiGoal.successMetric,
              'active': true,
              'source': 'ai_onboarding',
              'ai_plan_id': widget.plan.planId,
            })
            .select(
              'goal_id, goal_template_id, title, category, description, why, success_metric',
            )
            .single();

        final insertedGoal = Map<String, dynamic>.from(insertedGoalRaw);
        final List<Map<String, dynamic>> insertedHabits = [];

        for (final aiHabit in aiGoal.habits) {
          final insertedHabitRaw = await supabase
              .from('habits')
              .insert({
                'goal_id': insertedGoal['goal_id'],
                'habit_template_id': null,
                'title': aiHabit.title,
                'description': aiHabit.description,
                'target_frequency': aiHabit.targetFrequency,
                'duration_minutes': aiHabit.durationMinutes,
                'verification_type': aiHabit.verificationType,
                'evidence_type': aiHabit.evidenceType,
                'enforcement_level': aiHabit.enforcementLevel,
                'min_valid_minutes': aiHabit.minValidMinutes,
                'min_completion_ratio': aiHabit.minCompletionRatio,
                'max_interruptions': aiHabit.maxInterruptions,
                'grace_seconds': aiHabit.graceSeconds,
                'strict_fail_on_exit': aiHabit.strictFailOnExit,
                'requires_verifier': aiHabit.requiresVerifier,
                'base_points': aiHabit.basePoints,
                'penalty_points': aiHabit.penaltyPoints,
                'tier_weight': aiHabit.tierWeight,
                'verification_locked': true,
                'active': true,
                'source': 'ai_onboarding',
                'ai_plan_id': widget.plan.planId,
                'preferred_time_of_day': aiHabit.preferredTimeOfDay,
                'preferred_days': aiHabit.preferredDays,
                'review_after_days': aiHabit.reviewAfterDays,
                'progression_policy': aiHabit.progressionPolicy,
              })
              .select('''
                habit_id,
                habit_template_id,
                title,
                description,
                target_frequency,
                duration_minutes,
                verification_type,
                verification_locked,
                requires_verifier,
                evidence_type,
                enforcement_level,
                min_valid_minutes,
                min_completion_ratio,
                max_interruptions,
                grace_seconds,
                strict_fail_on_exit,
                base_points,
                penalty_points,
                tier_weight,
                preferred_time_of_day,
                preferred_days,
                review_after_days,
                progression_policy
              ''')
              .single();

          insertedHabits.add(Map<String, dynamic>.from(insertedHabitRaw));
        }

        detailedGoals.add({
          'goal_id': insertedGoal['goal_id'],
          'goal_template_id': insertedGoal['goal_template_id'],
          'title': insertedGoal['title'],
          'category': insertedGoal['category'],
          'description': insertedGoal['description'] ?? '',
          'why': insertedGoal['why'] ?? '',
          'metrics': insertedGoal['success_metric'] ?? '',
          'habits': insertedHabits,
        });
      }

      await supabase.from('ai_onboarding_plans').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('plan_id', widget.plan.planId).eq('user_id', widget.userId);

      await supabase.from('profiles').update({
        'onboarding_step': 3,
      }).eq('id', widget.userId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TimeConstraintScreen(
            detailedGoals: detailedGoals,
            userId: widget.userId,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('AI plan apply database error: ${e.message}');

      if (!mounted) return;

      setState(() {
        _isApplying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database error: ${e.message}')),
      );
    } catch (e, st) {
      debugPrint('AI plan apply error: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      setState(() {
        _isApplying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply AI plan: $e')),
      );
    }
  }

  String _verificationLabel(String value) {
    return value.replaceAll('_', ' ');
  }

  String _dayLabel(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _preferredDaysLabel(List<int> days) {
    if (days.isEmpty) return 'schedule flexible';

    final labels = days.map(_dayLabel).where((label) => label.isNotEmpty);
    return labels.join(', ');
  }

  Widget _pill(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202026),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF303038)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF8F8F8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoBlock({
    required String title,
    required String body,
  }) {
    if (body.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2B2B32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitTile(AiGeneratedHabit habit) {
    final progressionText = habit.progressionPolicy.isEmpty
        ? 'Review after ${habit.reviewAfterDays} days.'
        : 'Review after ${habit.reviewAfterDays} days. If consistent, BRIGHT may recommend +${habit.progressionPolicy['increase_duration_by_minutes'] ?? 10} minutes.';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.title,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (habit.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              habit.description,
              style: const TextStyle(
                color: Color(0xFF9D9DA8),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('${habit.durationMinutes} min'),
              _pill(habit.targetFrequency),
              _pill(_verificationLabel(habit.verificationType)),
              _pill(habit.preferredTimeOfDay),
              _pill(_preferredDaysLabel(habit.preferredDays)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            progressionText,
            style: const TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(AiGeneratedGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(goal.category),
              _pill(
                '${goal.habits.length} habit${goal.habits.length == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            goal.title,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal.description,
            style: const TextStyle(
              color: Color(0xFFA9A9B3),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _infoBlock(
            title: 'Why this matters',
            body: goal.why,
          ),
          const SizedBox(height: 10),
          _infoBlock(
            title: 'Success metric',
            body: goal.successMetric,
          ),
          const SizedBox(height: 16),
          const Text(
            'Habits',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...goal.habits.map(_habitTile),
        ],
      ),
    );
  }

  Widget _requestCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF292930)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your request',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.originalDesire,
            style: const TextStyle(
              color: Color(0xFFA9A9B3),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalHabits = widget.plan.goals.fold<int>(
      0,
      (total, goal) => total + goal.habits.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF8F8F8)),
        title: const Text(
          'Review BRIGHT Plan',
          style: TextStyle(
            color: Color(0xFFF8F8F8),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                children: [
                  Text(
                    'BRIGHT created ${widget.plan.goals.length} goal${widget.plan.goals.length == 1 ? '' : 's'} and $totalHabits habit${totalHabits == 1 ? '' : 's'} for your setup.',
                    style: const TextStyle(
                      color: Color(0xFFB8B8C0),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _requestCard(),
                  ...widget.plan.goals.map(_goalCard),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: _isApplying
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF8F8F8),
                      ),
                    )
                  : PrimaryButton(
                      text: 'Use This Plan',
                      onPressed: _usePlan,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}