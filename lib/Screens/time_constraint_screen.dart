import 'package:flutter/material.dart';
import 'confirmation_screen.dart';

class TimeConstraintScreen extends StatefulWidget {
  final List<Map<String, String>> detailedGoals;

  const TimeConstraintScreen({super.key, required this.detailedGoals});

  @override
  State<TimeConstraintScreen> createState() => _TimeConstraintScreenState();
}

class _TimeConstraintScreenState extends State<TimeConstraintScreen> {
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<int> hours = List.generate(18, (index) => 6 + index); // 6AM-11PM

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Blocked Time"),
        backgroundColor: const Color(0xFF0F0F0F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Select times when you are unavailable.\n"
              "AI will avoid scheduling goals during these blocks.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: days.map((day) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: hours.map((hour) {
                              final isBlocked = blockedHours[day]!.contains(hour);
                              return GestureDetector(
                                onTap: () => _toggleBlock(day, hour),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  width: 40,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isBlocked
                                        ? Colors.black
                                        : const Color(0xFF1C1C1C),
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "${hour}:00",
                                    style: TextStyle(
                                        color: isBlocked
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 12),
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: save blockedHours somewhere or pass to AI scheduler
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConfirmationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Continue"),
              ),
            )
          ],
        ),
      ),
      backgroundColor: const Color(0xFF0F0F0F),
    );
  }
}
