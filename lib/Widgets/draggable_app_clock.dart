import 'package:achievr_app/Services/app_clock.dart';
import 'package:flutter/material.dart';

class DraggableAppClock extends StatefulWidget {
  const DraggableAppClock({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<DraggableAppClock> createState() => _DraggableAppClockState();
}

class _DraggableAppClockState extends State<DraggableAppClock> {
  Offset? _position;

  static const double _chipWidth = 86;
  static const double _chipHeight = 36;
  static const double _safePadding = 10;
  static const double _bottomReservedSpace = 96;

  bool _dragStarted = false;
  bool _didMoveDuringDrag = false;

  void _setDefaultPositionIfNeeded(Size size) {
    if (_position != null) return;

    final defaultX = size.width - _chipWidth - _safePadding;
    final defaultY = size.height - _chipHeight - _bottomReservedSpace;

    _position = Offset(defaultX, defaultY);
  }

  void _clampPosition(Size size) {
    final current = _position ?? Offset.zero;

    final maxX = size.width - _chipWidth - _safePadding;
    final maxY = size.height - _chipHeight - _bottomReservedSpace;

    _position = Offset(
      current.dx.clamp(_safePadding, maxX),
      current.dy.clamp(_safePadding, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        _setDefaultPositionIfNeeded(size);
        _clampPosition(size);

        return Stack(
          children: [
            widget.child,
            Positioned(
              left: _position!.dx,
              top: _position!.dy,
              width: _chipWidth,
              height: _chipHeight,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_didMoveDuringDrag) return;
                    widget.onTap();
                  },
                  onPanStart: (_) {
                    _dragStarted = true;
                    _didMoveDuringDrag = false;
                  },
                  onPanUpdate: (details) {
                    if (!_dragStarted) return;

                    setState(() {
                      if (details.delta.distance > 0.2) {
                        _didMoveDuringDrag = true;
                      }

                      _position = _position! + details.delta;
                      _clampPosition(size);
                    });
                  },
                  onPanEnd: (_) {
                    Future.delayed(const Duration(milliseconds: 80), () {
                      if (!mounted) return;
                      _dragStarted = false;
                      _didMoveDuringDrag = false;
                    });
                  },
                  onPanCancel: () {
                    _dragStarted = false;
                    _didMoveDuringDrag = false;
                  },
                  child: const _ClockChip(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.debugNowNotifier,
      builder: (context, debugNow, _) {
        final isDebugging = debugNow != null;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: const Color(0xF217171A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDebugging
                  ? const Color(0xFFFFD166)
                  : const Color(0xFF2A2A2F),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDebugging ? Icons.bolt_rounded : Icons.schedule_rounded,
                color: isDebugging
                    ? const Color(0xFFFFD166)
                    : const Color(0xFFF5F5F5),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                isDebugging ? 'Debug' : 'Clock',
                style: const TextStyle(
                  color: Color(0xFFF5F5F5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}