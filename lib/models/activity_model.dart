
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActivityModel {
  final String id;
  final String userId;
  final String type; // 'Cycling', 'Running', etc.
  final DateTime startTime;
  final DateTime endTime;
  final double distance; // in km
  final Duration duration;
  final double calories;
  final double elevationGain; // in meters
  final List<LatLng> polyline;
  final int? gymSets;
  final int? gymExercises;
  final String? gymMuscleGroup;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.duration,
    required this.calories,
    required this.elevationGain,
    required this.polyline,
    this.gymSets,
    this.gymExercises,
    this.gymMuscleGroup,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'distance': distance,
      'duration': duration.inSeconds, // Store as seconds
      'calories': calories,
      'elevationGain': elevationGain,
      'polyline': polyline.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'gymSets': gymSets,
      'gymExercises': gymExercises,
      'gymMuscleGroup': gymMuscleGroup,
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityModel(
      id: docId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'Unknown',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      distance: (map['distance'] as num).toDouble(),
      duration: Duration(seconds: map['duration'] as int),
      calories: (map['calories'] as num).toDouble(),
      elevationGain: (map['elevationGain'] as num?)?.toDouble() ?? 0.0,
      polyline: (map['polyline'] as List<dynamic>?)
              ?.map((p) => LatLng(p['lat'], p['lng']))
              .toList() ??
          [],
      gymSets: map['gymSets'] as int?,
      gymExercises: map['gymExercises'] as int?,
      gymMuscleGroup: map['gymMuscleGroup'] as String?,
    );
  }
}
