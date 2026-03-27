import 'user.dart';

class Game {
  final String id;
  final String gameType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? endsAt;
  final String status;
  final List<AppUser> participants;

  Game({
    required this.id,
    required this.gameType,
    required this.createdBy,
    required this.createdAt,
    this.endsAt,
    required this.status,
    this.participants = const [],
  });

  bool get isExpired => endsAt != null && DateTime.now().isAfter(endsAt!);

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      gameType: json['game_type'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at']) : null,
      status: json['status'] ?? 'active',
      participants: (json['game_participants'] as List?)
              ?.map((p) => AppUser.fromJson(p['profiles']))
              .toList() ??
          [],
    );
  }
}

class GameAction {
  final String id;
  final String gameId;
  final String userId;
  final String actionType;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  GameAction({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.actionType,
    required this.data,
    required this.createdAt,
  });

  factory GameAction.fromJson(Map<String, dynamic> json) {
    return GameAction(
      id: json['id'],
      gameId: json['game_id'],
      userId: json['user_id'],
      actionType: json['action_type'],
      data: json['data'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
