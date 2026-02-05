import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Categories of Points of Interest relevant to cyclists
enum POICategory {
  bikeShop, // 🚲 Bike Shops
  repairStation, // 🔧 Repair/Service Stations (gas stations with air pumps)
  waterFountain, // 💧 Parks (as proxy for water/rest)
  cafe, // ☕ Cafes
  restArea, // 🪑 Rest Areas
}

extension POICategoryExtension on POICategory {
  String get displayName {
    switch (this) {
      case POICategory.bikeShop:
        return 'Bike Shops';
      case POICategory.repairStation:
        return 'Service Stations';
      case POICategory.waterFountain:
        return 'Parks';
      case POICategory.cafe:
        return 'Cafes';
      case POICategory.restArea:
        return 'Rest Areas';
    }
  }

  String get emoji {
    switch (this) {
      case POICategory.bikeShop:
        return '🚲';
      case POICategory.repairStation:
        return '🔧';
      case POICategory.waterFountain:
        return '🌳';
      case POICategory.cafe:
        return '☕';
      case POICategory.restArea:
        return '🪑';
    }
  }

  /// Google Places API type(s) for this category
  List<String> get placeTypes {
    switch (this) {
      case POICategory.bikeShop:
        return ['bicycle_store'];
      case POICategory.repairStation:
        return ['gas_station'];
      case POICategory.waterFountain:
        return ['park'];
      case POICategory.cafe:
        return ['cafe'];
      case POICategory.restArea:
        return ['rest_stop', 'tourist_attraction'];
    }
  }
}

/// A Point of Interest on the map
class POI {
  final String placeId;
  final String name;
  final LatLng location;
  final POICategory category;
  final String? address;
  final double? rating;
  final bool? isOpen;
  final String? photoReference;
  final int? userRatingsTotal;

  const POI({
    required this.placeId,
    required this.name,
    required this.location,
    required this.category,
    this.address,
    this.rating,
    this.isOpen,
    this.photoReference,
    this.userRatingsTotal,
  });

  /// Create POI from Google Places API response
  factory POI.fromPlacesApi(Map<String, dynamic> json, POICategory category) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List?;

    return POI(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      location: LatLng(
        (location?['lat'] as num?)?.toDouble() ?? 0.0,
        (location?['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      category: category,
      address: json['vicinity'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      isOpen: openingHours?['open_now'] as bool?,
      photoReference: photos != null && photos.isNotEmpty
          ? photos[0]['photo_reference'] as String?
          : null,
      userRatingsTotal: json['user_ratings_total'] as int?,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'lat': location.latitude,
      'lng': location.longitude,
      'category': category.index,
      'address': address,
      'rating': rating,
      'isOpen': isOpen,
      'photoReference': photoReference,
      'userRatingsTotal': userRatingsTotal,
    };
  }

  /// Create POI from local storage JSON
  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      category: POICategory.values[json['category'] as int],
      address: json['address'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      isOpen: json['isOpen'] as bool?,
      photoReference: json['photoReference'] as String?,
      userRatingsTotal: json['userRatingsTotal'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is POI &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;
}
