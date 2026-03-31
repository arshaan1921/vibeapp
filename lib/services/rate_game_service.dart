import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../models/rate_game.dart';
import '../models/user.dart';

class RateGameService {
  final _supabase = Supabase.instance.client;

  Future<List<RateGame>> getGames() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('rate_game_participants')
          .select('is_seen, has_voted, rate_games!inner(*, profiles!inner(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((data) {
        final gameData = data['rate_games'];
        return RateGame(
          id: gameData['id'],
          createdBy: gameData['created_by'],
          createdAt: DateTime.parse(gameData['created_at']),
          creator: AppUser.fromJson(gameData['profiles']),
          isSeen: data['is_seen'],
          hasVoted: data['has_voted'],
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createGame(List<String> participantIds) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Insert into rate_games
      final game = await _supabase
          .from('rate_games')
          .insert({'created_by': userId})
          .select()
          .single();

      final gameId = game['id'];

      // 2. Prepare participants list for bulk insert
      final participants = [
        {
          'game_id': gameId,
          'user_id': userId,
          'is_host': true,
          'is_seen': true, // Host has seen it
          'has_voted': false
        },
        ...participantIds.map((id) => {
              'game_id': gameId,
              'user_id': id,
              'is_host': false,
              'is_seen': false,
              'has_voted': false
            }),
      ];

      // 3. Bulk insert into rate_game_participants
      await _supabase.from('rate_game_participants').insert(participants);
    } catch (e) {
      // Rethrow to be caught by UI
      rethrow;
    }
  }

  Future<void> markAsSeen(String gameId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase
          .from('rate_game_participants')
          .update({'is_seen': true})
          .match({'game_id': gameId, 'user_id': userId});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAllAsSeen() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('rate_game_participants')
        .update({'is_seen': true})
        .eq('user_id', userId)
        .eq('is_seen', false);
  }

  Future<void> vote(String gameId, String rating) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final lowercaseRating = rating.toLowerCase();
      
      // ignore: avoid_print
      print('Rating being sent: $lowercaseRating');

      await _supabase.from('rate_votes').insert({
        'game_id': gameId,
        'voter_id': userId,
        'rating': lowercaseRating,
      });

      await _supabase
          .from('rate_game_participants')
          .update({'has_voted': true})
          .match({'game_id': gameId, 'user_id': userId});
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RateVote>> getVotesWithProfiles(String gameId) async {
    try {
      final response = await _supabase
          .from('rate_votes')
          .select('*, profiles(*)')
          .eq('game_id', gameId)
          .order('created_at');
      
      return (response as List).map((json) => RateVote.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamVotesRaw(String gameId) {
    return _supabase
        .from('rate_votes')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId);
  }

  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return res;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ DEBUG: Manual Fetch for Unread Count
  Future<int> getUnreadGamesCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    final userId = user.id;

    try {
      // 1. Check meme_participants
      final memeResponse = await _supabase
          .from('meme_participants')
          .select('id')
          .eq('user_id', userId)
          .eq('is_seen', false);

      // 2. Check rate_game_participants
      final rateResponse = await _supabase
          .from('rate_game_participants')
          .select('game_id')
          .eq('user_id', userId)
          .eq('is_seen', false);

      print("DEBUG: USER ID: $userId");
      print("DEBUG: MEME RESPONSE: $memeResponse");
      print("DEBUG: RATE RESPONSE: $rateResponse");

      final totalCount = (memeResponse as List).length + (rateResponse as List).length;
      print("DEBUG: FINAL UNREAD COUNT: $totalCount");

      return totalCount;
    } catch (e) {
      print("DEBUG: ERROR FETCHING COUNT: $e");
      return 0;
    }
  }

  Stream<int> streamUnseenGamesCount() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    print('📡 DEBUG: Setting up unseen games stream for user: $userId');

    final rateGames = _supabase
        .from('rate_game_participants')
        .stream(primaryKey: ['game_id', 'user_id'])
        .eq('user_id', userId)
        .map((data) {
          final count = data.where((row) => row['is_seen'] == false).length;
          print('🎮 DEBUG: RateGames unseen count: $count');
          return count;
        });

    final memeGames = _supabase
        .from('meme_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          final count = data.where((row) => row['is_seen'] == false).length;
          print('🤡 DEBUG: MemeGames unseen count: $count');
          return count;
        });

    return Rx.combineLatest2<int, int, int>(
      rateGames,
      memeGames,
      (a, b) {
        final total = a + b;
        print('🔔 DEBUG: Total unseen games badge: $total');
        return total;
      },
    ).asBroadcastStream();
  }
}
