
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/activity_model.dart';
import '../theme/app_theme.dart';

class ActivityShareOverlay extends StatelessWidget {
  final ActivityModel activity;
  final Uint8List? backgroundImageBytes;
  
  const ActivityShareOverlay({
    super.key,
    required this.activity,
    this.backgroundImageBytes,
  });


  @override
  Widget build(BuildContext context) {
    // Determine the background
    Widget background;
    if (backgroundImageBytes != null) {
      background = Image.memory(
        backgroundImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      background = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CruizrTheme.primaryDark,
              Colors.black87,
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 5, // Typical social media ratio
      child: Stack(
        children: [
          // 1. Background Image using RepaintBoundary to ensure it's captured correctly
          Positioned.fill(child: background),

          // 2. Translucent Overlay (Darken effect for readability)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // 3. Mini path/route (CustomPainter)
          if (activity.polyline.isNotEmpty)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: CustomPaint(
                  painter: RoutePainter(
                    coordinates: activity.polyline,
                    color: CruizrTheme.accentPink, // Brand color
                    strokeWidth: 4.0,
                  ),
                ),
              ),
            ),

          // 4. Foreground Content (Stats)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CRUIZR RIDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Stats in the center/bottom-center
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatRow('DISTANCE', '${activity.distance.toStringAsFixed(2)} km'),
                      const SizedBox(height: 24),
                      _buildStatRow('ELEV GAIN', '${activity.elevationGain.toInt()} m'),
                      const SizedBox(height: 24),
                      _buildStatRow('TIME', _formatDuration(activity.duration)),
                    ],
                  ),

                  // Footer / Logo
                  Column(
                    children: [
                      Text(
                        'CRUIZR',
                        style: TextStyle(
                          fontFamily: 'Playfair Display', // Using app font
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lato', // Assuming Lato is available as per previous conversations
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
}

class RoutePainter extends CustomPainter {
  final List<LatLng> coordinates;
  final Color color;
  final double strokeWidth;

  RoutePainter({
    required this.coordinates,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Calculate bounding box
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (var point in coordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // 2. Normalize and scale points to canvas size
    // We want to fit the route within the size, maintaining aspect ratio
    final double latSpan = maxLat - minLat;
    final double lngSpan = maxLng - minLng;
    
    if (latSpan == 0 && lngSpan == 0) return;

    // Add some padding (e.g. 10%)
    // But actual padding is handled by the widget wrapping CustomPaint, so we can just draw to fit size.
    
    // Scale factors
    // To fit in rectangle:
    // x = (lng - minLng) / lngSpan * width
    // y = (lat - minLat) / latSpan * height -> note: Y maps opposite in screen space (top is 0) but latitude grows upwards.
    // So y = height - ((lat - minLat) / latSpan * height)

    // Maintain aspect ratio
    // Identify scale based on the dimension that is the limiting factor
    double scaleX = size.width / lngSpan;
    double scaleY = size.height / latSpan;
    double scale = (scaleX < scaleY) ? scaleX : scaleY;

    // Center the drawing
    double contentWidth = lngSpan * scale;
    double contentHeight = latSpan * scale;
    double offsetX = (size.width - contentWidth) / 2;
    double offsetY = (size.height - contentHeight) / 2;

    final path = Path();
    
    // Start point
    final startX = (coordinates.first.longitude - minLng) * scale + offsetX;
    final startY = size.height - ((coordinates.first.latitude - minLat) * scale) - offsetY;
    
    path.moveTo(startX, startY);

    for (int i = 1; i < coordinates.length; i++) {
        final x = (coordinates[i].longitude - minLng) * scale + offsetX;
        final y = size.height - ((coordinates[i].latitude - minLat) * scale) - offsetY;
        path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.coordinates != coordinates || 
           oldDelegate.color != color || 
           oldDelegate.strokeWidth != strokeWidth;
  }
}
