import 'package:flutter/material.dart';
import 'goal_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  AnimationController? _fadeOutController;

  late Animation<double> _opacityIn;
  Animation<double>? _opacityOut;

  @override
  void initState() {
    super.initState();

    // ---- FADE-IN ----
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _opacityIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOutCubic),
    );

    _fadeInController.forward();

    // Start fade-out after short delay
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      _startFadeOut();
    });
  }

  void _startFadeOut() {
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200), // <- CHANGEABLE
    );

    _opacityOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController!, curve: Curves.easeInOut),
    );

    _fadeOutController!.forward();

    // Navigate when fade-out completes
    _fadeOutController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const GoalSetupIntroScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _fadeOutController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: AnimatedBuilder(
        animation: _fadeInController,
        builder: (context, child) {
          // Combine fade-in and fade-out
          double opacity = _opacityIn.value;
          if (_fadeOutController?.isAnimating ?? false) {
            opacity *= _opacityOut!.value;
          }

          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
        child: Center(
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'achievr',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Color(0xFFF5F5F5),
                  ),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C7C7C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
