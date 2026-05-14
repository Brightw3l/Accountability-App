import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedPointsText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedPointsText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<AnimatedPointsText> createState() => _AnimatedPointsTextState();
}

class _AnimatedPointsTextState extends State<AnimatedPointsText> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedPointsText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '${widget.prefix}${value.round()}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

class PointsDeltaOverlay {
  PointsDeltaOverlay._();

  static OverlayEntry? _activeEntry;
  static Timer? _removeTimer;

  static OverlayEntry show(
    BuildContext context, {
    required int delta,
    Offset? anchor,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    _removeTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return _RewardPopup(
          delta: delta,
          duration: duration,
          onFinished: () {
            if (_activeEntry == entry) {
              _activeEntry = null;
            }

            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _removeTimer = Timer(duration + const Duration(milliseconds: 120), () {
      if (_activeEntry == entry) {
        _activeEntry = null;
      }

      if (entry.mounted) {
        entry.remove();
      }
    });

    return entry;
  }
}

class _RewardPopup extends StatefulWidget {
  final int delta;
  final Duration duration;
  final VoidCallback onFinished;

  const _RewardPopup({
    required this.delta,
    required this.duration,
    required this.onFinished,
  });

  @override
  State<_RewardPopup> createState() => _RewardPopupState();
}

class _RewardPopupState extends State<_RewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
    ]).animate(_controller);

    _lift = Tween<double>(
      begin: 10,
      end: -8,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller);

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _positive => widget.delta >= 0;

  String get _pointsText {
    final sign = _positive ? '+' : '-';
    return '$sign${widget.delta.abs()}';
  }

  String get _rewardTitle {
    if (_positive) return 'Reward earned';
    return 'Penalty applied';
  }

  String get _rewardSubtitle {
    if (_positive) return 'XP added';
    return 'XP deducted';
  }

  Color get _accentColor {
    if (_positive) return const Color(0xFF6EE7A8);
    return const Color(0xFFFF8A80);
  }

  IconData get _icon {
    if (_positive) return Icons.workspace_premium_rounded;
    return Icons.remove_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _fade.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, _lift.value),
                        child: Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: 190,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xF2151519),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _accentColor.withValues(alpha:0.55),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentColor.withValues(alpha:0.18),
                                  blurRadius: 34,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:0.32),
                                  blurRadius: 28,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _accentColor.withValues(alpha:0.14),
                                    border: Border.all(
                                      color: _accentColor.withValues(alpha:0.45),
                                    ),
                                  ),
                                  child: Icon(
                                    _icon,
                                    color: _accentColor,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _rewardTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF8F8F8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.1,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '$_pointsText XP',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _accentColor,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    letterSpacing: -0.8,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _rewardSubtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFA9A9B3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}