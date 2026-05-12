import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Widgets/primary_button.dart';
import 'bright_onboarding_screen.dart';
import 'goal_input_screen.dart';
import 'providers.dart';

class GoalSelectionScreen extends ConsumerStatefulWidget {
  const GoalSelectionScreen({super.key});

  static const int maxGoals = 2;

  @override
  ConsumerState<GoalSelectionScreen> createState() =>
      _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends ConsumerState<GoalSelectionScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _goalTemplates = [];
  Map<String, List<Map<String, dynamic>>> _habitTemplatesByGoalCode = {};

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final goalTemplatesResponse = await supabase
          .from('goal_templates')
          .select(
            'goal_template_id, code, title, description, category, active',
          )
          .eq('active', true)
          .order('category', ascending: true)
          .order('title', ascending: true);

      final habitTemplatesResponse = await supabase
          .from('habit_templates')
          .select('''
            habit_template_id,
            goal_template_id,
            code,
            title,
            description,
            target_frequency,
            duration_minutes,
            verification_type,
            evidence_type,
            enforcement_level,
            min_valid_minutes,
            min_completion_ratio,
            max_interruptions,
            grace_seconds,
            strict_fail_on_exit,
            requires_verifier,
            base_points,
            penalty_points,
            tier_weight,
            active
          ''')
          .eq('active', true)
          .order('created_at', ascending: true);

      final goals = List<Map<String, dynamic>>.from(goalTemplatesResponse);
      final habits = List<Map<String, dynamic>>.from(habitTemplatesResponse);

      final Map<String, List<Map<String, dynamic>>> groupedHabits = {};

      for (final goal in goals) {
        final goalTemplateId = goal['goal_template_id'].toString();
        final goalCode = goal['code'].toString();

        final goalHabits = habits
            .where(
              (habit) =>
                  habit['goal_template_id']?.toString() == goalTemplateId,
            )
            .map((habit) => Map<String, dynamic>.from(habit))
            .toList();

        groupedHabits[goalCode] = goalHabits;
      }

      if (!mounted) return;

      setState(() {
        _goalTemplates = goals;
        _habitTemplatesByGoalCode = groupedHabits;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading goal templates: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load goal templates.\n$e';
        _isLoading = false;
      });
    }
  }

  void _openBrightOnboarding() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrightOnboardingScreen(userId: user.id),
      ),
    );
  }

  Future<void> _saveGoalsAndNavigate(
    BuildContext context,
    Set<String> selectedGoalCodes,
  ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final selectedTemplates = _goalTemplates
          .where((goal) => selectedGoalCodes.contains(goal['code']))
          .toList();

      if (selectedTemplates.length != GoalSelectionScreen.maxGoals) {
        throw Exception(
          'Please select exactly ${GoalSelectionScreen.maxGoals} goals.',
        );
      }

      await supabase.from('goals').delete().eq('user_id', user.id);
      await supabase.from('fixed_time_blocks').delete().eq('user_id', user.id);

      final List<Map<String, dynamic>> goalsToInsert = selectedTemplates
          .map(
            (goalTemplate) => {
              'user_id': user.id,
              'goal_template_id': goalTemplate['goal_template_id'],
              'title': goalTemplate['title'],
              'category': goalTemplate['category'],
              'description': null,
              'why': null,
              'success_metric': null,
              'active': true,
              'source': 'template',
            },
          )
          .toList();

      final insertedGoalsRaw = await supabase
          .from('goals')
          .insert(goalsToInsert)
          .select('goal_id, goal_template_id, title, category');

      final insertedGoalRows =
          List<Map<String, dynamic>>.from(insertedGoalsRaw);

      if (insertedGoalRows.isEmpty) {
        throw Exception('No goals were inserted.');
      }

      final List<Map<String, dynamic>> habitsToInsert = [];
      final Map<String, dynamic> goalHabitsForNextScreen = {};

      for (final insertedGoal in insertedGoalRows) {
        final goalId = insertedGoal['goal_id']?.toString();
        final goalTemplateId = insertedGoal['goal_template_id']?.toString();
        final goalTitle = insertedGoal['title']?.toString();

        if (goalId == null || goalId.isEmpty) {
          throw Exception('Inserted goal is missing goal_id.');
        }

        if (goalTemplateId == null || goalTemplateId.isEmpty) {
          throw Exception('Inserted goal is missing goal_template_id.');
        }

        if (goalTitle == null || goalTitle.isEmpty) {
          throw Exception('Inserted goal is missing title.');
        }

        final matchingTemplate = selectedTemplates.firstWhere(
          (template) =>
              template['goal_template_id']?.toString() == goalTemplateId,
          orElse: () => <String, dynamic>{},
        );

        final goalCode = matchingTemplate['code']?.toString();

        if (goalCode == null || goalCode.isEmpty) {
          throw Exception('Could not resolve selected goal code.');
        }

        final habitTemplates = _habitTemplatesByGoalCode[goalCode] ?? [];

        goalHabitsForNextScreen[goalTitle] = habitTemplates
            .map((habit) => Map<String, dynamic>.from(habit))
            .toList();

        for (final habitTemplate in habitTemplates) {
          habitsToInsert.add({
            'goal_id': goalId,
            'habit_template_id': habitTemplate['habit_template_id'],
            'title': habitTemplate['title'],
            'description': habitTemplate['description'],
            'target_frequency': habitTemplate['target_frequency'],
            'duration_minutes': habitTemplate['duration_minutes'],
            'verification_type': habitTemplate['verification_type'],
            'evidence_type': habitTemplate['evidence_type'],
            'enforcement_level': habitTemplate['enforcement_level'],
            'min_valid_minutes': habitTemplate['min_valid_minutes'],
            'min_completion_ratio': habitTemplate['min_completion_ratio'],
            'max_interruptions': habitTemplate['max_interruptions'],
            'grace_seconds': habitTemplate['grace_seconds'],
            'strict_fail_on_exit': habitTemplate['strict_fail_on_exit'],
            'requires_verifier': habitTemplate['requires_verifier'],
            'base_points': habitTemplate['base_points'],
            'penalty_points': habitTemplate['penalty_points'],
            'tier_weight': habitTemplate['tier_weight'],
            'verification_locked': true,
            'active': true,
            'source': 'template',
          });
        }
      }

      if (habitsToInsert.isNotEmpty) {
        await supabase.from('habits').insert(habitsToInsert);
      }

      await supabase.from('profiles').update({
        'onboarding_step': 2,
      }).eq('id', user.id);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoalInputScreen(
            userId: user.id,
            selectedGoalRecords: insertedGoalRows,
            goalHabits: goalHabitsForNextScreen,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('Postgrest error saving selected goals: ${e.message}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database error: ${e.message}')),
      );
    } catch (e, st) {
      debugPrint('Error saving selected goals: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving goals: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupGoalsByCategory() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final goal in _goalTemplates) {
      final category = (goal['category'] ?? 'Other').toString();
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(goal);
    }

    return grouped;
  }

  int get _totalHabitCount {
    return _habitTemplatesByGoalCode.values.fold<int>(
      0,
      (total, habits) => total + habits.length,
    );
  }

  Widget _screenShell({
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(child: child),
    );
  }

  Widget _buildLoadingState() {
    return _screenShell(
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF8F8F8),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return _screenShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF151519),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF292930)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFF8F8F8),
                  size: 34,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Could not load goals',
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB8B8C0),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loadTemplates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8F8F8),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int selectedCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your focus',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.9,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Pick two areas manually, or let BRIGHT build a custom setup if none of these match what you need.',
            style: TextStyle(
              color: Color(0xFFA9A9B3),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _headerMetric(
                  value: '$selectedCount/${GoalSelectionScreen.maxGoals}',
                  label: 'selected',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _headerMetric(
                  value: '${_goalTemplates.length}',
                  label: 'goal options',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _headerMetric(
                  value: '$_totalHabitCount',
                  label: 'habit templates',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightEntryCard() {
    return GestureDetector(
      onTap: _openBrightOnboarding,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF22222A),
              Color(0xFF151519),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF363640)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.black,
                size: 26,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not seeing your goal?',
                    style: TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Let BRIGHT design a custom goal and habit system for you.',
                    style: TextStyle(
                      color: Color(0xFFA9A9B3),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A31),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF3A3A44)),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFF8F8F8),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<Map<String, dynamic>> goals,
    required Set<String> selectedGoals,
    required dynamic selectedNotifier,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_rounded,
                color: Color(0xFFF8F8F8),
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                '${goals.length}',
                style: const TextStyle(
                  color: Color(0xFF8C8C96),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 380;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: goals.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: compact ? 1 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: compact ? 2.45 : 1.14,
                ),
                itemBuilder: (_, index) {
                  final goal = goals[index];
                  final code = (goal['code'] ?? '').toString();
                  final isSelected = selectedGoals.contains(code);

                  return _buildGoalCard(
                    goal: goal,
                    isSelected: isSelected,
                    onTap: () {
                      selectedNotifier.toggle(
                        code,
                        maxGoals: GoalSelectionScreen.maxGoals,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required Map<String, dynamic> goal,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final goalCode = (goal['code'] ?? '').toString();
    final habitCount = (_habitTemplatesByGoalCode[goalCode] ?? []).length;
    final description = (goal['description'] ?? '').toString();
    final title = (goal['title'] ?? 'Untitled Goal').toString();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF8F8F8)
              : const Color(0xFF1D1D22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF8F8F8)
                : const Color(0xFF2B2B32),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : const Color(0xFF26262D),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : const Color(0xFF3A3A42),
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF8C8C96),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.black : const Color(0xFFF8F8F8),
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withValues(alpha: 0.08)
                          : const Color(0xFF25252B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$habitCount habit${habitCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black.withValues(alpha: 0.72)
                            : const Color(0xFFA9A9B3),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black.withValues(alpha: 0.72)
                              : const Color(0xFF9D9DA8),
                          fontSize: 12,
                          height: 1.32,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required bool canContinue,
    required int selectedCount,
    required Set<String> selectedGoals,
  }) {
    final int remaining = GoalSelectionScreen.maxGoals - selectedCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF292930).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isSaving
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF8F8F8),
                ),
              )
            : PrimaryButton(
                text: canContinue
                    ? 'Continue With Selected Goals'
                    : remaining == 1
                        ? 'Select 1 more goal'
                        : 'Select $remaining more goals',
                onPressed: canContinue
                    ? () => _saveGoalsAndNavigate(
                          context,
                          selectedGoals,
                        )
                    : null,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final selectedNotifier = ref.read(selectedGoalsProvider.notifier);

    final canContinue = selectedGoals.length == GoalSelectionScreen.maxGoals;
    final groupedGoals = _groupGoalsByCategory();

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildHeader(selectedGoals.length),
                  _buildBrightEntryCard(),
                  ...groupedGoals.entries.map(
                    (entry) => _buildCategorySection(
                      category: entry.key,
                      goals: entry.value,
                      selectedGoals: selectedGoals,
                      selectedNotifier: selectedNotifier,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildBottomBar(
              canContinue: canContinue,
              selectedCount: selectedGoals.length,
              selectedGoals: selectedGoals,
            ),
          ],
        ),
      ),
    );
  }
}