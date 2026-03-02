class ClubModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int memberCount;
  final bool isPrivate;
  final String? inviteCode;
  final String activityType; // e.g., 'Cycling', 'Running', 'Gym', 'Mixed'
  final List<String> adminIds;
  final int? iconCodePoint; // Material Icons code point for the club icon

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.memberCount = 0,
    this.isPrivate = false,
    this.inviteCode,
    this.activityType = 'Mixed',
    this.adminIds = const [],
    this.iconCodePoint,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'memberCount': memberCount,
      'isPrivate': isPrivate,
      'inviteCode': inviteCode,
      'activityType': activityType,
      'adminIds': adminIds,
      'iconCodePoint': iconCodePoint,
    };
  }

  factory ClubModel.fromMap(Map<String, dynamic> map) {
    return ClubModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      memberCount: map['memberCount'] ?? 0,
      isPrivate: map['isPrivate'] ?? false,
      inviteCode: map['inviteCode'],
      activityType: map['activityType'] ?? 'Mixed',
      adminIds: List<String>.from(map['adminIds'] ?? []),
      iconCodePoint: map['iconCodePoint'],
    );
  }
}
