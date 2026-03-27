import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game.dart';
import '../models/user.dart';

class GameService {
  final _supabase = Supabase.instance.client;

  Future<List<Game>> getActiveGames(String gameType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('games')
        .select('*, game_participants!inner(profiles(*))')
        .eq('game_type', gameType)
        .eq('status', 'active')
        .eq('game_participants.user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Game.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getActiveGamesWithStatus(String gameType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('games')
        .select('*, game_participants!inner(profiles(*)), game_actions(user_id, action_type)')
        .eq('game_type', gameType)
        .eq('status', 'active')
        .eq('game_participants.user_id', userId)
        .order('created_at', ascending: false);

    final games = (response as List).map((json) {
      final game = Game.fromJson(json);
      final actions = json['game_actions'] as List;
      final hasVoted = actions.any((a) => a['user_id'] == userId && a['action_type'] == 'vote');
      return {
        'game': game,
        'hasVoted': hasVoted,
      };
    }).toList();

    return games;
  }

  Future<Game> createGame(String gameType, List<String> participantIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Not authenticated");

    final allParticipants = {...participantIds, userId}.toList();

    final endsAt = DateTime.now().add(const Duration(hours: 24));
    final gameData = await _supabase.from('games').insert({
      'game_type': gameType,
      'created_by': userId,
      'status': 'active',
      'ends_at': endsAt.toIso8601String(),
    }).select().single();

    final gameId = gameData['id'];

    final participantsInsert = allParticipants.map((id) => {
      'game_id': gameId,
      'user_id': id,
    }).toList();

    await _supabase.from('game_participants').insert(participantsInsert);

    final completeGameData = await _supabase
        .from('games')
        .select('*, game_participants(profiles(*))')
        .eq('id', gameId)
        .single();

    return Game.fromJson(completeGameData);
  }

  Future<void> submitAction(String gameId, String actionType, Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('game_actions').insert({
      'game_id': gameId,
      'user_id': userId,
      'action_type': actionType,
      'data': data,
    });
  }

  Stream<List<GameAction>> streamActions(String gameId) {
    return _supabase
        .from('game_actions')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('created_at')
        .map((data) => data.map((json) => GameAction.fromJson(json)).toList());
  }

  Future<Game> getGameById(String gameId) async {
    final response = await _supabase
        .from('games')
        .select('*, game_participants(profiles(*))')
        .eq('id', gameId)
        .single();
    return Game.fromJson(response);
  }

  Future<int> getUnvotedGamesCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final gamesResponse = await _supabase
        .from('games')
        .select('id, game_actions(user_id, action_type), game_participants!inner(user_id)')
        .eq('status', 'active')
        .eq('game_participants.user_id', userId);

    int count = 0;
    for (var game in (gamesResponse as List)) {
      final actions = game['game_actions'] as List;
      bool hasVoted = actions.any((a) => a['user_id'] == userId && a['action_type'] == 'vote');
      if (!hasVoted) count++;
    }
    return count;
  }
}
