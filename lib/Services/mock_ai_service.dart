class MockAIService {
  static Map<String, List<Map<String, dynamic>>> generateSchedule({
    required List<Map<String, String>> goals,
    required Map<String, Set<int>> blockedHours,
  }) {
    final Map<String, List<Map<String, dynamic>>> schedule = {};
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final int tasksPerDay = 2; // at least 2 tasks per day

    int goalIndex = 0;

    // Initialize schedule for each day
    for (var day in days) {
      schedule[day] = [];
    }

    for (var day in days) {
      int tasksScheduledToday = 0;

      for (int hour = 6; hour <= 22; hour++) {
        if (tasksScheduledToday >= tasksPerDay) break;

        // Skip blocked hours or already scheduled
        if (!blockedHours[day]!.contains(hour) &&
            !schedule[day]!.any((t) => t['start'] == hour)) {
          // Schedule the task
          schedule[day]!.add({
            "start": hour,
            "end": hour + 1,
            "task": "${goals[goalIndex]["title"]} work session",
          });

          tasksScheduledToday++;
          goalIndex = (goalIndex + 1) % goals.length; // cycle goals
        }
      }
    }

    return schedule;
  }
}
