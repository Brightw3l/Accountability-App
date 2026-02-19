import 'package:flutter/material.dart';
import 'confirmation_screen.dart';

class AISchedulingLoadingScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> schedule;

  const AISchedulingLoadingScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<AISchedulingLoadingScreen> createState() =>
      _AISchedulingLoadingScreenState();
}

class _AISchedulingLoadingScreenState
    extends State<AISchedulingLoadingScreen> {

  @override
  void initState() {
    super.initState();
    _simulateAIProcessing();
  }

  Future<void> _simulateAIProcessing() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          schedule: widget.schedule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              "AI is optimizing your week...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
