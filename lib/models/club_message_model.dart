import 'package:cloud_firestore/cloud_firestore.dart';

class ClubMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final Timestamp timestamp;
  /// Map of 'Emoji' -> List of userIds who reacted with it
  final Map<String, List<String>> reactions;

  ClubMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': timestamp,
      'reactions': reactions,
    };
  }

  factory ClubMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClubMessageModel(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      senderAvatar: map['senderAvatar'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      reactions: (map['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>).map((e) => e.toString()).toList(),
            ),
          ) ??
          {},
    );
  }
}
