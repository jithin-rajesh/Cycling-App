import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

/// Service to get elevation data from Google Elevation API.
/// 
/// On web platforms, API calls are routed through a Firebase Cloud Function
/// proxy to bypass CORS restrictions. On mobile/desktop, direct API calls
/// are used for better performance.
class ElevationService {
  final String apiKey;

  ElevationService({required this.apiKey});

  /// Fetches elevation data for a list of points along a route.
  /// 
  /// [routePoints] - List of LatLng points along the route
  /// [samples] - Number of samples to take along the route (default: 100)
  /// 
  /// Returns an [ElevationResult] containing elevation gain and profile data.
  Future<ElevationResult?> getElevation({
    required List<LatLng> routePoints,
    int samples = 100,
  }) async {
    if (routePoints.isEmpty) return null;

    // On web, use Firebase Cloud Function proxy to bypass CORS
    if (kIsWeb) {
      return _getElevationViaProxy(
        routePoints: routePoints,
        samples: samples,
      );
    }

    try {
      // For the Elevation API, we can either:
      // 1. Send specific locations (for small number of points)
      // 2. Use path sampling (for routes with many points)
      
      // If we have many points, sample the path
      if (routePoints.length > 50) {
        return _getElevationAlongPath(routePoints, samples);
      } else {
        return _getElevationForLocations(routePoints);
      }
    } catch (e) {
      debugPrint('ElevationService error: $e');
      return null;
    }
  }

  /// Get elevation for specific locations
  Future<ElevationResult?> _getElevationForLocations(List<LatLng> points) async {
    // Build the locations string (max ~512 points per request)
    final locationChunks = <List<LatLng>>[];
    for (var i = 0; i < points.length; i += 256) {
      locationChunks.add(
        points.sublist(i, i + 256 > points.length ? points.length : i + 256),
      );
    }

    List<double> allElevations = [];

    for (final chunk in locationChunks) {
      final locationsStr = chunk
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');

      final url = 'https://maps.googleapis.com/maps/api/elevation/json?'
          'locations=$locationsStr'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('Elevation API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        debugPrint('Elevation API status: ${data['status']}');
        return null;
      }

      final results = data['results'] as List;
      for (final result in results) {
        allElevations.add((result['elevation'] as num).toDouble());
      }
    }

    return _calculateElevationResult(allElevations);
  }

  /// Get elevation along a path (sampled)
  Future<ElevationResult?> _getElevationAlongPath(
    List<LatLng> points,
    int samples,
  ) async {
    // For path sampling, we need to encode the path or provide points
    // Using path parameter - encode as a series of coordinates
    final pathStr = points
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final url = 'https://maps.googleapis.com/maps/api/elevation/json?'
        'path=$pathStr'
        '&samples=$samples'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      debugPrint('Elevation API error: ${response.statusCode}');
      return null;
    }

    final data = json.decode(response.body);

    if (data['status'] != 'OK') {
      debugPrint('Elevation API status: ${data['status']}');
      return null;
    }

    final results = data['results'] as List;
    final elevations = results
        .map((r) => (r['elevation'] as num).toDouble())
        .toList();

    return _calculateElevationResult(elevations);
  }

  /// Calculate elevation gain and other stats from elevation data
  ElevationResult _calculateElevationResult(List<double> elevations) {
    if (elevations.isEmpty) {
      return ElevationResult(
        elevationGain: 0,
        elevationLoss: 0,
        maxElevation: 0,
        minElevation: 0,
        elevationProfile: [],
      );
    }

    double elevationGain = 0;
    double elevationLoss = 0;
    double maxElevation = elevations.first;
    double minElevation = elevations.first;

    for (int i = 1; i < elevations.length; i++) {
      final diff = elevations[i] - elevations[i - 1];
      if (diff > 0) {
        elevationGain += diff;
      } else {
        elevationLoss += diff.abs();
      }

      if (elevations[i] > maxElevation) {
        maxElevation = elevations[i];
      }
      if (elevations[i] < minElevation) {
        minElevation = elevations[i];
      }
    }

    return ElevationResult(
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      maxElevation: maxElevation,
      minElevation: minElevation,
      elevationProfile: elevations,
    );
  }

  /// Fetches elevation data via Firebase Cloud Function proxy (for web).
  Future<ElevationResult?> _getElevationViaProxy({
    required List<LatLng> routePoints,
    int samples = 100,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getElevation');

      // Convert points to list of strings
      final locations = routePoints
          .map((p) => '${p.latitude},${p.longitude}')
          .toList();

      final result = await callable.call<Map<String, dynamic>>({
        'locations': locations,
        'samples': samples,
      });

      final responseData = result.data;

      if (responseData['success'] != true) {
        final status = responseData['status'] ?? 'UNKNOWN';
        final error = responseData['error'] ?? 'Unknown error';
        debugPrint('Elevation proxy error: $status - $error');
        return null;
      }

      final data = responseData['data'];
      final results = data['results'] as List;
      final elevations = results
          .map((r) => (r['elevation'] as num).toDouble())
          .toList();

      return _calculateElevationResult(elevations);
    } catch (e) {
      debugPrint('ElevationService proxy error: $e');
      return null;
    }
  }
}

/// Result from an Elevation API query.
class ElevationResult {
  /// Total elevation gained (climbing) in meters
  final double elevationGain;
  
  /// Total elevation lost (descending) in meters
  final double elevationLoss;
  
  /// Maximum elevation along the route in meters
  final double maxElevation;
  
  /// Minimum elevation along the route in meters
  final double minElevation;
  
  /// Elevation profile as a list of elevations in meters
  final List<double> elevationProfile;

  ElevationResult({
    required this.elevationGain,
    required this.elevationLoss,
    required this.maxElevation,
    required this.minElevation,
    required this.elevationProfile,
  });

  /// Elevation gain in meters (rounded)
  int get elevationGainMeters => elevationGain.round();
}
