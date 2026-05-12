import 'dart:async';
import 'package:achievr_app/Services/app_clock.dart';
import 'package:flutter/material.dart';

class HoldToRefreshWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const HoldToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<HoldToRefreshWrapper> createState() => _HoldToRefreshWrapperState();
}

class _HoldToRefreshWrapperState extends State<HoldToRefreshWrapper> {
  static const double _triggerDistance = 120;
  static const double _maxPullDistance = 150;
  static const Duration _holdDuration = Duration(milliseconds: 900);

  double _pullDistance = 0;
  bool _armed = false;
  bool _isRefreshing = false;
  bool _holdComplete = false;

  Timer? _holdTimer;
  DateTime? _holdStart;

  void _startHoldTimer() {
    if (_holdTimer != null || _isRefreshing || _holdComplete) return;

    _holdStart = AppClock.now();
    _holdTimer = Timer(_holdDuration, () async {
      if (!mounted) return;

      setState(() {
        _holdComplete = true;
      });

      await _triggerRefresh();
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdStart = null;
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.onRefresh();
    } finally {
      _cancelHoldTimer();

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 250));

        setState(() {
          _pullDistance = 0;
          _armed = false;
          _isRefreshing = false;
          _holdComplete = false;
        });
      }
    }
  }

  void _resetPull() {
    _cancelHoldTimer();

    if (!mounted) return;

    setState(() {
      _pullDistance = 0;
      _armed = false;
      _holdComplete = false;
    });
  }

  bool _atTop() {
    final controller = PrimaryScrollController.of(context);
    return controller.positions.isEmpty || controller.offset <= 0;
  }

  String get _label {
    if (_isRefreshing) return 'Reloading...';
    if (_pullDistance < _triggerDistance) return 'Pull down to reload';
    if (_holdComplete) return 'Reloading...';
    return 'Hold to reload';
  }

  double get _progress {
    if (_isRefreshing) return 1.0;

    if (_pullDistance < _triggerDistance) {
      return (_pullDistance / _triggerDistance).clamp(0.0, 1.0);
    }

    if (_holdStart == null) return 1.0;

    final elapsed = AppClock.now().difference(_holdStart!).inMilliseconds;
    return (elapsed / _holdDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _cancelHoldTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicatorHeight = _pullDistance.clamp(0.0, _maxPullDistance);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (_isRefreshing) return;
        if (!_atTop()) return;

        final delta = details.delta.dy;

        if (delta > 0) {
          setState(() {
            _pullDistance =
                (_pullDistance + delta).clamp(0.0, _maxPullDistance);
            _armed = _pullDistance >= _triggerDistance;
          });

          if (_armed) {
            _startHoldTimer();
          }
        } else {
          setState(() {
            _pullDistance =
                (_pullDistance + delta).clamp(0.0, _maxPullDistance);

            if (_pullDistance < _triggerDistance) {
              _armed = false;
              _holdComplete = false;
            }
          });

          if (!_armed) {
            _cancelHoldTimer();
          }
        }
      },
      onVerticalDragEnd: (_) {
        if (!_holdComplete && !_isRefreshing) {
          _resetPull();
        }
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: indicatorHeight,
            alignment: Alignment.center,
            child: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFFF5F5F5),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 2.4,
                          color: const Color(0xFFF5F5F5),
                          backgroundColor: const Color(0xFF2A2A2F),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _label,
                        style: const TextStyle(
                          color: Color(0xFFB3B3BB),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}