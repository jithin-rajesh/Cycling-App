import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity_model.dart';


class ActivityDetailsScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailsScreen({super.key, required this.activity});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  // Custom map style
  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5ebe9"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#5d4037"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#fdf6f5"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#fdf6f5"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#e0d4d4"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#d7ccc8"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#e8f5e9"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  void _setupMapData() {
    // Add polyline
    if (widget.activity.polyline.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.activity.polyline,
          color: CruizrTheme.accentPink,
          width: 5,
        ),
      );

      // Add Start Marker
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: widget.activity.polyline.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );

      // Add End Marker
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: widget.activity.polyline.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.activity.polyline.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           _fitBounds();
        }
      });
    }
  }

  void _fitBounds() {
    if (widget.activity.polyline.isEmpty) return;

    double minLat = widget.activity.polyline.first.latitude;
    double maxLat = widget.activity.polyline.first.latitude;
    double minLng = widget.activity.polyline.first.longitude;
    double maxLng = widget.activity.polyline.first.longitude;

    for (var point in widget.activity.polyline) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('EEEE, MMMM d, y • h:mm a').format(widget.activity.startTime);

    // Calculate Avg Speed logic
    double speedKmH = 0.0;
    if (widget.activity.duration.inSeconds > 0) {
      speedKmH = widget.activity.distance / (widget.activity.duration.inSeconds / 3600);
    }

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400.0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
              onPressed: () => Navigator.of(context).pop(),
            ),
             flexibleSpace: FlexibleSpaceBar(
               background: widget.activity.polyline.isNotEmpty 
                 ? GoogleMap(
                     initialCameraPosition: CameraPosition(
                       target: widget.activity.polyline.first,
                       zoom: 14,
                     ),
                     polylines: _polylines,
                     markers: _markers,
                     onMapCreated: _onMapCreated,
                     style: _mapStyle,
                     zoomControlsEnabled: false,
                     mapToolbarEnabled: false,
                     myLocationButtonEnabled: false,
                   ) 
                 : Container(
                   color: Colors.grey[200],
                   child: const Center(
                     child: Text('No route data available'),
                   ),
                 ),
             ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.activity.type,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CruizrTheme.accentPink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: CruizrTheme.accentPink,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                     dateString,
                     style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                   const SizedBox(height: 32),

                  // Stats Grid
                  _buildStatsGrid(speedKmH),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(double speed) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatItem(Icons.straighten, 'Distance', '${widget.activity.distance.toStringAsFixed(2)} km')),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(child: _buildStatItem(Icons.timer, 'Duration', _formatDuration(widget.activity.duration))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
           Row(
            children: [
              Expanded(child: _buildStatItem(Icons.speed, 'Avg Speed', '${speed.toStringAsFixed(1)} km/h')),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(child: _buildStatItem(Icons.local_fire_department, 'Calories', '${widget.activity.calories.toInt()} cal')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: CruizrTheme.accentPink, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
