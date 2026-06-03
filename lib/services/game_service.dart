import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game.dart';
import '../models/user.dart';
import 'notification_service.dart';

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

    // Send notifications
    try {
      final creatorProfile = await _supabase.from('profiles').select('username').eq('id', userId).single();
      final creatorUsername = creatorProfile['username'] ?? "Someone";

      for (final id in participantIds) {
        if (id != userId) {
          NotificationService.sendGameNotification(
            targetUserId: id,
            creatorUsername: creatorUsername,
          );
        }
      }
    } catch (e) {
      debugPrint("Error sending generic game notification: $e");
    }

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

    print('BADGE_DEBUG: START Aggregating counts for $userId');

    int totalCount = 0;

    // 1. Generic Games
    try {
      final gamesResponse = await _supabase
          .from('games')
          .select('id, game_actions(user_id, action_type), game_participants!inner(user_id)')
          .eq('status', 'active')
          .eq('game_participants.user_id', userId)
          .neq('created_by', userId);

      int genericCount = 0;
      for (var game in (gamesResponse as List)) {
        final actions = game['game_actions'] as List;
        bool hasVoted = actions.any((a) => a['user_id'] == userId && a['action_type'] == 'vote');
        if (!hasVoted) genericCount++;
      }
      totalCount += genericCount;
      print('BADGE_DEBUG: Generic = $genericCount');
    } catch (e) {
      print('BADGE_DEBUG: Generic Error = $e');
    }

    // 2. Most Likely To
    try {
      final mlResponse = await _supabase
          .from('most_likely_participants')
          .select('user_id, most_likely_games!inner(status)')
          .eq('user_id', userId)
          .eq('most_likely_games.status', 'active')
          .not('is_seen', 'eq', true);
      int mlCount = (mlResponse as List).length;
      totalCount += mlCount;
      print('BADGE_DEBUG: Most Likely = $mlCount');
    } catch (e) {
      print('BADGE_DEBUG: Most Likely Error = $e');
    }

    // 3. Two Truths & One Lie
    try {
      final tlResponse = await _supabase
          .from('truth_lie_participants')
          .select('user_id, truth_lie_games!inner(status)')
          .eq('user_id', userId)
          .eq('truth_lie_games.status', 'active')
          .not('is_seen', 'eq', true);
      int tlCount = (tlResponse as List).length;
      totalCount += tlCount;
      print('BADGE_DEBUG: Truth Lie = $tlCount');
    } catch (e) {
      print('BADGE_DEBUG: Truth Lie Error = $e');
    }

    // 4. Rate Me Brutally
    try {
      final rateResponse = await _supabase
          .from('rate_game_participants')
          .select('user_id')
          .eq('user_id', userId)
          .not('is_seen', 'eq', true);
      
      // Currently rate_games doesn't seem to have a 'status' column in the model, 
      // keeping it simple but wrapping in try-catch.
      int rateCount = (rateResponse as List).length;
      totalCount += rateCount;
      print('BADGE_DEBUG: Rate Me = $rateCount');
    } catch (e) {
      print('BADGE_DEBUG: Rate Me Error = $e');
    }

    // 5. Meme Mania
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final memeResponse = await _supabase
          .from('meme_participants')
          .select('user_id, meme_games!inner(is_active, expires_at)')
          .eq('user_id', userId)
          .eq('meme_games.is_active', true)
          .gt('meme_games.expires_at', now)
          .not('is_seen', 'eq', true);

      int memeCount = (memeResponse as List).length;
      totalCount += memeCount;
      print('BADGE_DEBUG: Meme Mania = $memeCount');
    } catch (e) {
      print('BADGE_DEBUG: Meme Mania Error = $e');
    }

    print('BADGE_DEBUG: FINAL TOTAL = $totalCount');
    return totalCount;
  }
}
