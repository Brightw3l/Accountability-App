import 'package:flutter_riverpod/flutter_riverpod.dart';

// State: Blocked hours map (day -> set of hours)
final blockedHoursProvider = StateNotifierProvider<BlockedHoursNotifier, Map<String, Set<int>>>(
  (ref) => BlockedHoursNotifier(),
);

class BlockedHoursNotifier extends StateNotifier<Map<String, Set<int>>> {
  BlockedHoursNotifier()
      : super({
          "Mon": {},
          "Tue": {},
          "Wed": {},
          "Thu": {},
          "Fri": {},
          "Sat": {},
        });

  void toggle(String day, int hour) {
    final currentSet = state[day] ?? {};
    final newSet = Set<int>.from(currentSet);

    if (newSet.contains(hour)) {
      newSet.remove(hour);
    } else {
      newSet.add(hour);
    }

    state = {...state, day: newSet};
  }
}
