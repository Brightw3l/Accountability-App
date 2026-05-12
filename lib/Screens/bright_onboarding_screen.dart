import 'package:achievr_app/Services/ai_onboarding_service.dart';
import 'package:achievr_app/Screens/ai_generated_plan_review_screen.dart'
    as ai_review;
import 'package:flutter/material.dart';

import '../Widgets/primary_button.dart';

class BrightOnboardingScreen extends StatefulWidget {
  const BrightOnboardingScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<BrightOnboardingScreen> createState() => _BrightOnboardingScreenState();
}

class _BrightOnboardingScreenState extends State<BrightOnboardingScreen> {
  final TextEditingController _controller = TextEditingController();
  final AiOnboardingService _aiOnboardingService = AiOnboardingService();

  bool _isGenerating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    final desire = _controller.text.trim();

    if (desire.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tell BRIGHT what you want to fix or build first.'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final plan = await _aiOnboardingService.generateOnboardingPlan(
        desire: desire,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ai_review.AiGeneratedPlanReviewScreen(
            userId: widget.userId,
            plan: plan,
            originalDesire: desire,
          ),
        ),
      );
    } catch (e) {
      debugPrint('BRIGHT onboarding generation failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BRIGHT failed to generate your plan: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Widget _exampleChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF2B2B32)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFB8B8C0),
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFF8F8F8),
            size: 28,
          ),
          SizedBox(height: 16),
          Text(
            'Build with BRIGHT',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.9,
              height: 1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Describe what you want to fix, build, or become consistent with. BRIGHT will turn it into goals, habits, verification rules, and a schedule preference.',
            style: TextStyle(
              color: Color(0xFFA9A9B3),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptInput() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you need help with?',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be honest. BRIGHT is not just creating what sounds nice; it is building what you need to execute.',
            style: TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 9,
            style: const TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: const Color(0xFFF8F8F8),
            decoration: InputDecoration(
              hintText:
                  'Example: I waste evenings, keep skipping workouts, sleep too late, and need a realistic routine for studying after school.',
              hintStyle: const TextStyle(
                color: Color(0xFF777780),
                fontSize: 13,
                height: 1.4,
              ),
              filled: true,
              fillColor: const Color(0xFF101013),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFF2B2B32)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFF2B2B32)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFF8F8F8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamples() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Examples',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _exampleChip(
                'I want to study consistently and stop wasting evenings.',
              ),
              _exampleChip(
                'I need to work out 3 times a week but I keep skipping it.',
              ),
              _exampleChip(
                'I sleep late, lose mornings, and need a better daily routine.',
              ),
              _exampleChip(
                'I want to build discipline for coding and schoolwork.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: _isGenerating
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF8F8F8),
              ),
            )
          : PrimaryButton(
              text: 'Generate My Plan',
              onPressed: _generatePlan,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF8F8F8)),
        title: const Text(
          'BRIGHT Setup',
          style: TextStyle(
            color: Color(0xFFF8F8F8),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                children: [
                  _buildHeader(),
                  _buildPromptInput(),
                  _buildExamples(),
                ],
              ),
            ),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }
}