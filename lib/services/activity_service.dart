
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/activity_model.dart';


import 'package:flutter/foundation.dart' show kIsWeb;

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true; // Permissions are handled by browser/Geolocator on web

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

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .add(activity.toMap());
        
    // Update user's aggregate stats if needed (optional)
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
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
  // Get Leaderboard Data (Mock for now)
  Future<List<Map<String, dynamic>>> getLeaderboard(String metric) async {
    // metrics: 'distance' or 'calories'
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay

    // Extended mock data
    final List<Map<String, dynamic>> mockUsers = [
      {'name': 'Alex Rivera', 'distance': 156.5, 'calories': 4500.0, 'avatar': null},
      {'name': 'Sarah Chen', 'distance': 142.0, 'calories': 3800.0, 'avatar': null},
      {'name': 'Mike Ross', 'distance': 120.5, 'calories': 4100.0, 'avatar': null},
      {'name': 'Emma Wilson', 'distance': 98.2, 'calories': 2900.0, 'avatar': null},
      {'name': 'David Kim', 'distance': 85.0, 'calories': 2500.0, 'avatar': null},
      {'name': 'Lisa Park', 'distance': 72.5, 'calories': 2100.0, 'avatar': null},
      {'name': 'Tom Holland', 'distance': 60.0, 'calories': 3000.0, 'avatar': null},
      {'name': 'Adwai (You)', 'distance': 0.0, 'calories': 0.0, 'avatar': null, 'isMe': true}, 
    ];

    // Try to get real stats for "You"
    final realStats = await getWeeklyStats();
    final myIndex = mockUsers.indexWhere((u) => u['isMe'] == true);
    if (myIndex != -1) {
       mockUsers[myIndex]['distance'] = 25.5 + ((realStats['count'] as int) * 5); // Add dummy base
       // Use real stats if they exist, roughly converted or just use the mock logic + real addition
       // For a proper leaderboard, we'd normally just read the real aggregate.
       // Here we'll just overlay the real weekly stats if they are non-zero
       if ((realStats['calories'] as double) > 0) {
          mockUsers[myIndex]['calories'] = realStats['calories'];
       } else {
         mockUsers[myIndex]['calories'] = 1250.0; // Fallback mock
       }
       
       // Rough distance estimate from time if distance isn't tracked in getWeeklyStats (which it isn't currently, only time/cals)
       // We should ideally update getWeeklyStats to return distance too.
       // For now, let's just leave the mock base + some random factor
    }

    // Sort
    if (metric == 'distance') {
      mockUsers.sort((a, b) => (b['distance'] as double).compareTo(a['distance'] as double));
    } else {
      mockUsers.sort((a, b) => (b['calories'] as double).compareTo(a['calories'] as double));
    }

    return mockUsers;
  }
}
