import 'user.dart';

class RateGame {
  final String id;
  final String createdBy;
  final DateTime createdAt;
  final AppUser? creator;
  final bool isSeen;
  final bool hasVoted;

  RateGame({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    this.creator,
    this.isSeen = true,
    this.hasVoted = false,
  });

  factory RateGame.fromJson(Map<String, dynamic> json) {
    return RateGame(
      id: json['id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      creator: json['profiles'] != null ? AppUser.fromJson(json['profiles']) : null,
      isSeen: json['rate_game_participants']?[0]?['is_seen'] ?? true,
      hasVoted: json['rate_game_participants']?[0]?['has_voted'] ?? false,
    );
  }
}

class RateVote {
  final String id;
  final String gameId;
  final String voterId;
  final String rating;
  final AppUser? voter;

  RateVote({
    required this.id,
    required this.gameId,
    required this.voterId,
    required this.rating,
    this.voter,
  });

  factory RateVote.fromJson(Map<String, dynamic> json) {
    return RateVote(
      id: json['id'],
      gameId: json['game_id'],
      voterId: json['voter_id'],
      rating: json['rating'],
      voter: json['profiles'] != null ? AppUser.fromJson(json['profiles']) : null,
    );
  }
}
