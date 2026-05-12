import 'package:supabase_flutter/supabase_flutter.dart';

class AiGeneratedPlan {
  AiGeneratedPlan({
    required this.planId,
    required this.goals,
  });

  final String planId;
  final List<AiGeneratedGoal> goals;

  factory AiGeneratedPlan.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? {};
    final goalsRaw = plan['goals'] as List<dynamic>? ?? [];

    return AiGeneratedPlan(
      planId: json['plan_id'].toString(),
      goals: goalsRaw
          .map(
            (item) => AiGeneratedGoal.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class AiGeneratedGoal {
  AiGeneratedGoal({
    required this.title,
    required this.description,
    required this.category,
    required this.why,
    required this.successMetric,
    required this.habits,
  });

  final String title;
  final String description;
  final String category;
  final String why;
  final String successMetric;
  final List<AiGeneratedHabit> habits;

  factory AiGeneratedGoal.fromJson(Map<String, dynamic> json) {
    final habitsRaw = json['habits'] as List<dynamic>? ?? [];

    return AiGeneratedGoal(
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      why: (json['why'] ?? '').toString(),
      successMetric: (json['success_metric'] ?? '').toString(),
      habits: habitsRaw
          .map(
            (item) => AiGeneratedHabit.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class AiGeneratedHabit {
  AiGeneratedHabit({
    required this.title,
    required this.description,
    required this.targetFrequency,
    required this.durationMinutes,
    required this.verificationType,
    required this.evidenceType,
    required this.enforcementLevel,
    required this.minValidMinutes,
    required this.minCompletionRatio,
    required this.maxInterruptions,
    required this.graceSeconds,
    required this.strictFailOnExit,
    required this.requiresVerifier,
    required this.basePoints,
    required this.penaltyPoints,
    required this.tierWeight,
    required this.preferredTimeOfDay,
    required this.preferredDays,
    required this.reviewAfterDays,
    required this.progressionPolicy,
  });

  final String title;
  final String description;
  final String targetFrequency;
  final int durationMinutes;
  final String verificationType;
  final String evidenceType;
  final int enforcementLevel;
  final int? minValidMinutes;
  final double? minCompletionRatio;
  final int maxInterruptions;
  final int graceSeconds;
  final bool strictFailOnExit;
  final bool requiresVerifier;
  final int basePoints;
  final int penaltyPoints;
  final int tierWeight;
  final String preferredTimeOfDay;

  /// ISO weekday numbers:
  /// Monday = 1, Tuesday = 2, ... Sunday = 7.
  final List<int> preferredDays;

  /// Usually 14. Used later by BRIGHT to decide when to review progression.
  final int reviewAfterDays;

  /// JSON policy for future AI progression:
  /// increase duration if consistent, reduce friction if struggling, etc.
  final Map<String, dynamic> progressionPolicy;

  factory AiGeneratedHabit.fromJson(Map<String, dynamic> json) {
    final preferredDaysRaw = json['preferred_days'] as List<dynamic>? ?? [];

    return AiGeneratedHabit(
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      targetFrequency: (json['target_frequency'] ?? 'daily').toString(),
      durationMinutes: _asInt(json['duration_minutes'], fallback: 60),
      verificationType: (json['verification_type'] ?? 'manual').toString(),
      evidenceType: (json['evidence_type'] ?? 'none').toString(),
      enforcementLevel: _asInt(json['enforcement_level'], fallback: 2),
      minValidMinutes: json['min_valid_minutes'] == null
          ? null
          : _asInt(json['min_valid_minutes'], fallback: 0),
      minCompletionRatio: json['min_completion_ratio'] == null
          ? null
          : _asDouble(json['min_completion_ratio'], fallback: 0.8),
      maxInterruptions: _asInt(json['max_interruptions'], fallback: 0),
      graceSeconds: _asInt(json['grace_seconds'], fallback: 60),
      strictFailOnExit: json['strict_fail_on_exit'] == true,
      requiresVerifier: json['requires_verifier'] == true,
      basePoints: _asInt(json['base_points'], fallback: 20),
      penaltyPoints: _asInt(json['penalty_points'], fallback: 10),
      tierWeight: _asInt(json['tier_weight'], fallback: 1),
      preferredTimeOfDay:
          (json['preferred_time_of_day'] ?? 'anytime').toString(),
      preferredDays: preferredDaysRaw
          .map((day) => _asInt(day, fallback: 1))
          .where((day) => day >= 1 && day <= 7)
          .toSet()
          .toList()
        ..sort(),
      reviewAfterDays: _asInt(json['review_after_days'], fallback: 14),
      progressionPolicy: Map<String, dynamic>.from(
        (json['progression_policy'] as Map?) ?? {},
      ),
    );
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }
}

class AiOnboardingService {
  AiOnboardingService({
    SupabaseClient? client,
  }) : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<AiGeneratedPlan> generateOnboardingPlan({
    required String desire,
  }) async {
    final trimmed = desire.trim();

    if (trimmed.length < 10) {
      throw Exception('Please describe what you want to improve.');
    }

    final response = await _supabase.functions.invoke(
      'ai-onboarding-plan',
      body: {
        'desire': trimmed,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;

      throw Exception(
        data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Failed to generate AI plan.',
      );
    }

    if (response.data is! Map) {
      throw Exception('Invalid AI plan response.');
    }

    return AiGeneratedPlan.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}