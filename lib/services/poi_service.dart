import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/poi_model.dart';
import '../config/secrets.dart';

/// Service for fetching Points of Interest from Google Places API
/// and managing user favorites in local storage.
class POIService {
  static const String _favoritesKey = 'poi_favorites';
  static const int _defaultRadius = 5000; // 5km radius

  /// Searches for nearby POIs of specified categories.
  ///
  /// [center] - The center point to search around
  /// [categories] - List of POI categories to search for
  /// [radius] - Search radius in meters (default 5000m)
  ///
  /// Returns a list of POIs grouped by category.
  Future<List<POI>> searchNearbyPOIs({
    required LatLng center,
    required Set<POICategory> categories,
    int radius = _defaultRadius,
  }) async {
    if (categories.isEmpty) return [];

    final List<POI> allPOIs = [];

    // Fetch POIs for each category in parallel
    final futures = categories.map((category) {
      return _searchCategory(center, category, radius);
    });

    final results = await Future.wait(futures);
    for (final pois in results) {
      allPOIs.addAll(pois);
    }

    return allPOIs;
  }

  /// Search for POIs of a specific category
  Future<List<POI>> _searchCategory(
    LatLng center,
    POICategory category,
    int radius,
  ) async {
    // On web, use Firebase Cloud Function proxy to bypass CORS
    if (kIsWeb) {
      return _searchViaProxy(center, category, radius);
    }
    return _searchDirect(center, category, radius);
  }

  /// Direct API call (for mobile/desktop)
  Future<List<POI>> _searchDirect(
    LatLng center,
    POICategory category,
    int radius,
  ) async {
    try {
      final types = category.placeTypes.join('|');
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${center.latitude},${center.longitude}'
          '&radius=$radius'
          '&type=$types'
          '&key=$googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('Places API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        debugPrint('Places API status: ${data['status']}');
        return [];
      }

      final results = data['results'] as List? ?? [];
      return results
          .map((place) =>
              POI.fromPlacesApi(place as Map<String, dynamic>, category))
          .toList();
    } catch (e) {
      debugPrint('POIService error: $e');
      return [];
    }
  }

  /// Search via Firebase Cloud Function (for web - bypasses CORS)
  Future<List<POI>> _searchViaProxy(
    LatLng center,
    POICategory category,
    int radius,
  ) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getNearbyPlaces');

      final result = await callable.call<Map<String, dynamic>>({
        'location': '${center.latitude},${center.longitude}',
        'radius': radius,
        'type': category.placeTypes.first,
      });

      final responseData = result.data;

      if (responseData['success'] != true) {
        debugPrint('Places proxy error: ${responseData['error']}');
        return [];
      }

      final results = responseData['results'] as List? ?? [];
      return results
          .map((place) =>
              POI.fromPlacesApi(place as Map<String, dynamic>, category))
          .toList();
    } catch (e) {
      debugPrint('POIService proxy error: $e');
      return [];
    }
  }

  /// Get photo URL for a POI
  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://maps.googleapis.com/maps/api/place/photo?'
        'maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=$googleMapsApiKey';
  }

  // ===== Local Favorites Management =====

  /// Get all favorite POIs from local storage
  Future<List<POI>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];

      return favoritesJson
          .map((jsonStr) =>
              POI.fromJson(json.decode(jsonStr) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      return [];
    }
  }

  /// Save a POI to favorites
  Future<bool> saveFavorite(POI poi) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];

      // Check if already exists
      final exists = favoritesJson.any((jsonStr) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        return decoded['placeId'] == poi.placeId;
      });

      if (!exists) {
        favoritesJson.add(json.encode(poi.toJson()));
        await prefs.setStringList(_favoritesKey, favoritesJson);
      }

      return true;
    } catch (e) {
      debugPrint('Error saving favorite: $e');
      return false;
    }
  }

  /// Remove a POI from favorites
  Future<bool> removeFavorite(String placeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];

      favoritesJson.removeWhere((jsonStr) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        return decoded['placeId'] == placeId;
      });

      await prefs.setStringList(_favoritesKey, favoritesJson);
      return true;
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return false;
    }
  }

  /// Check if a POI is in favorites
  Future<bool> isFavorite(String placeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];

      return favoritesJson.any((jsonStr) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        return decoded['placeId'] == placeId;
      });
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }
}
