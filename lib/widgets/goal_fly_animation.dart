import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Displays an animated goal card that pops out and flies to the home icon.
///
/// Usage:
/// ```dart
/// GoalFlyAnimation.show(
///   context: context,
///   startRect: _getGoalCardRect(),
///   endPosition: _homeIconPosition,
///   goalText: '50 km in 1 Week',
/// );
/// ```
class GoalFlyAnimation {
  static void show({
    required BuildContext context,
    required Rect startRect,
    required Offset endPosition,
    required String goalText,
    VoidCallback? onComplete,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _GoalFlyWidget(
        startRect: startRect,
        endPosition: endPosition,
        goalText: goalText,
        onComplete: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _GoalFlyWidget extends StatefulWidget {
  final Rect startRect;
  final Offset endPosition;
  final String goalText;
  final VoidCallback onComplete;

  const _GoalFlyWidget({
    required this.startRect,
    required this.endPosition,
    required this.goalText,
    required this.onComplete,
  });

  @override
  State<_GoalFlyWidget> createState() => _GoalFlyWidgetState();
}

class _GoalFlyWidgetState extends State<_GoalFlyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Scale: 1.0 -> 1.2 (pop) -> 0.4 (shrink to destination)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 75,
      ),
    ]).animate(_controller);

    // Opacity: 1.0 throughout, then fade at end
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 85,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(_controller);

    // Position: curved path from start to end
    _positionAnimation = _CurvedPathTween(
      begin: widget.startRect.center,
      end: widget.endPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = _positionAnimation.value;
        final scale = _scaleAnimation.value;
        final opacity = _opacityAnimation.value;

        return Positioned(
          left: position.dx - (60 * scale), // Center the widget
          top: position.dy - (20 * scale),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: _buildGoalCard(),
    );
  }

  Widget _buildGoalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CruizrTheme.accentPink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CruizrTheme.accentPink.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            widget.goalText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom tween that animates along a curved (parabolic) path
class _CurvedPathTween extends Tween<Offset> {
  _CurvedPathTween({required Offset begin, required Offset end})
      : super(begin: begin, end: end);

  @override
  Offset lerp(double t) {
    final start = begin!;
    final finish = end!;

    // Linear interpolation for x
    final x = start.dx + (finish.dx - start.dx) * t;

    // Curved path for y: add a parabolic arc
    // The arc peaks at t=0.3 (early in animation) then drops down
    final linearY = start.dy + (finish.dy - start.dy) * t;

    // Add upward arc in first part, then gravity-like drop
    final arcHeight = -80.0; // How high the arc goes
    final arcProgress = math.sin(t * math.pi * 0.8); // Asymmetric arc
    final y = linearY + arcHeight * arcProgress * (1 - t * 0.5);

    return Offset(x, y);
  }
}
