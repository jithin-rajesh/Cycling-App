import 'package:cloud_firestore/cloud_firestore.dart';

class ClubPostModel {
  final String id;
  final String clubId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String? imageUrl;
  final String description;
  final Timestamp timestamp;
  final int likes;

  ClubPostModel({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.imageUrl,
    required this.description,
    required this.timestamp,
    this.likes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'imageUrl': imageUrl,
      'description': description,
      'timestamp': timestamp,
      'likes': likes,
    };
  }

  factory ClubPostModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClubPostModel(
      id: docId,
      clubId: map['clubId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'User',
      userAvatar: map['userAvatar'] ?? '',
      imageUrl: map['imageUrl'],
      description: map['description'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      likes: map['likes'] ?? 0,
    );
  }
}
