import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A smooth animated switch widget matching the Cruizr app aesthetic.
/// 
/// Provides a Cupertino-like switch with smooth thumb transitions,
/// theme-matching colors, and a larger hit target for better UX.
class CruizrSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;

  const CruizrSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<CruizrSwitch> createState() => _CruizrSwitchState();
}

class _CruizrSwitchState extends State<CruizrSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _thumbPosition;
  late Animation<Color?> _trackColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _setupAnimations();

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  void _setupAnimations() {
    final activeColor = widget.activeColor ?? CruizrTheme.accentPink;
    final inactiveColor = widget.inactiveColor ?? const Color(0xFFE0D4D4);

    _thumbPosition = Tween<double>(
      begin: 2.0,
      end: 26.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _trackColor = ColorTween(
      begin: inactiveColor,
      end: activeColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(CruizrSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.activeColor != widget.activeColor ||
        oldWidget.inactiveColor != widget.inactiveColor) {
      _setupAnimations();
    }

    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: _trackColor.value,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: _thumbPosition.value,
                  top: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
