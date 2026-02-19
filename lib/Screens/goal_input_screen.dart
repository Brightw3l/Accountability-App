import 'package:achievr_app/screens/time_constraint_screen.dart';
import 'package:flutter/material.dart';


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

    _descriptionControllers =
        widget.selectedGoals.map((_) => TextEditingController()).toList();
    _whyControllers =
        widget.selectedGoals.map((_) => TextEditingController()).toList();
    _metricsControllers =
        widget.selectedGoals.map((_) => TextEditingController()).toList();

    // 👇 Listen for changes so button updates live
    for (var c in [
      ..._descriptionControllers,
      ..._whyControllers,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (var c in [
      ..._descriptionControllers,
      ..._whyControllers,
      ..._metricsControllers,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get allFilled {
    for (int i = 0; i < widget.selectedGoals.length; i++) {
      if (_descriptionControllers[i].text.trim().isEmpty ||
          _whyControllers[i].text.trim().isEmpty) {
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
        "description": _descriptionControllers[i].text.trim(),
        "why": _whyControllers[i].text.trim(),
        "metrics": _metricsControllers[i].text.trim(),
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TimeConstraintScreen(detailedGoals: detailedGoals),
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(179, 255, 255, 255), // 179/255 = 0.7 opacity
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          labelText: requiredField ? "$label *" : label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      ),
    );
  }

  Widget _buildGoalForm(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedGoals[index],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),

          _styledField(
            controller: _descriptionControllers[index],
            label: "Define the Outcome",
            hint:
                "What exactly will be different when this goal is achieved?",
            maxLines: 2,
            requiredField: true,
          ),
          const SizedBox(height: 16),

          _styledField(
            controller: _whyControllers[index],
            label: "Emotional Reason",
            hint:
                "Why does this matter deeply to you? What happens if you don't achieve it?",
            maxLines: 2,
            requiredField: true,
          ),
          const SizedBox(height: 16),

          _styledField(
            controller: _metricsControllers[index],
            label: "Success Metric (Optional)",
            hint:
                "E.g., 5 push-ups/day, \$500 savings/month",
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
        elevation: 0,
        title: const Text("Clarify Your Goals"),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: allFilled ? _goNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allFilled ? const Color(0xFFF5F5F5) : Colors.grey[900],
                  foregroundColor:
                      allFilled ? Colors.black : Colors.white38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  "Continue",
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
