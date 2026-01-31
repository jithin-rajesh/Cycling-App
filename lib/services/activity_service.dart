import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/activity_model.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> requestPermissions() async {
    if (kIsWeb)
      return true; // Permissions are handled by browser/Geolocator on web

    // Request activity recognition permission
    // For Android 10+ (API 29+), this is required for step counting/activity recognition
    final activityStatus = await Permission.activityRecognition.request();

    // Request location permission
    final locationStatus = await Permission.location.request();

    return activityStatus.isGranted && locationStatus.isGranted;
  }

  Future<void> saveActivity(ActivityModel activity) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Save the activity document
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .add(activity.toMap());

    // Update user's aggregate stats
    await _firestore.collection('users').doc(user.uid).update({
      'totalDistance': FieldValue.increment(activity.distance),
      'totalCalories': FieldValue.increment(activity.calories),
      'totalDuration': FieldValue.increment(activity.duration.inSeconds),
      // Ensure basic profile info is there if it wasn't already
      'lastActivity': FieldValue.serverTimestamp(),
    }).catchError((e) {
      // If doc doesn't exist (edge case), set it
      _firestore.collection('users').doc(user.uid).set({
        'totalDistance': activity.distance,
        'totalCalories': activity.calories,
        'totalDuration': activity.duration.inSeconds,
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Check for badges/tiers
    await _checkAndAwardBadges(user.uid, activity.distance);
  }

  Future<void> _checkAndAwardBadges(
      String uid, double currentActivityDistance) async {
    // Fetch total distance
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final totalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;

    String newTier = 'Relaxed';
    if (totalDistance >= 500) {
      newTier = 'Hypertraining';
    } else if (totalDistance >= 150) {
      newTier = 'Athletic';
    } else if (totalDistance >= 50) {
      newTier = 'Intermediate';
    }

    // Update tier if changed (or just always update for simplicity)
    await _firestore.collection('users').doc(uid).update({
      'badgeTier': newTier,
    });
  }

  // Get weekly stats
  Future<Map<String, dynamic>> getWeeklyStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'count': 0, 'time': Duration.zero, 'calories': 0.0};
    }

    final now = DateTime.now();
    // Start of the week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    int count = 0;
    Duration totalTime = Duration.zero;
    double totalCalories = 0.0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      count++;
      totalTime += Duration(seconds: data['duration'] as int);
      totalCalories += (data['calories'] as num).toDouble();
    }

    return {
      'count': count,
      'time': totalTime,
      'calories': totalCalories,
    };
  }

  // Get recent activities associated with the user
  Future<List<ActivityModel>> getRecentActivities({int limit = 3}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => ActivityModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get Leaderboard Data (Real Data)
  Future<List<Map<String, dynamic>>> getLeaderboard(String metric) async {
    // metric: 'distance' (default) or 'calories'
    final String orderByField =
        metric == 'calories' ? 'totalCalories' : 'totalDistance';

    final querySnapshot = await _firestore
        .collection('users')
        .orderBy(orderByField, descending: true)
        .limit(50) // Top 50
        .get();

    final currentUser = _auth.currentUser;

    return querySnapshot.docs.where((doc) {
      final data = doc.data();
      // Filter out private profiles
      if (data['profileVisibility'] == 'private') return false;
      return true;
    }).map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id, // Add UID for navigation
        'name': data['preferredName'] ?? data['displayName'] ?? 'Cruizr User',
        'distance': (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
        'calories': (data['totalCalories'] as num?)?.toDouble() ?? 0.0,
        'avatar': data['photoUrl'],
        'isMe': currentUser != null && doc.id == currentUser.uid,
      };
    }).toList();
  }
}
