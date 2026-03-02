import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club_model.dart';
import '../models/club_post_model.dart';
import '../models/club_message_model.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all clubs
  Future<List<ClubModel>> getClubs({String? activityType}) async {
    // If no clubs exist, we'll create some generic ones (in a real app, this would be admin side)
    Query query = _firestore.collection('clubs');

    if (activityType != null && activityType != 'All') {
      query = query.where('activityType', isEqualTo: activityType);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty &&
        (activityType == null || activityType == 'All')) {
      await _seedClubs();
      return getClubs();
    }

    return snapshot.docs
        .map((doc) => ClubModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> _seedClubs() async {
    final clubs = [
      ClubModel(
        id: 'relaxed_riders',
        name: 'Relaxed Riders',
        description:
            'For those who enjoy the journey more than the speed. Join us for scenic rides and good vibes.',
        imageUrl: '',
        memberCount: 120,
        activityType: 'Cycling',
      ),
      ClubModel(
        id: 'weekend_warriors',
        name: 'Weekend Warriors',
        description:
            'We crush miles on Saturdays and Sundays. Join the challenge!',
        imageUrl: '',
        memberCount: 340,
        activityType: 'Cycling',
      ),
      ClubModel(
        id: 'elite_cyclists',
        name: 'Elite Cyclists',
        description: 'High performance training club. Push your limits.',
        imageUrl: '',
        memberCount: 85,
        activityType: 'Cycling',
      ),
      ClubModel(
        id: 'morning_joggers',
        name: 'Morning Joggers',
        description: 'Start your day with a run. Sunrise chasers welcome.',
        imageUrl: '',
        memberCount: 200,
        activityType: 'Running',
      ),
    ];

    final batch = _firestore.batch();
    for (var club in clubs) {
      batch.set(_firestore.collection('clubs').doc(club.id), club.toMap());
    }
    await batch.commit();
  }

  // Create Club
  Future<void> createClub({
    required String name,
    required String description,
    required String activityType,
    required bool isPrivate,
    String? imageUrl,
    int? iconCodePoint,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final docRef = _firestore.collection('clubs').doc();
    String? inviteCode;

    if (isPrivate) {
      // Simple 6-char random code
      inviteCode =
          DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    }

    final club = ClubModel(
      id: docRef.id,
      name: name,
      description: description,
      imageUrl: imageUrl ?? '',
      memberCount: 1,
      isPrivate: isPrivate,
      inviteCode: inviteCode,
      activityType: activityType,
      adminIds: [user.uid],
      iconCodePoint: iconCodePoint,
    );

    await docRef.set(club.toMap());

    // Auto-join the creator
    await joinClub(docRef.id, code: inviteCode);
  }

  // Check if user is member
  Future<bool> isMember(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(user.uid)
        .get();

    return doc.exists;
  }

  // Join Club
  Future<void> joinClub(String clubId, {String? code}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    if (!clubDoc.exists) throw Exception('Club not found');

    final club = ClubModel.fromMap(clubDoc.data()!);

    if (club.isPrivate) {
      if (code == null || code != club.inviteCode) {
        // Allow if user is admin (e.g. creator joining)
        if (!club.adminIds.contains(user.uid)) {
          throw Exception('Invalid invite code');
        }
      }
    }

    final batch = _firestore.batch();

    // Add to members subcollection
    final memberRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(user.uid);
    batch.set(memberRef, {
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Increment member count
    final clubRef = _firestore.collection('clubs').doc(clubId);
    batch.update(clubRef, {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Leave Club
  Future<void> leaveClub(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();

    // Remove from members
    final memberRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(user.uid);
    batch.delete(memberRef);

    // Decrement member count
    final clubRef = _firestore.collection('clubs').doc(clubId);
    batch.update(clubRef, {
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Get Posts
  Stream<List<ClubPostModel>> getClubPosts(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClubPostModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Create Post
  Future<void> createPost(String clubId, String description, String? imageUrl,
      [String? activityId]) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final userName = userData?['preferredName'] ?? user.displayName ?? 'User';
    final userAvatar = userData?['photoUrl'] ?? '';

    final post = {
      'clubId': clubId,
      'userId': user.uid,
      'userName': userName,
      'userAvatar': userAvatar,
      'description': description,
      'imageUrl': imageUrl,
      'activityId': activityId,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
    };

    await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('posts')
        .add(post);
  }

  // --- Chat Functionality ---

  // Send Message
  Future<void> sendMessage(String clubId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final userName = userData?['preferredName'] ?? user.displayName ?? 'User';
    final userAvatar = userData?['photoUrl'] ?? '';

    final message = {
      'senderId': user.uid,
      'senderName': userName,
      'senderAvatar': userAvatar,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .add(message);
  }

  // Get Messages Stream
  Stream<List<ClubMessageModel>> getClubMessages(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClubMessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Toggle Reaction
  Future<void> toggleReaction(
      String clubId, String messageId, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .doc(messageId);

    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() as Map<String, dynamic>;
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final userList = List<String>.from(reactions[emoji] ?? []);

    if (userList.contains(user.uid)) {
      userList.remove(user.uid);
      if (userList.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = userList;
      }
    } else {
      userList.add(user.uid);
      reactions[emoji] = userList;
    }

    await docRef.update({'reactions': reactions});
  }

  // Join Club by Code (for direct entry)
  Future<ClubModel?> joinClubByCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Find club with this code
    final snapshot = await _firestore
        .collection('clubs')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final clubDoc = snapshot.docs.first;
    final club = ClubModel.fromMap(clubDoc.data());

    // Check if already a member
    if (await isMember(club.id)) {
      return club;
    }

    // Join
    await joinClub(club.id, code: code);
    return club;
  }
}
