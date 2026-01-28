import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../services/strava_service.dart';
import '../theme/app_theme.dart';
import 'follow_route_screen.dart';

class ChallengeRoutesScreen extends StatefulWidget {
  final String challengeType; // 'Endurance' or 'Speed'

  const ChallengeRoutesScreen({
    super.key,
    required this.challengeType,
  });

  @override
  State<ChallengeRoutesScreen> createState() => _ChallengeRoutesScreenState();
}

class _ChallengeRoutesScreenState extends State<ChallengeRoutesScreen> {
  final StravaService _stravaService = StravaService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _filteredSegments = [];
  GoogleMapController? _mapController;

  // Custom dark map style
  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#2c2c2c"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8a8a8a"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  Future<void> _loadSegments() async {
    setState(() => _isLoading = true);

    try {
      String bounds;

      if (_mapController != null) {
        final region = await _mapController!.getVisibleRegion();
        bounds =
            '${region.southwest.latitude},${region.southwest.longitude},${region.northeast.latitude},${region.northeast.longitude}';
      } else {
        Position position = await Geolocator.getCurrentPosition();
        final double lat = position.latitude;
        final double lng = position.longitude;
        bounds = '${lat - 0.1},${lng - 0.1},${lat + 0.1},${lng + 0.1}';
      }

      final segments = await _stravaService.getChallengeSegments(
          widget.challengeType, bounds);

      if (mounted) {
        setState(() {
          _filteredSegments = segments;
          _updateMapItems();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading segments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateMapItems() {
    _markers.clear();
    _polylines.clear();

    for (var segment in _filteredSegments) {
      final id = segment['id'].toString();
      final polylineEncoded = segment['points'];

      if (polylineEncoded != null && polylineEncoded.isNotEmpty) {
        final points = PolylinePoints().decodePolyline(polylineEncoded);
        final latLngs =
            points.map((p) => LatLng(p.latitude, p.longitude)).toList();

        // Color based on type
        final color = widget.challengeType == 'Endurance'
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFF5722);

        _polylines.add(
          Polyline(
            polylineId: PolylineId('poly_$id'),
            points: latLngs,
            color: color,
            width: 4,
            onTap: () => _showSegmentDetails(segment),
            consumeTapEvents: true,
          ),
        );
      }

      final startLat = segment['start_latlng'][0];
      final startLng = segment['start_latlng'][1];

      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(startLat, startLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.challengeType == 'Endurance'
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueOrange),
          onTap: () => _showSegmentDetails(segment),
        ),
      );
    }
  }

  void _showSegmentDetails(Map<String, dynamic> segment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              segment['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Distance',
                    '${(segment['distance'] / 1000).toStringAsFixed(1)} km'),
                _buildStat('Elev Gain', '${segment['elev_difference']} m'),
                _buildStat('Avg Grade', '${segment['avg_grade']}%'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.challengeType == 'Endurance'
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final polylineEncoded = segment['points'];
                  if (polylineEncoded != null) {
                    Navigator.pop(context);
                    final points =
                        PolylinePoints().decodePolyline(polylineEncoded);
                    final latLngs = points
                        .map((p) => LatLng(p.latitude, p.longitude))
                        .toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FollowRouteScreen(
                          routePoints: latLngs,
                          waypoints: [latLngs.first, latLngs.last],
                          distanceKm: (segment['distance'] ?? 0) / 1000.0,
                          durationMinutes: 45, // Estimation
                          elevationGain:
                              (segment['elev_difference'] ?? 0).toDouble(),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Start Challenge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(12.9716, 77.5946), // Default fallback
              zoom: 12,
            ),
            style: _mapStyle,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) async {
              _mapController = controller;
              try {
                final pos = await Geolocator.getCurrentPosition();
                controller.animateCamera(CameraUpdate.newLatLng(
                    LatLng(pos.latitude, pos.longitude)));
              } catch (_) {}
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      '${widget.challengeType} Routes',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (!_isLoading && _filteredSegments.isEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No ${widget.challengeType} routes found nearby.\nTry exploring a different area.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Refresh Button
          Positioned(
            top: 100, // Below header
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'refresh_btn',
              onPressed: _loadSegments,
              backgroundColor: Colors.white,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('Search Here',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
