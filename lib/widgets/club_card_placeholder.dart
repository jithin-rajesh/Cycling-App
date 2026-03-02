import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A beautiful gradient placeholder for club cards and headers.
/// Each activity type gets a unique gradient and icon.
class ClubCardPlaceholder extends StatelessWidget {
  final String activityType;
  final String clubName;
  final double? height;
  final BorderRadius? borderRadius;
  final int? customIconCodePoint;

  const ClubCardPlaceholder({
    super.key,
    required this.activityType,
    required this.clubName,
    this.height,
    this.borderRadius,
    this.customIconCodePoint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _getPalette(activityType);
    final displayIcon = customIconCodePoint != null
        ? IconData(customIconCodePoint!, fontFamily: 'MaterialIcons')
        : palette.icon;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.colors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Subtle pattern overlay
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              displayIcon,
              size: 160,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: Icon(
              displayIcon,
              size: 60,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          // Center icon
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    displayIcon,
                    size: 28,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activityType,
                  style: GoogleFonts.lato(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _GradientPalette _getPalette(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return _GradientPalette(
          colors: [
            const Color(0xFFD97D84), // Warm rose
            const Color(0xFFB85D65), // Deeper rose
            const Color(0xFF8B3A42), // Dark rose
          ],
          icon: Icons.directions_bike,
        );
      case 'running':
        return _GradientPalette(
          colors: [
            const Color(0xFF7DBED9), // Soft sky blue
            const Color(0xFF5A9BB5), // Mid blue
            const Color(0xFF3A7A8B), // Deep teal
          ],
          icon: Icons.directions_run,
        );
      case 'gym':
        return _GradientPalette(
          colors: [
            const Color(0xFF9B7DDB), // Soft purple
            const Color(0xFF7B5DBB), // Mid purple
            const Color(0xFF5A3D9B), // Deep purple
          ],
          icon: Icons.fitness_center,
        );
      default: // Mixed or unknown
        return _GradientPalette(
          colors: [
            const Color(0xFF4A3438), // Dark brown (primaryDark)
            const Color(0xFF6B4E52), // Mid brown
            const Color(0xFFD97D84), // Accent pink
          ],
          icon: Icons.groups,
        );
    }
  }
}

class _GradientPalette {
  final List<Color> colors;
  final IconData icon;

  const _GradientPalette({required this.colors, required this.icon});
}
