import 'package:flutter/material.dart';
import '../services/mock_ai_service.dart';
import 'ai_loading_screen.dart';

class TimeConstraintScreen extends StatefulWidget {
  final List<Map<String, String>> detailedGoals;

  const TimeConstraintScreen({super.key, required this.detailedGoals});

  @override
  State<TimeConstraintScreen> createState() => _TimeConstraintScreenState();
}

class _TimeConstraintScreenState extends State<TimeConstraintScreen> {
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<int> hours = List.generate(18, (index) => 6 + index); // 6AM–11PM

  late Map<String, Set<int>> blockedHours;

  @override
  void initState() {
    super.initState();
    blockedHours = {for (var day in days) day: <int>{}};
  }

  void _toggleBlock(String day, int hour) {
    setState(() {
      if (blockedHours[day]!.contains(hour)) {
        blockedHours[day]!.remove(hour);
      } else {
        blockedHours[day]!.add(hour);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = screenWidth / (days.length + 1);
    const cellHeight = 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("Blocked Time"),
        backgroundColor: const Color(0xFF0F0F0F),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Select times when you are unavailable.\nAI will avoid scheduling goals during these blocks.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: days.map((day) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(day,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          Column(
                            children: hours.map((hour) {
                              final isBlocked = blockedHours[day]!.contains(hour);
                              return GestureDetector(
                                onTap: () => _toggleBlock(day, hour),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  width: cellWidth * 0.8,
                                  height: cellHeight,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isBlocked
                                        ? Colors.black
                                        : const Color(0xFF1C1C1C),
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "$hour:00",
                                    style: TextStyle(
                                      color: isBlocked
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.detailedGoals.isEmpty
                      ? null
                      : () {
                          final schedule = MockAIService.generateSchedule(
                            goals: widget.detailedGoals,
                            blockedHours: blockedHours,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AISchedulingLoadingScreen(schedule: schedule),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.detailedGoals.isEmpty
                        ? Colors.grey
                        : const Color(0xFFF5F5F5),
                    foregroundColor: widget.detailedGoals.isEmpty
                        ? Colors.black38
                        : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
