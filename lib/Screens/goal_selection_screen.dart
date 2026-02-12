import 'package:flutter/material.dart';
import 'goal_input_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  final Set<String> _selectedGoals = {};

  final Map<String, List<String>> _goalCategories = {
    "Health & Fitness": [
      "Build Strength",
      "Lose Weight",
      "Improve Endurance",
      "Sleep Discipline",
      "Daily Movement",
    ],
    "Career & Productivity": [
      "Deep Work Routine",
      "Launch a Project",
      "Skill Development",
      "Networking Consistency",
      "Daily Output Target",
    ],
    "Mental & Emotional": [
      "Meditation Practice",
      "Reduce Screen Time",
      "Journaling Habit",
      "Emotional Regulation",
      "Stress Management",
    ],
    "Financial": [
      "Increase Income",
      "Savings Discipline",
      "Budget Tracking",
      "Debt Reduction",
      "Investment Learning",
    ],
    "Personal Growth": [
      "Reading Habit",
      "Public Speaking",
      "Creative Practice",
      "Social Confidence",
      "Language Learning",
    ],
  };

  void _toggleGoal(String goal) {
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else {
        if (_selectedGoals.length < 3) {
          _selectedGoals.add(goal);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _selectedGoals.length == 3;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          "Select 3 Focus Areas",
          style: TextStyle(color: Color(0xFFF5F5F5)),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Choose exactly three broad goals.\nYou will define them in detail next.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFAAAAAA),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _goalCategories.entries.map((entry) {
                return _buildCategory(entry.key, entry.value);
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFF333333),
                  foregroundColor: canContinue ? Colors.black : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: canContinue
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalInputScreen(
                              selectedGoals: _selectedGoals.toList(),
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  canContinue
                      ? "Continue"
                      : "Select ${3 - _selectedGoals.length} more",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<String> goals) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: goals.map((goal) {
              final bool isSelected = _selectedGoals.contains(goal);

              return GestureDetector(
                onTap: () => _toggleGoal(goal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF5F5F5)
                        : const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF5F5F5)
                          : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Text(
                    goal,
                    style: TextStyle(
                      color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
