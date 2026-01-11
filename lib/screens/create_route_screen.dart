import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../services/directions_service.dart';

// API key is passed via --dart-define=GOOGLE_MAPS_API_KEY=...
const String _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  GoogleMapController? _mapController;
  final List<LatLng> _waypoints = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Route type: 0 = Loop, 1 = One Way, 2 = Out & Back
  int _routeType = 1; // Default to One Way
  // Routing preference: 0 = Cycling, 1 = Walking, 2 = Direct
  int _routingPreference = 0;
  // Auto-snap enabled (uses Directions API when true)
  bool _autoSnap = true;
  
  // Loading state for route fetching
  bool _isLoadingRoute = false;
  
  // Stats
  double _distance = 0.0;
  int _elevation = 0;
  int _duration = 0;
  
  // Directions service
  late DirectionsService _directionsService;

  // Default camera position (can be updated with user location)
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946); // Bangalore

  // Custom map style for cream/pink theme
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
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#f5ebe9"}]
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
    _directionsService = DirectionsService(apiKey: _mapsApiKey);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_mapStyle);
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _waypoints.add(position);
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_${_waypoints.length}'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      );
    });
    _updateRoute();
  }

  Future<void> _updateRoute() async {
    if (_waypoints.length < 2) {
      setState(() {
        _polylines.clear();
        _distance = 0;
        _duration = 0;
      });
      return;
    }

    // If autoSnap is disabled OR routing preference is Direct, use straight lines
    if (!_autoSnap || _routingPreference == 2) {
      _updateStraightLinePolyline();
      _calculateSimpleStats();
      return;
    }

    // Use Directions API for real routes
    setState(() {
      _isLoadingRoute = true;
    });

    final result = await _directionsService.getRoute(
      waypoints: _waypoints,
      routeType: _routeType,
      travelMode: _routingPreference,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polylinePoints,
            color: CruizrTheme.accentPink,
            width: 4,
          ),
        );
        _distance = result.distanceKm;
        _duration = result.durationMinutes;
        _isLoadingRoute = false;
      });
    } else {
      // Fallback to straight lines if API fails
      _updateStraightLinePolyline();
      _calculateSimpleStats();
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _updateStraightLinePolyline() {
    if (_waypoints.length < 2) {
      _polylines.clear();
      return;
    }
    
    List<LatLng> points = List.from(_waypoints);
    
    // If loop, connect back to start
    if (_routeType == 0 && _waypoints.length > 1) {
      points.add(_waypoints.first);
    }
    // If out & back, add reverse path
    else if (_routeType == 2 && _waypoints.length > 1) {
      points.addAll(_waypoints.reversed.skip(1));
    }
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: CruizrTheme.accentPink,
          width: 4,
        ),
      );
    });
  }

  void _calculateSimpleStats() {
    // Simple distance calculation (haversine would be more accurate)
    double totalDistance = 0;
    for (int i = 1; i < _waypoints.length; i++) {
      totalDistance += _calculateDistance(_waypoints[i - 1], _waypoints[i]);
    }
    
    // Adjust for route type
    if (_routeType == 0 && _waypoints.length > 1) {
      totalDistance += _calculateDistance(_waypoints.last, _waypoints.first);
    } else if (_routeType == 2) {
      totalDistance *= 2;
    }
    
    setState(() {
      _distance = totalDistance;
      // Rough estimate: 3 min per km for cycling
      _duration = (_distance * 3).round();
    });
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    // Simplified distance in km (rough approximation)
    const double kmPerDegree = 111.0;
    double dx = (p2.longitude - p1.longitude) * kmPerDegree;
    double dy = (p2.latitude - p1.latitude) * kmPerDegree;
    return (dx * dx + dy * dy).abs().sqrt() * 0.8; // More realistic multiplier
  }

  void _undo() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.removeLast();
        _markers.removeWhere((m) => m.markerId.value == 'waypoint_${_waypoints.length + 1}');
      });
      _updateRoute();
    }
  }

  void _clear() {
    setState(() {
      _waypoints.clear();
      _markers.clear();
      _polylines.clear();
      _distance = 0;
      _elevation = 0;
      _duration = 0;
    });
  }

  void _saveRoute() {
    if (_waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add waypoints to create a route')),
      );
      return;
    }
    // TODO: Save route to Firebase
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Map
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: _onMapCreated,
                    onTap: _onMapTap,
                    initialCameraPosition: const CameraPosition(
                      target: _defaultCenter,
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  // Loading indicator
                  if (_isLoadingRoute)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Calculating route...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Zoom controls
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        _buildMapButton(Icons.add, () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        }),
                        const SizedBox(height: 8),
                        _buildMapButton(Icons.remove, () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        }),
                        const SizedBox(height: 8),
                        _buildMapButton(Icons.my_location, () {
                          // Could get user location and move camera
                        }),
                      ],
                    ),
                  ),
                  // Hint text when no waypoints
                  if (_waypoints.isEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tap to add waypoints',
                          style: TextStyle(
                            color: CruizrTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Stats Panel
            _buildStatsPanel(),
            
            // Route Type
            _buildRouteTypeSelector(),
            
            // Routing Preference
            _buildRoutingPreference(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF5D4037),
                fontSize: 16,
              ),
            ),
          ),
          const Text(
            'Create',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          Row(
            children: [
              const Text(
                'Route',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _saveRoute,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: CruizrTheme.accentPink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF5D4037), size: 20),
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Distance', '${_distance.toStringAsFixed(1)} km'),
              _buildStat('Elevation', '$_elevation m'),
              _buildStat('Duration', '$_duration min'),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(child: _buildActionButton(Icons.undo, 'Undo', _undo, false)),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton(Icons.delete_outline, 'Clear', _clear, false)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  Icons.auto_fix_high,
                  'Auto-\nsnap',
                  () {
                    setState(() => _autoSnap = !_autoSnap);
                    _updateRoute();
                  },
                  _autoSnap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: CruizrTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, bool isActive) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? CruizrTheme.accentPink : const Color(0xFFF5EBE9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF5D4037),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF5D4037),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTypeChip(0, Icons.loop, 'Loop')),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeChip(1, Icons.arrow_forward, 'One Way')),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeChip(2, Icons.swap_horiz, 'Out & Back')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(int index, IconData icon, String label) {
    final isSelected = _routeType == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _routeType = index;
        });
        _updateRoute();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: CruizrTheme.accentPink, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? CruizrTheme.accentPink : CruizrTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? CruizrTheme.accentPink : CruizrTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingPreference() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Routing Preference',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPreferenceChip(0, '🚴', 'Cycling')),
              const SizedBox(width: 12),
              Expanded(child: _buildPreferenceChip(1, '🚶', 'Walking')),
              const SizedBox(width: 12),
              Expanded(child: _buildPreferenceChip(2, '📍', 'Direct')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceChip(int index, String emoji, String label) {
    final isSelected = _routingPreference == index;
    return GestureDetector(
      onTap: () {
        setState(() => _routingPreference = index);
        _updateRoute();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: CruizrTheme.accentPink, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? CruizrTheme.accentPink : CruizrTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to add sqrt to double
extension on double {
  double sqrt() => this >= 0 ? math.sqrt(this) : 0;
}
