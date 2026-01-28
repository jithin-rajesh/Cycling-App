import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StravaService {
  static const String clientId = "196883";
  static const String clientSecret = "42ec1cd5571151e1f11f7f947b301256e076b763";

  // static const String redirectUrl = "http://localhost/strava-callback"; // REMOVED

  static const String _baseUrl = "https://www.strava.com/api/v3";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for storage
  static const String _keyAccessToken = "strava_access_token";
  static const String _keyRefreshToken = "strava_refresh_token";
  static const String _keyExpiresAt = "strava_expires_at";

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null;
  }

  Future<void> authenticate() async {
    String redirectUrl;

    // Logic:
    // - Linux (Web or Desktop): Use localhost (Legacy/Manual flow)
    // - Non-Linux Web (Windows, Mobile): Use dynamic origin (Auto-flow)
    // - Non-Linux Desktop/Mobile App: Use localhost (Default/Deep link placeholder)

    if (kIsWeb && defaultTargetPlatform != TargetPlatform.linux) {
      redirectUrl = Uri.base.origin;
    } else {
      redirectUrl = "http://localhost/strava-callback";
    }

    final Uri url = Uri.parse('https://www.strava.com/oauth/authorize'
        '?client_id=$clientId'
        '&response_type=code'
        '&redirect_uri=$redirectUrl'
        '&approval_prompt=force'
        '&scope=activity:write,activity:read_all,profile:read_all,read_all');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    } else {
      throw 'Could not launch $url';
    }
  }

  /// Exchanges the authorization code for an access token
  Future<bool> handleAuthCallback(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(data);
        return true;
      } else {
        debugPrint('Strava Auth Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Strava Auth Exception: $e');
      return false;
    }
  }

  /// Disconnects the user by clearing stored tokens
  Future<void> disconnect() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiresAt);
  }

  /// Uploads a ride (GPX format) to Strava
  Future<bool> uploadActivity(
      String gpxContent, String name, String description) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/uploads'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromString(
          'file',
          gpxContent,
          filename: 'ride.gpx',
        ),
      );

      request.fields['data_type'] = 'gpx';
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['activity_type'] = 'ride';

      var response = await request.send();
      return response.statusCode == 201; // 201 Created
    } catch (e) {
      debugPrint('Upload Error: $e');
      return false;
    }
  }

  /// Explores segments in the given bounding box
  /// Bounds format: "southwest_lat,southwest_lng,northeast_lat,northeast_lng"
  Future<List<Map<String, dynamic>>> exploreSegments(String bounds) async {
    final token = await _getValidAccessToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/segments/explore?bounds=$bounds&activity_type=riding'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['segments'] != null) {
          return List<Map<String, dynamic>>.from(data['segments']);
        }
      }
    } catch (e) {
      debugPrint('Explore Segments Error: $e');
    }
    return [];
  }

  /// Gets segments filtered by challenge type (Endurance vs Speed)
  Future<List<Map<String, dynamic>>> getChallengeSegments(
      String type, String bounds) async {
    final allSegments = await exploreSegments(bounds);

    if (allSegments.isEmpty) return [];

    return allSegments.where((segment) {
      final distance = (segment['distance'] ?? 0) as num; // meters
      final avgGrade = (segment['avg_grade'] ?? 0) as num; // percentage
      final elevDifference = (segment['elev_difference'] ?? 0) as num; // meters

      if (type == 'Endurance') {
        // endurance: longer distance OR significant elevation
        // Relaxed criteria for testing: > 5km or > 50m elev
        return distance > 5000 || elevDifference > 50;
      } else if (type == 'Speed') {
        // speed: flat and fast
        // < 1% grade AND < 50m elev difference
        return avgGrade.abs() < 1.5 && elevDifference < 100;
      }
      return true;
    }).toList();
  }

  /// Gets the details of a specific segment
  Future<Map<String, dynamic>?> getSegmentDetails(String segmentId) async {
    final token = await _getValidAccessToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/segments/$segmentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Get Segment Details Error: $e');
    }
    return null;
  }

  // --- Internal Helpers ---

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: _keyAccessToken, value: data['access_token']);
    await _storage.write(key: _keyRefreshToken, value: data['refresh_token']);
    await _storage.write(
        key: _keyExpiresAt, value: data['expires_at'].toString());
  }

  Future<String?> _getValidAccessToken() async {
    final expiresAtStr = await _storage.read(key: _keyExpiresAt);
    if (expiresAtStr == null) return null;

    final expiresAt = int.parse(expiresAtStr);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Refresh if expired or expiring in next 5 mins
    if (expiresAt < now + 300) {
      return await _refreshAccessToken();
    }

    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(data);
        return data['access_token'];
      }
    } catch (e) {
      debugPrint('Token Refresh Error: $e');
    }
    return null;
  }
}
