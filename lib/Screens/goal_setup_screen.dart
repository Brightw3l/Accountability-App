import 'package:flutter/material.dart';
import 'goal_selection_screen.dart';

class GoalSetupIntroScreen extends StatelessWidget {
  const GoalSetupIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You will define 3 goals.\n\n'
              'These goals will be enforced.\n'
              'Failure will be recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.5,
                color: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  // Navigate to GoalSelectionScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GoalSelectionScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Begin Selection',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
