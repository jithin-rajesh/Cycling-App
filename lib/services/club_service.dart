import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club_model.dart';
import '../models/club_post_model.dart';
import '../models/club_message_model.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all clubs
  Future<List<ClubModel>> getClubs() async {
    // If no clubs exist, we'll create some generic ones (in a real app, this would be admin side)
    final snapshot = await _firestore.collection('clubs').get();

    if (snapshot.docs.isEmpty) {
      await _seedClubs();
      return getClubs();
    }

    return snapshot.docs.map((doc) => ClubModel.fromMap(doc.data())).toList();
  }

  Future<void> _seedClubs() async {
    final clubs = [
      ClubModel(
        id: 'relaxed_riders',
        name: 'Relaxed Riders',
        description:
            'For those who enjoy the journey more than the speed. Join us for scenic rides and good vibes.',
        imageUrl:
            'https://images.unsplash.com/photo-1541625602330-2277a4c46182?ixlib=rb-1.2.1&auto=format&fit=crop&w=1950&q=80',
        memberCount: 120,
      ),
      ClubModel(
        id: 'weekend_warriors',
        name: 'Weekend Warriors',
        description:
            'We crush miles on Saturdays and Sundays. Join the challenge!',
        imageUrl:
            'https://images.unsplash.com/photo-1517649763962-0c623066013b?ixlib=rb-1.2.1&auto=format&fit=crop&w=1950&q=80',
        memberCount: 340,
      ),
      ClubModel(
        id: 'elite_cyclists',
        name: 'Elite Cyclists',
        description: 'High performance training club. Push your limits.',
        imageUrl:
            'https://images.unsplash.com/photo-1558556209-760775d5069b?ixlib=rb-1.2.1&auto=format&fit=crop&w=1950&q=80',
        memberCount: 85,
      ),
      ClubModel(
        id: 'morning_joggers',
        name: 'Morning Joggers',
        description: 'Start your day with a run. Sunrise chasers welcome.',
        imageUrl:
            'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?ixlib=rb-1.2.1&auto=format&fit=crop&w=1950&q=80',
        memberCount: 200,
      ),
    ];

    final batch = _firestore.batch();
    for (var club in clubs) {
      batch.set(_firestore.collection('clubs').doc(club.id), club.toMap());
    }
    await batch.commit();
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
  Future<void> joinClub(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) return;

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

    // Add to user's joined clubs (optional, for quick access)
    // batch.set(_firestore.collection('users').doc(user.uid).collection('joinedClubs').doc(clubId), {});

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
}
