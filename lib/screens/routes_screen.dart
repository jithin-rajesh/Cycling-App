import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import '../services/strava_service.dart';
import '../services/poi_service.dart';
import '../models/poi_model.dart';
import '../theme/app_theme.dart';
import '../widgets/poi_filter_bar.dart';
import '../widgets/poi_detail_sheet.dart';
import '../utils/poi_marker_icons.dart';
import 'follow_route_screen.dart';
import '../widgets/route_card.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final List<String> _filters = ["My Routes", "All Routes", "Strava Segments"];
  int _selectedFilterIndex = 0;

  // Map State
  GoogleMapController? _mapController;
  final Set<Polyline> _segmentPolylines = {};
  final Set<Marker> _segmentMarkers = {};
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946); // Bangalore

  // POI state
  final POIService _poiService = POIService();
  final Set<POICategory> _activePOICategories = {};
  final Set<Marker> _poiMarkers = {};
  List<POI> _currentPOIs = [];
  bool _showFavorites = false;
  Timer? _poiFetchDebounce;
  LatLng? _lastPOIFetchCenter;
  bool _showSearchHereButton = false;

  // Custom map style (reuse from CreateRoute if possible, or simplified)
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
    _initPOIMarkers();
  }

  Future<void> _initPOIMarkers() async {
    await POIMarkerIcons.initialize();
  }

  @override
  void dispose() {
    _poiFetchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _selectedFilterIndex == 2
                  ? _buildSegmentsMap()
                  : _buildRoutesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesList() {
    final user = FirebaseAuth.instance.currentUser;

    // Build query - for "My Routes", filter by userId first, then order
    // For "All Routes", just order by createdAt
    Query<Map<String, dynamic>> query;

    if (_selectedFilterIndex == 0 && user != null) {
      // My Routes - filter first, then order
      query = FirebaseFirestore.instance
          .collection('routes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);
    } else {
      // All Routes - just order
      query = FirebaseFirestore.instance
          .collection('routes')
          .orderBy('createdAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final routes = snapshot.data?.docs ?? [];

        if (routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: CruizrTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No saved routes yet',
                  style: TextStyle(
                    color: CruizrTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a route to get started!',
                  style: TextStyle(
                    color: CruizrTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: routes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final routeData = routes[index].data();
            final routeId = routes[index].id;
            return RouteCard(
              route: routeData,
              routeId: routeId,
              onTap: () => _navigateToRoute(routeData),
              onDelete: () => _deleteRoute(routeId, routeData['name']),
            );
          },
        );
      },
    );
  }

  void _navigateToRoute(Map<String, dynamic> routeData) {
    // Convert stored data back to LatLng
    final routePointsList = (routeData['routePoints'] as List?)?.map((p) {
          return LatLng(p['lat'] as double, p['lng'] as double);
        }).toList() ??
        [];

    final waypointsList = (routeData['waypoints'] as List?)?.map((p) {
          return LatLng(p['lat'] as double, p['lng'] as double);
        }).toList() ??
        [];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowRouteScreen(
          routePoints: routePointsList,
          waypoints: waypointsList,
          distanceKm: (routeData['distanceKm'] as num?)?.toDouble() ?? 0.0,
          durationMinutes: (routeData['durationMinutes'] as num?)?.toInt() ?? 0,
        ),
      ),
    );
  }

  Future<void> _deleteRoute(String routeId, String? routeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text(
            'Are you sure you want to delete "${routeName ?? 'this route'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('routes')
          .doc(routeId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route deleted')),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Discover Routes',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: CruizrTheme.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // Buttons removed as requested
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return Center(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilterIndex = index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CruizrTheme.accentPink : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentsMap() {
    return Column(
      children: [
        // POI Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: POIFilterBar(
            activeCategories: _activePOICategories,
            onCategoryToggled: _togglePOICategory,
            showFavorites: true,
            onFavoritesToggled: _toggleFavorites,
            favoritesActive: _showFavorites,
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _getUserLocation();
                },
                onCameraIdle: _onCameraIdle,
                style: _mapStyle,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: {..._segmentMarkers, ..._poiMarkers},
                polylines: _segmentPolylines,
              ),
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'map_loc',
                  mini: true,
                  backgroundColor: CruizrTheme.surface,
                  onPressed: _getUserLocation,
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ),
              // Search here button for POIs
              if (_showSearchHereButton)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(
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
                            Icon(Icons.search, color: Colors.white, size: 18),
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
            ],
          ),
        ),
      ],
    );
  }

  void _onCameraIdle() {
    _fetchSegmentsInView();
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

    final bounds = await _mapController?.getVisibleRegion();
    if (bounds == null) return;

    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

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

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchSegmentsInView() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final southWest = bounds.southwest;
    final northEast = bounds.northeast;

    final boundsString =
        '${southWest.latitude},${southWest.longitude},${northEast.latitude},${northEast.longitude}';

    final segments = await StravaService().exploreSegments(boundsString);

    if (!mounted) return;

    setState(() {
      _segmentPolylines.clear();
      _segmentMarkers.clear();

      for (var segment in segments) {
        final id = segment['id'].toString();
        // final name = segment['name'];
        final polylineEncoded = segment['points'];
        if (polylineEncoded != null && polylineEncoded.isNotEmpty) {
          final points = PolylinePoints().decodePolyline(polylineEncoded);
          final latLngs =
              points.map((p) => LatLng(p.latitude, p.longitude)).toList();

          _segmentPolylines.add(
            Polyline(
              polylineId: PolylineId('poly_$id'),
              points: latLngs,
              color: const Color(0xFFFC4C02)
                  .withValues(alpha: 0.7), // Strava Orange
              width: 4,
              onTap: () {
                // Open details when tapping line too
                _showSegmentDetails(segment);
              },
              consumeTapEvents: true,
            ),
          );
        }

        // Markers for start points
        final startLat = segment['start_latlng'][0];
        final startLng = segment['start_latlng'][1];

        _segmentMarkers.add(
          Marker(
            markerId: MarkerId(id),
            position: LatLng(startLat, startLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            consumeTapEvents: true,
            onTap: () {
              _showSegmentDetails(segment);
            },
          ),
        );
      }
    });
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
            Row(
              children: [
                const Icon(Icons.directions_bike, color: Color(0xFFFC4C02)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segment['name'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.star_border, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSegmentStat('Distance',
                    '${(segment['distance'] / 1000).toStringAsFixed(1)} km'),
                _buildSegmentStat('Avg Grade', '${segment['avg_grade']}%'),
                _buildSegmentStat(
                    'Cat', '${segment['climb_category_desc'] ?? "-"}'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('View on Strava'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CruizrTheme.accentPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final polylineEncoded = segment['points'];
                  if (polylineEncoded != null && polylineEncoded.isNotEmpty) {
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
                          durationMinutes: 30,
                          elevationGain: (segment['elev_difference'] ?? 0)
                              .toDouble(), // Pass elevation
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Route path not available')),
                    );
                  }
                },
                child: const Text('Start Route'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentStat(String label, String value) {
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
}
