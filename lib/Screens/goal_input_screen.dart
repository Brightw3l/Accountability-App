import 'package:flutter/material.dart';
import 'time_constraint_screen.dart';

class GoalInputScreen extends StatefulWidget {
  final List<String> selectedGoals;

  const GoalInputScreen({super.key, required this.selectedGoals});

  @override
  State<GoalInputScreen> createState() => _GoalInputScreenState();
}

class _GoalInputScreenState extends State<GoalInputScreen> {
  late List<TextEditingController> _descriptionControllers;
  late List<TextEditingController> _whyControllers;
  late List<TextEditingController> _metricsControllers;

  @override
  void initState() {
    super.initState();
    _descriptionControllers = widget.selectedGoals
        .map((_) => TextEditingController())
        .toList();
    _whyControllers =
        widget.selectedGoals.map((_) => TextEditingController()).toList();
    _metricsControllers =
        widget.selectedGoals.map((_) => TextEditingController()).toList();
  }

  @override
  void dispose() {
    for (var c in _descriptionControllers) {
      c.dispose();
    }
    for (var c in _whyControllers) {
      c.dispose();
    }
    for (var c in _metricsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get allFilled {
    for (int i = 0; i < widget.selectedGoals.length; i++) {
      if (_descriptionControllers[i].text.isEmpty ||
          _whyControllers[i].text.isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _goNext() {
    if (!allFilled) return;

    final List<Map<String, String>> detailedGoals = [];
    for (int i = 0; i < widget.selectedGoals.length; i++) {
      detailedGoals.add({
        "title": widget.selectedGoals[i],
        "description": _descriptionControllers[i].text,
        "why": _whyControllers[i].text,
        "metrics": _metricsControllers[i].text,
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimeConstraintScreen(detailedGoals: detailedGoals),
      ),
    );
  }

  Widget _buildGoalForm(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedGoals[index],
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionControllers[index],
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Describe the goal",
              hintText: "What exactly do you want to achieve?",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFF1C1C1C),
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whyControllers[index],
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Why does it matter?",
              hintText:
                  "Why is this goal important to you? How will it impact your life?",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFF1C1C1C),
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metricsControllers[index],
            maxLines: 1,
            decoration: const InputDecoration(
              labelText: "How will you measure progress? (Optional)",
              hintText: "E.g., 5 push-ups/day, \$500 savings/month",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFF1C1C1C),
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text("Elaborate Your Goals"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.selectedGoals.length,
                itemBuilder: (_, index) => _buildGoalForm(index),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: allFilled ? _goNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allFilled ? const Color(0xFFF5F5F5) : Colors.grey[800],
                  foregroundColor: allFilled ? Colors.black : Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
