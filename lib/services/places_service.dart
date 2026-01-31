import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacesService {
  final String _apiKey = 'AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ';

  Future<List<Map<String, dynamic>>> searchNearbyPlaces(LatLng location, String type) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=5000&type=$type&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      print('Places API Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
           return List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else {
           print('Places API Error: ${data['status']} - ${data['error_message']}');
        }
      } else {
        print('Failed to load places: ${response.body}');
      }
    } catch (e) {
      print('Error fetching places: $e');
    }
    return [];
  }
}
