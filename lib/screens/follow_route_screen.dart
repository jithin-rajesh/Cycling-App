import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../theme/app_theme.dart';
import '../models/poi_model.dart';
import '../services/poi_service.dart';
import '../widgets/poi_filter_bar.dart';
import '../widgets/poi_detail_sheet.dart';
import '../utils/poi_marker_icons.dart';

/// Screen for following a pre-defined route with live tracking.
class FollowRouteScreen extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<LatLng> waypoints;
  final double distanceKm;
  final int durationMinutes;
  final double elevationGain; // Added

  const FollowRouteScreen({
    super.key,
    required this.routePoints,
    required this.waypoints,
    required this.distanceKm,
    required this.durationMinutes,
    this.elevationGain = 0.0,
  });

  @override
  State<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends State<FollowRouteScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  BitmapDescriptor? _locationMarkerIcon;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  final List<LatLng> _traveledPath = [];

  // Stats
  double _distanceTraveled = 0.0;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;

  // Markers and polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // POI state
  final POIService _poiService = POIService();
  final Set<POICategory> _activePOICategories = {};
  final Set<Marker> _poiMarkers = {};
  List<POI> _currentPOIs = [];
  bool _showFavorites = false;
  Timer? _poiFetchDebounce;
  LatLng? _lastPOIFetchCenter;
  bool _showSearchHereButton = false;

  // Custom map style
  static const String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f5ebe9"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#5d4037"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#fdf6f5"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#fdf6f5"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#e0d4d4"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#f5ebe9"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#d7ccc8"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#e8f5e9"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _initLocationMarker();
    _setupRouteDisplay();
    _initPOIMarkers();
  }

  Future<void> _initPOIMarkers() async {
    await POIMarkerIcons.initialize();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
    _poiFetchDebounce?.cancel();
    super.dispose();
  }

  void _setupRouteDisplay() {
    // Add the route polyline
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('planned_route'),
        points: widget.routePoints,
        color: CruizrTheme.accentPink.withValues(alpha: 0.5),
        width: 6,
      ),
    );

    // Add waypoint markers
    for (int i = 0; i < widget.waypoints.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: widget.waypoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      );
    }
  }

  Future<void> _initLocationMarker() async {
    _locationMarkerIcon = await _createLocationMarkerIcon();
    _getCurrentLocation();
  }

  Future<BitmapDescriptor> _createLocationMarkerIcon() async {
    const double circleSize = 40;
    const double tipHeight = 16;
    const double shadowOffset = 3;
    const double padding = 6;
    const double totalHeight = circleSize + tipHeight + padding;
    const double totalWidth = circleSize + padding;
    const double borderWidth = 4;
    const double centerX = totalWidth / 2;
    const double centerY = circleSize / 2 + 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pinkPaint = Paint()
      ..color = CruizrTheme.accentPink
      ..style = PaintingStyle.fill;

    // Draw shadow
    final shadowTipPath = Path();
    shadowTipPath.moveTo(centerX - 8 + shadowOffset,
        centerY + circleSize / 2 - 6 + shadowOffset);
    shadowTipPath.lineTo(centerX + 8 + shadowOffset,
        centerY + circleSize / 2 - 6 + shadowOffset);
    shadowTipPath.lineTo(centerX + shadowOffset,
        centerY + tipHeight + circleSize / 2 - 10 + shadowOffset);
    shadowTipPath.close();
    canvas.drawPath(shadowTipPath, shadowPaint);
    canvas.drawCircle(Offset(centerX + shadowOffset, centerY + shadowOffset),
        circleSize / 2, shadowPaint);

    // Draw marker
    final tipPath = Path();
    tipPath.moveTo(centerX - 8, centerY + circleSize / 2 - 6);
    tipPath.lineTo(centerX + 8, centerY + circleSize / 2 - 6);
    tipPath.lineTo(centerX, centerY + tipHeight + circleSize / 2 - 10);
    tipPath.close();
    canvas.drawPath(tipPath, whitePaint);
    canvas.drawCircle(Offset(centerX, centerY), circleSize / 2, whitePaint);
    canvas.drawCircle(
        Offset(centerX, centerY), circleSize / 2 - borderWidth, pinkPaint);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });

    _updateLocationMarker();

    // Center on route start
    if (widget.routePoints.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getBoundsForRoute(),
          50,
        ),
      );
    }
  }

  LatLngBounds _getBoundsForRoute() {
    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLng = widget.routePoints.first.longitude;
    double maxLng = widget.routePoints.first.longitude;

    for (final point in widget.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateLocationMarker() {
    if (_currentPosition != null && _locationMarkerIcon != null) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: _locationMarkerIcon!,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: 999,
          ),
        );
      });
    }
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedTime += const Duration(seconds: 1);
        });
      }
    });

    // Start location tracking
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (_isPaused) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      // Calculate distance from last point
      if (_traveledPath.isNotEmpty) {
        final lastPoint = _traveledPath.last;
        final distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        _distanceTraveled += distance / 1000; // Convert to km
      }

      setState(() {
        _currentPosition = position;
        _traveledPath.add(newPoint);
      });

      _updateLocationMarker();
      _updateTraveledPolyline();

      // Center on current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPoint),
      );
    });
  }

  void _pauseTracking() {
    setState(() => _isPaused = true);
  }

  void _resumeTracking() {
    setState(() => _isPaused = false);
  }

  void _stopTracking() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _showSummaryDialog();
  }

  void _updateTraveledPolyline() {
    setState(() {
      _polylines.removeWhere((p) => p.polylineId.value == 'traveled');
      if (_traveledPath.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('traveled'),
            points: _traveledPath,
            color: CruizrTheme.accentPink,
            width: 5,
          ),
        );
      }
    });
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Route Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(
                'Distance', '${_distanceTraveled.toStringAsFixed(2)} km'),
            _buildSummaryRow('Time', _formatDuration(_elapsedTime)),
            _buildSummaryRow(
                'Planned', '${widget.distanceKm.toStringAsFixed(1)} km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child:
                Text('Done', style: TextStyle(color: CruizrTheme.accentPink)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: CruizrTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}';
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Style is now handled by GoogleMap widget style parameter
  }

  void _onCameraIdle() {
    if (_activePOICategories.isNotEmpty || _showFavorites) {
      setState(() {
        _showSearchHereButton = true;
      });
    }
  }

  Future<void> _fetchPOIs({bool force = false}) async {
    setState(() {
      _showSearchHereButton = false;
    });

    if (_activePOICategories.isEmpty && !_showFavorites) {
      setState(() {
        _poiMarkers.clear();
        _currentPOIs.clear();
      });
      return;
    }

    // Use current position or route center as center
    final center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : widget.routePoints.isNotEmpty
            ? widget.routePoints.first
            : const LatLng(12.9716, 77.5946);

    // Skip if center hasn't changed significantly
    if (!force && _lastPOIFetchCenter != null) {
      final distance = Geolocator.distanceBetween(
        _lastPOIFetchCenter!.latitude,
        _lastPOIFetchCenter!.longitude,
        center.latitude,
        center.longitude,
      );
      if (distance < 500) return;
    }
    _lastPOIFetchCenter = center;

    // Show loading snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Loading nearby places...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    final pois = await _poiService.searchNearbyPOIs(
      center: center,
      categories: _activePOICategories,
    );

    List<POI> allPOIs = List.from(pois);
    if (_showFavorites) {
      final favorites = await _poiService.getFavorites();
      allPOIs.addAll(favorites);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _currentPOIs = allPOIs;
      _poiMarkers.clear();
      for (final poi in allPOIs) {
        _poiMarkers.add(
          Marker(
            markerId: MarkerId('poi_${poi.placeId}'),
            position: poi.location,
            icon: POIMarkerIcons.getIcon(poi.category),
            onTap: () => _showPOIDetails(poi),
          ),
        );
      }
    });
  }

  void _showPOIDetails(POI poi) {
    POIDetailSheet.show(
      context,
      poi: poi,
      onFavoriteChanged: () => _fetchPOIs(force: true),
    );
  }

  void _togglePOICategory(POICategory category) {
    setState(() {
      if (_activePOICategories.contains(category)) {
        _activePOICategories.remove(category);
      } else {
        _activePOICategories.add(category);
      }
      _showSearchHereButton = true;
      _updateVisibleMarkers();
    });
  }

  void _toggleFavorites() {
    setState(() {
      _showFavorites = !_showFavorites;
      if (_showFavorites) {
        _showSearchHereButton = true;
      }
    });
    _fetchPOIs(force: true);
  }

  void _updateVisibleMarkers() {
    _poiMarkers.clear();
    for (final poi in _currentPOIs) {
      if (_activePOICategories.contains(poi.category)) {
        _poiMarkers.add(
          Marker(
            markerId: MarkerId('poi_${poi.placeId}'),
            position: poi.location,
            icon: POIMarkerIcons.getIcon(poi.category),
            onTap: () => _showPOIDetails(poi),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            // POI Filter Bar (hidden when tracking active)
            if (!_isTracking)
              POIFilterBar(
                activeCategories: _activePOICategories,
                onCategoryToggled: _togglePOICategory,
                showFavorites: true,
                onFavoritesToggled: _toggleFavorites,
                favoritesActive: _showFavorites,
              ),

            if (!_isTracking) const SizedBox(height: 8),

            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: _onMapCreated,
                    onCameraIdle: _onCameraIdle,
                    initialCameraPosition: CameraPosition(
                      target: widget.routePoints.isNotEmpty
                          ? widget.routePoints.first
                          : const LatLng(12.9716, 77.5946),
                      zoom: 14,
                    ),
                    style: _mapStyle,
                    markers: {..._markers, ..._poiMarkers},
                    polylines: _polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  // Search here button for POIs
                  if (_showSearchHereButton)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: PointerInterceptor(
                          child: GestureDetector(
                            onTap: _fetchPOIs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: CruizrTheme.accentPink,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text('Search this area',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Zoom controls - wrapped with PointerInterceptor
                  Positioned(
                    top: 16,
                    right: 16,
                    child: PointerInterceptor(
                      child: Column(
                        children: [
                          _buildMapButton(Icons.add, () {
                            _mapController
                                ?.animateCamera(CameraUpdate.zoomIn());
                          }),
                          const SizedBox(height: 8),
                          _buildMapButton(Icons.remove, () {
                            _mapController
                                ?.animateCamera(CameraUpdate.zoomOut());
                          }),
                          const SizedBox(height: 8),
                          _buildMapButton(
                              Icons.my_location, _getCurrentLocation),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildStatsPanel(),
            _buildControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isTracking) {
                _showExitConfirmation();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
          ),
          const Expanded(
            child: Text(
              'Follow Route',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Tracking?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child:
                Text('Stop', style: TextStyle(color: CruizrTheme.accentPink)),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    // Simple GestureDetector - PointerInterceptor handles the tap blocking
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Distance', '${_distanceTraveled.toStringAsFixed(2)} km'),
          _buildStat(
              'Elevation', '${widget.elevationGain.toStringAsFixed(0)} m'),
          _buildStat('Remaining',
              '${(widget.distanceKm - _distanceTraveled).clamp(0, double.infinity).toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: CruizrTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isTracking)
            _buildControlButton(
              icon: Icons.play_arrow,
              label: 'Start',
              onTap: _startTracking,
              isPrimary: true,
            )
          else if (_isPaused)
            Row(
              children: [
                _buildControlButton(
                  icon: Icons.play_arrow,
                  label: 'Resume',
                  onTap: _resumeTracking,
                  isPrimary: true,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.stop,
                  label: 'Finish',
                  onTap: _stopTracking,
                  isPrimary: false,
                ),
              ],
            )
          else
            Row(
              children: [
                _buildControlButton(
                  icon: Icons.pause,
                  label: 'Pause',
                  onTap: _pauseTracking,
                  isPrimary: false,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.stop,
                  label: 'Finish',
                  onTap: _stopTracking,
                  isPrimary: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? CruizrTheme.accentPink : const Color(0xFFF5EBE9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF5D4037),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF5D4037),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
