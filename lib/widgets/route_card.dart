import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/polyline_encoder.dart';

class RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final String routeId;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // Optional: Only show delete if provided

  const RouteCard({
    super.key,
    required this.route,
    required this.routeId,
    required this.onTap,
    this.onDelete,
  });

  String _generateStaticMapUrl(List<LatLng> points) {
    const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (apiKey.isEmpty || points.isEmpty) return '';

    final encodedPolyline = PolylineEncoder.encode(points);

    // Style matches the cream/pink theme
    // const style = '&style=feature:all|element:geometry|color:0xf5ebe9'
    //     '&style=feature:water|element:geometry|color:0xd7ccc8'
    //     '&style=feature:road|element:geometry|color:0xfdf6f5'
    //     '&style=feature:road|element:geometry.stroke|color:0xe0d4d4';

    const style = '&style=feature:poi|visibility:off';

    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'size=600x300'
        '&maptype=roadmap'
        '&path=weight:4%7Ccolor:0xFC4C02%7Cenc:$encodedPolyline'
        '$style'
        '&key=$apiKey';
  }

  @override
  Widget build(BuildContext context) {
    final name = route['name'] as String? ?? 'Unnamed Route';
    final distanceKm = (route['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final durationMinutes = (route['durationMinutes'] as num?)?.toInt() ?? 0;
    final elevation = (route['elevation'] as num?)?.toInt() ?? 0;
    final routeType = route['routeType'] as int? ?? 1;

    // Parse route points for preview
    final routePointsList = (route['routePoints'] as List?)?.map((p) {
          return LatLng(p['lat'] as double, p['lng'] as double);
        }).toList() ??
        [];

    final mapUrl = _generateStaticMapUrl(routePointsList);

    String routeTypeLabel;
    switch (routeType) {
      case 0:
        routeTypeLabel = 'Loop';
        break;
      case 2:
        routeTypeLabel = 'Out & Back';
        break;
      default:
        routeTypeLabel = 'One Way';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route preview
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: mapUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: mapUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color:
                                  CruizrTheme.accentPink.withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(
                                  Icons.map,
                                  color: CruizrTheme.accentPink
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color:
                                  CruizrTheme.accentPink.withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: CruizrTheme.accentPink
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color:
                                CruizrTheme.accentPink.withValues(alpha: 0.1),
                            child: Center(
                              child: Icon(
                                Icons.route,
                                size: 48,
                                color: CruizrTheme.accentPink
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      routeTypeLabel,
                      style: TextStyle(
                        color: CruizrTheme.accentPink,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),

            // Info Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStat(Icons.straighten,
                          '${distanceKm.toStringAsFixed(1)} km'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.terrain, '$elevation m'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.timer_outlined, '$durationMinutes min'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CruizrTheme.accentPink),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
