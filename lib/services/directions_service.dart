import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

/// Service to get actual road-following routes from Google Directions API.
/// 
/// Note: On web platforms, the Directions API HTTP calls are blocked by CORS.
/// The service returns null on web, and the app falls back to straight lines.
class DirectionsService {
  final String apiKey;

  DirectionsService({required this.apiKey});

  /// Fetches a route between waypoints using Google Directions API.
  /// 
  /// [waypoints] - List of LatLng points to route through
  /// [routeType] - 0 = Loop, 1 = One Way, 2 = Out & Back
  /// [travelMode] - 0 = Cycling, 1 = Walking, 2 = Driving
  /// 
  /// Returns a [DirectionsResult] containing polyline points and route info.
  Future<DirectionsResult?> getRoute({
    required List<LatLng> waypoints,
    required int routeType,
    int travelMode = 0,
  }) async {
    if (waypoints.length < 2) return null;
    
    // On web, CORS blocks direct API calls - return null to use fallback
    if (kIsWeb) {
      debugPrint('DirectionsService: Skipping API call on web (CORS)');
      return null;
    }

    try {
      // Build waypoints list based on route type
      List<LatLng> routePoints = List.from(waypoints);
      
      // For loop, add first point as destination
      if (routeType == 0 && waypoints.length > 1) {
        // The API will route from first to last, with destination being first point
      }

      final origin = routePoints.first;
      LatLng destination;
      List<LatLng>? intermediateWaypoints;

      if (routeType == 0) {
        // Loop: Route back to start
        destination = origin;
        if (routePoints.length > 2) {
          intermediateWaypoints = routePoints.sublist(1);
        } else if (routePoints.length == 2) {
          intermediateWaypoints = [routePoints[1]];
        }
      } else if (routeType == 2) {
        // Out & Back: Go to last point, then we'll reverse and append
        destination = routePoints.last;
        if (routePoints.length > 2) {
          intermediateWaypoints = routePoints.sublist(1, routePoints.length - 1);
        }
      } else {
        // One Way: Just go from first to last
        destination = routePoints.last;
        if (routePoints.length > 2) {
          intermediateWaypoints = routePoints.sublist(1, routePoints.length - 1);
        }
      }

      // Build the API URL
      final mode = _getTravelMode(travelMode);
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$mode'
          '&key=$apiKey';

      // Add intermediate waypoints if any
      if (intermediateWaypoints != null && intermediateWaypoints.isNotEmpty) {
        final waypointStr = intermediateWaypoints
            .map((p) => '${p.latitude},${p.longitude}')
            .join('|');
        url += '&waypoints=$waypointStr';
      }

      // Make the API request
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('Directions API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        debugPrint('Directions API status: ${data['status']}');
        return null;
      }

      // Extract the route
      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;

      final route = routes[0];
      final legs = route['legs'] as List;
      
      // Calculate total distance and duration
      double totalDistanceMeters = 0;
      int totalDurationSeconds = 0;
      
      for (final leg in legs) {
        totalDistanceMeters += leg['distance']['value'];
        totalDurationSeconds += leg['duration']['value'] as int;
      }

      // Decode the polyline
      final overviewPolyline = route['overview_polyline']['points'];
      final polylinePoints = PolylinePoints();
      final points = polylinePoints.decodePolyline(overviewPolyline);
      
      List<LatLng> polylineCoordinates = points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // For Out & Back, append the reverse route
      if (routeType == 2) {
        // Double the distance and duration for return trip
        totalDistanceMeters *= 2;
        totalDurationSeconds *= 2;
        
        // Add reversed polyline (excluding the endpoint to avoid duplication)
        final returnPoints = polylineCoordinates.reversed.skip(1).toList();
        polylineCoordinates.addAll(returnPoints);
      }

      return DirectionsResult(
        polylinePoints: polylineCoordinates,
        distanceMeters: totalDistanceMeters,
        durationSeconds: totalDurationSeconds,
      );
    } catch (e) {
      debugPrint('DirectionsService error: $e');
      return null;
    }
  }

  String _getTravelMode(int mode) {
    switch (mode) {
      case 0:
        return 'bicycling';
      case 1:
        return 'walking';
      case 2:
        return 'driving';
      default:
        return 'bicycling';
    }
  }
}

/// Result from a Directions API route query.
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final int durationSeconds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Duration in minutes
  int get durationMinutes => (durationSeconds / 60).round();
}
