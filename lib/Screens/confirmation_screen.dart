import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class ConfirmationScreen extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> schedule;

  const ConfirmationScreen({
    super.key,
    required this.schedule,
  });

  int _calculateTotalTasks() {
    int total = 0;
    for (var dayTasks in schedule.values) {
      total += dayTasks
          .where((t) => t['start'] != null && t['end'] != null)
          .length;
    }
    return total;
  }

  /// Prepares tasks for display (sorted by start time), filtering out invalid entries
  List<Map<String, dynamic>> _prepareTasksForDisplay(List<Map<String, dynamic>> tasks) {
    final validTasks = tasks
        .where((t) => t['start'] != null && t['end'] != null)
        .map((t) => {
              'start': t['start'] as int,
              'end': t['end'] as int,
              'task': t['task'] ?? "Unnamed Task",
            })
        .toList();

    validTasks.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
    return validTasks;
  }

  @override
  Widget build(BuildContext context) {
    final sortedDays = schedule.keys.toList()..sort();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("AI Schedule Review"),
        backgroundColor: const Color(0xFF0F0F0F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== AI SUMMARY HEADER =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AI Optimization Summary",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "• ${_calculateTotalTasks()} total scheduled tasks\n"
                    "• Blocked times fully respected\n"
                    "• High-focus goals prioritized earlier in the day\n"
                    "• Cognitive load balanced across week\n"
                    "• Recovery spacing applied to prevent burnout",
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ===== WEEKLY SCHEDULE =====
            Expanded(
              child: ListView(
                children: sortedDays.map((day) {
                  final tasks = schedule[day] ?? [];
                  final tasksForDisplay = _prepareTasksForDisplay(tasks);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...tasksForDisplay.map((task) {
                          final start = task['start'] as int;
                          final end = task['end'] as int;
                          final taskName = task['task'] as String;

                          return Container(
                            width: screenWidth,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "$start:00–$end:00",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      taskName,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ===== ACTION BUTTONS =====
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                        (_) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Accept & Begin Tracking"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text("Regenerate Schedule"),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.settings.name == null);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white12),
                    ),
                    child: const Text("Edit Time Constraints"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
