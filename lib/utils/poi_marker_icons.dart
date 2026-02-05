import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/poi_model.dart';
import '../theme/app_theme.dart';

/// Generates custom marker icons for each POI category.
/// Icons are small colored circles for a clean look.
class POIMarkerIcons {
  static final Map<POICategory, BitmapDescriptor> _cache = {};
  static bool _initialized = false;

  /// Initialize all marker icons. Call this once at app startup.
  static Future<void> initialize() async {
    if (_initialized) return;

    for (final category in POICategory.values) {
      _cache[category] = await _createMarkerIcon(category);
    }
    _initialized = true;
  }

  /// Get the marker icon for a category.
  /// Returns default marker if not initialized.
  static BitmapDescriptor getIcon(POICategory category) {
    return _cache[category] ?? BitmapDescriptor.defaultMarker;
  }

  /// Get the marker icon for favorites (yellow star).
  static BitmapDescriptor get favoriteIcon {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  static Future<BitmapDescriptor> _createMarkerIcon(
      POICategory category) async {
    const double size = 32; // Smaller markers
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Get category-specific color
    final color = _getCategoryColor(category);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
        const Offset(size / 2, size / 2 + 1), size / 2 - 3, shadowPaint);

    // Draw outer circle (white border)
    final outerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2 - 2, outerPaint);

    // Draw inner circle (category color)
    final innerPaint = Paint()..color = color;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2 - 5, innerPaint);

    // Draw Icon
    final iconData = _getCategoryIcon(category);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5, // 16px icon
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  static IconData _getCategoryIcon(POICategory category) {
    switch (category) {
      case POICategory.bikeShop:
        return Icons.pedal_bike;
      case POICategory.repairStation:
        return Icons.build;
      case POICategory.waterFountain:
        return Icons.water_drop;
      case POICategory.cafe:
        return Icons.local_cafe;
      case POICategory.restArea:
        return Icons.chair_alt;
    }
  }

  static Color _getCategoryColor(POICategory category) {
    switch (category) {
      case POICategory.bikeShop:
        return CruizrTheme.accentPink;
      case POICategory.repairStation:
        return Colors.blue.shade600;
      case POICategory.waterFountain:
        return Colors.green.shade600;
      case POICategory.cafe:
        return Colors.brown.shade500;
      case POICategory.restArea:
        return Colors.purple.shade400;
    }
  }
}
