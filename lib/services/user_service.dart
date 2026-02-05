import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // Follow a user
  Future<void> followUser(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');
    if (currentUser.uid == targetUid) throw Exception('Cannot follow yourself');

    final batch = _firestore.batch();

    // Add target to current user's "following" subcollection or array
    // Using subcollections is more scalable if lists get large, but arrays are cheaper/easier for small apps.
    // Let's use arrays of strings for simplicity as per common use cases unless specified otherwise,
    // but subcollections are safer for 1M limits. Given "community panel", let's stick to subcollections for potential scale
    // OR just use arrays for MVP. arrays are easier to count. Let's start with arrays for IDs.

    // Actually, let's use a subcollection 'following' and 'followers' for each user to be safe and scalable.
    // And store a counter on the main doc.

    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);

    // 1. Add target to my following
    batch.set(currentUserRef.collection('following').doc(targetUid), {
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Add me to target's followers
    batch.set(targetUserRef.collection('followers').doc(currentUser.uid), {
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. Update counts
    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final batch = _firestore.batch();

    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);

    // 1. Remove target from my following
    batch.delete(currentUserRef.collection('following').doc(targetUid));

    // 2. Remove me from target's followers
    batch.delete(targetUserRef.collection('followers').doc(currentUser.uid));

    // 3. Update counts
    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Check if following
  Future<bool> isFollowing(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUid)
        .get();

    return doc.exists;
  }

  // Get follow counts (if not on main doc, this is backup, but we increment on main doc)
  Future<Map<String, int>> getFollowCounts(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      return {
        'followers': data['followersCount'] ?? 0,
        'following': data['followingCount'] ?? 0,
      };
    }
    return {'followers': 0, 'following': 0};
  }

  // Get routes created by user
  Future<List<Map<String, dynamic>>> getUserRoutes(String uid) async {
    try {
      // Check privacy first
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final currentUser = _auth.currentUser;
        final isMe = currentUser != null && currentUser.uid == uid;

        if (userData?['profileVisibility'] == 'private' && !isMe) {
          return [];
        }
      }

      final query = await _firestore
          .collection('routes')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include ID
        return data;
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching user routes: $e');
      return [];
    }
  }

  // Save a new goal
  Future<void> saveGoal({
    required String target,
    required String metric,
    required int durationAmount,
    required String durationUnit, // 'Day', 'Week', 'Month'
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Calculate end date based on duration
    DateTime now = DateTime.now();
    DateTime endDate = now;
    if (durationUnit == 'Day') {
      endDate = now.add(Duration(days: durationAmount));
    } else if (durationUnit == 'Week') {
      endDate = now.add(Duration(days: durationAmount * 7));
    } else if (durationUnit == 'Month') {
      endDate = now.add(Duration(days: durationAmount * 30));
    }

    // Pluralize label if amount > 1
    String unitLabel = durationUnit;
    if (durationAmount > 1) {
      unitLabel = '${durationUnit}s';
    }

    await _firestore.collection('users').doc(user.uid).collection('goals').add({
      'target': target,
      'metric': metric,
      'durationAmount': durationAmount,
      'durationUnit': durationUnit,
      'durationLabel': '$durationAmount $unitLabel',
      'startDate': FieldValue.serverTimestamp(),
      'endDate': endDate,
      'status': 'active', // active, completed, failed
      'progress': 0,
    });
  }

  // Stream active goals
  Stream<List<Map<String, dynamic>>> getActiveGoalsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((data) {
        // Client-side filter for end date
        if (data['endDate'] is Timestamp) {
          return (data['endDate'] as Timestamp).toDate().isAfter(now);
        }
        return false;
      }).toList();

      // Client-side sort
      docs.sort((a, b) {
        // Sort by startDate descending (newest first)
        final aDate =
            (a['startDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bDate =
            (b['startDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return docs;
    });
  }

  // Delete a goal
  Future<void> deleteGoal(String goalId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId)
        .delete();
  }
}
