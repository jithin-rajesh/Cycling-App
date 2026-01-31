import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';

class PlacesTab extends StatefulWidget {
  const PlacesTab({super.key});

  @override
  State<PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends State<PlacesTab> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(12.9716, 77.5946); // Default: Bangalore
  final PlacesService _placesService = PlacesService();
  String _selectedType = 'bicycle_store'; // Default type
  bool _isLoading = false;

  final Map<String, String> _placeTypes = {
    'bicycle_store': 'Bike Shops',
    'cafe': 'Cafes',
    'park': 'Parks',
    'convenience_store': 'Stores',
    'physiotherapist': 'Recovery'
  };

  // Map Style (reusing from RoutesScreen for consistency)
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
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      final position = await Geolocator.getCurrentPosition();
      
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
      
      _fetchPlaces();
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchPlaces() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
    });

    final places = await _placesService.searchNearbyPlaces(_currentPosition, _selectedType);

    setState(() {
      _isLoading = false;
      for (var place in places) {
        final geometry = place['geometry']['location'];
        final lat = geometry['lat'];
        final lng = geometry['lng'];
        final name = place['name'];
        final vicinity = place['vicinity'];

        _markers.add(
          Marker(
            markerId: MarkerId(place['place_id']),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: name,
              snippet: vicinity,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_currentPosition != const LatLng(12.9716, 77.5946)) {
               _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
            }
          },
          style: _mapStyle,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          markers: _markers,
        ),
        
        // Filter Chips
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _placeTypes.entries.map((entry) {
                final isSelected = _selectedType == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          _selectedType = entry.key;
                        });
                        _fetchPlaces();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: CruizrTheme.accentPink,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // My Location Button
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            heroTag: 'places_loc',
            backgroundColor: CruizrTheme.surface,
            onPressed: _getUserLocation,
            child: _isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, color: Colors.black),
          ),
        ),
      ],
    );
  }
}
