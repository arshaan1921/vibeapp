import 'user.dart';

class SecretCrushGame {
  final String id;
  final String createdBy;
  final DateTime createdAt;
  final AppUser? creator;
  final bool hasSelected;

  SecretCrushGame({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    this.creator,
    this.hasSelected = false,
  });

  factory SecretCrushGame.fromJson(Map<String, dynamic> json) {
    return SecretCrushGame(
      id: json['id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      creator: json['profiles'] != null ? AppUser.fromJson(json['profiles']) : null,
      hasSelected: json['secret_crush_participants']?[0]?['has_selected'] ?? false,
    );
  }
}

class SecretCrushMatch {
  final String id;
  final String user1Id;
  final String user2Id;
  final AppUser? user1;
  final AppUser? user2;
  final DateTime createdAt;

  SecretCrushMatch({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.user1,
    this.user2,
    required this.createdAt,
  });

  factory SecretCrushMatch.fromJson(Map<String, dynamic> json) {
    return SecretCrushMatch(
      id: json['id'],
      user1Id: json['user1'],
      user2Id: json['user2'],
      user1: json['user1_profile'] != null ? AppUser.fromJson(json['user1_profile']) : null,
      user2: json['user2_profile'] != null ? AppUser.fromJson(json['user2_profile']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
