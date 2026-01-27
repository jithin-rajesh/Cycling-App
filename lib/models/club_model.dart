
class ClubModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int memberCount;

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.memberCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'memberCount': memberCount,
    };
  }

  factory ClubModel.fromMap(Map<String, dynamic> map) {
    return ClubModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      memberCount: map['memberCount'] ?? 0,
    );
  }
}
