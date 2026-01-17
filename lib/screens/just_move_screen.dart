import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../theme/app_theme.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';

class JustMoveScreen extends StatefulWidget {
  const JustMoveScreen({super.key});

  @override
  State<JustMoveScreen> createState() => _JustMoveScreenState();
}

class _JustMoveScreenState extends State<JustMoveScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  BitmapDescriptor? _locationMarkerIcon;
  
  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isMapExpanded = false; // For small screens
  
  // Stats
  double _distance = 0.0;
  Duration _duration = Duration.zero;
  double _elevationGain = 0.0;
  double? _lastAltitude;
  
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;

  // Default camera position
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946);

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

  Future<BitmapDescriptor> _createLocationMarkerIcon() async {
    const double circleSize = 40;
    const double tipHeight = 16;
    const double shadowOffset = 3;
    const double padding = 6; // Extra space for shadow
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
    
    // Draw shadow tip
    final shadowTipPath = Path();
    shadowTipPath.moveTo(centerX - 8 + shadowOffset, centerY + circleSize / 2 - 6 + shadowOffset);
    shadowTipPath.lineTo(centerX + 8 + shadowOffset, centerY + circleSize / 2 - 6 + shadowOffset);
    shadowTipPath.lineTo(centerX + shadowOffset, centerY + tipHeight + circleSize / 2 - 10 + shadowOffset);
    shadowTipPath.close();
    canvas.drawPath(shadowTipPath, shadowPaint);
    
    // Draw shadow circle
    canvas.drawCircle(Offset(centerX + shadowOffset, centerY + shadowOffset), circleSize / 2, shadowPaint);
    
    // Draw white tip (triangle pointing down)
    final tipPath = Path();
    tipPath.moveTo(centerX - 8, centerY + circleSize / 2 - 6);
    tipPath.lineTo(centerX + 8, centerY + circleSize / 2 - 6);
    tipPath.lineTo(centerX, centerY + tipHeight + circleSize / 2 - 10);
    tipPath.close();
    canvas.drawPath(tipPath, whitePaint);
    
    // Draw white outer circle (border)
    canvas.drawCircle(Offset(centerX, centerY), circleSize / 2, whitePaint);
    
    // Draw pink inner circle
    canvas.drawCircle(Offset(centerX, centerY), circleSize / 2 - borderWidth, pinkPaint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _updateLocationMarker() {
    if (_currentPosition != null && _locationMarkerIcon != null) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: _locationMarkerIcon!,
            anchor: const Offset(0.5, 1.0),
          ),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initLocationMarker();
  }

  Future<void> _initLocationMarker() async {
    _locationMarkerIcon = await _createLocationMarkerIcon();
    _getCurrentLocation();
  }

  Future<void> _checkPermissions() async {
    await ActivityService().requestPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    // _mapController?.dispose(); // Not needed and causes Web errors
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied. Allow in settings.')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });
      
      _updateLocationMarker();
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
    });
    
    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused) {
        setState(() {
          _duration += const Duration(seconds: 1);
        });
      }
    });
    
    // Start location tracking
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (_isTracking && !_isPaused) {
        setState(() {
          if (_routePoints.isNotEmpty) {
            // Calculate distance from last point
            final lastPoint = _routePoints.last;
            _distance += Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              position.latitude,
              position.longitude,
            ) / 1000; // Convert to km
          }
          
          // Calculate Elevation Gain
          if (_lastAltitude != null) {
            double altitudeDiff = position.altitude - _lastAltitude!;
            // Only count positive gain, ignore small noise (< 0.5m)
            if (altitudeDiff > 0.5) {
              _elevationGain += altitudeDiff;
            }
          }
          _lastAltitude = position.altitude;
          
          _routePoints.add(LatLng(position.latitude, position.longitude));
          // _speed = position.speed * 3.6; // Removed as unused
          _updatePolyline();
          _currentPosition = position;
        });
        
        _updateLocationMarker();
        
        // Keep camera centered on user
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    });
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTracking() {
    setState(() {
      _isPaused = false;
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    
    setState(() {
      _isTracking = false;
      _isPaused = false;
    });
    
    // Show summary dialog
    _showSummaryDialog();
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CruizrTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Activity Complete!',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Distance', '${_distance.toStringAsFixed(2)} km'),
            _buildSummaryRow('Duration', _formatDuration(_duration)),
            _buildSummaryRow('Elevation', '${_elevationGain.toStringAsFixed(0)} m'),
          ],
        ),
        actions: [
            TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              // Create Activity Model
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final activity = ActivityModel(
                  id: '', // Generated by Firestore
                  userId: user.uid,
                  type: 'Cycling', // Default for now, could be dynamic
                  startTime: DateTime.now().subtract(_duration),
                  endTime: DateTime.now(),
                  distance: _distance,
                  duration: _duration,
                  calories: _distance * 40, // Rough estimate
                  polyline: _routePoints,
                );
                
                await ActivityService().saveActivity(activity);
              }
              
              if (!mounted) return;
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back home
            },
            style: FilledButton.styleFrom(
              backgroundColor: CruizrTheme.accentPink,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: CruizrTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _updatePolyline() {
    _polylines.clear();
    if (_routePoints.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: CruizrTheme.accentPink,
          width: 5,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            ),
          );
        }
      });
    }
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
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                          : _defaultCenter,
                      zoom: 16,
                    ),
                    polylines: _polylines,
                    markers: _markers,
                    style: _mapStyle,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  // Zoom controls
                  Positioned(
                    top: _isMapExpanded ? 16 : null,
                    bottom: _isMapExpanded ? null : 16,
                    right: 16,
                    child: PointerInterceptor(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMapButton(Icons.add, () {
                            _mapController?.animateCamera(CameraUpdate.zoomIn());
                          }),
                          const SizedBox(height: 8),
                          _buildMapButton(Icons.remove, () {
                            _mapController?.animateCamera(CameraUpdate.zoomOut());
                          }),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMapButton(
                                _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen, 
                                () => setState(() => _isMapExpanded = !_isMapExpanded)
                              ),
                              const SizedBox(width: 12),
                              _buildMapButton(Icons.my_location, _getCurrentLocation),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isMapExpanded)
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      child: PointerInterceptor(
                        child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildExpandedStat('Distance', '${_distance.toStringAsFixed(2)} km'),
                            Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildExpandedStat('Duration', _formatDuration(_duration)),
                            Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildExpandedStat('Elev', '${_elevationGain.toStringAsFixed(0)} m'),
                          ],
                        ),
                      ),
                      ),
                    ),
                ],
              ),
            ),
            
            if (!_isMapExpanded) ...[
              // Stats Panel
              _buildStatsPanel(),
              
              // Controls
              _buildControls(),
              
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
            onPressed: () {
              if (_isTracking) {
                // Show confirmation
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Stop Activity?'),
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
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const Text(
            'Just Move',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
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
      padding: const EdgeInsets.all(24),
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
          _buildStat('Distance', '${_distance.toStringAsFixed(2)} km'),
          _buildStat('Duration', _formatDuration(_duration)),
          _buildStat('Elev', '${_elevationGain.toStringAsFixed(0)} m'),
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isTracking)
            // Start button
            _buildControlButton(
              icon: Icons.play_arrow,
              label: 'Start',
              onTap: _startTracking,
              isPrimary: true,
              size: 72,
            )
          else ...[
            // Pause/Resume button
            _buildControlButton(
              icon: _isPaused ? Icons.play_arrow : Icons.pause,
              label: _isPaused ? 'Resume' : 'Pause',
              onTap: _isPaused ? _resumeTracking : _pauseTracking,
              isPrimary: false,
              size: 56,
            ),
            const SizedBox(width: 24),
            // Stop button
            _buildControlButton(
              icon: Icons.stop,
              label: 'Stop',
              onTap: _stopTracking,
              isPrimary: true,
              size: 72,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    required double size,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isPrimary ? CruizrTheme.accentPink : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isPrimary
                      ? CruizrTheme.accentPink.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF5D4037),
              size: size * 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: CruizrTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  Widget _buildExpandedStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
