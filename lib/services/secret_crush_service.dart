import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/secret_crush.dart';
import '../models/user.dart';

class SecretCrushService {
  final _supabase = Supabase.instance.client;

  Future<List<SecretCrushGame>> getGames() async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Fetch games where current user is a participant
    final response = await _supabase
        .from('secret_crush_participants')
        .select('has_selected, secret_crush_games!inner(*, profiles!inner(*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false, referencedTable: 'secret_crush_games');

    return (response as List).map((data) {
      final gameData = data['secret_crush_games'];
      return SecretCrushGame(
        id: gameData['id'],
        createdBy: gameData['created_by'],
        createdAt: DateTime.parse(gameData['created_at']),
        creator: AppUser.fromJson(gameData['profiles']),
        hasSelected: data['has_selected'],
      );
    }).toList();
  }

  Future<void> createGame(List<String> participantIds) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // 1. Create ONE game row
    final game = await _supabase
        .from('secret_crush_games')
        .insert({'created_by': userId})
        .select()
        .single();

    final gameId = game['id'];
    
    // 2. Add ALL participants (creator + friends) to SAME game_id
    final participants = [
      {'game_id': gameId, 'user_id': userId},
      ...participantIds.map((id) => {'game_id': gameId, 'user_id': id}),
    ];

    await _supabase.from('secret_crush_participants').insert(participants);
  }

  Future<void> deleteGame(String gameId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('secret_crush_games')
        .delete()
        .match({'id': gameId, 'created_by': userId});
  }

  Future<List<AppUser>> getParticipants(String gameId) async {
    final response = await _supabase
        .from('secret_crush_participants')
        .select('profiles(*)')
        .eq('game_id', gameId);
    
    return (response as List).map((data) => AppUser.fromJson(data['profiles'])).toList();
  }

  Future<void> selectCrush(String gameId, String crushId) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // All choices use the same gameId
    await _supabase.from('secret_crush_choices').insert({
      'game_id': gameId,
      'chooser_id': userId,
      'crush_id': crushId,
    });

    await _supabase
        .from('secret_crush_participants')
        .update({'has_selected': true})
        .match({'game_id': gameId, 'user_id': userId});
  }

  Future<SecretCrushMatch?> checkMatch(String gameId) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('secret_crush_matches')
        .select('*, user1_profile:profiles!user1(*), user2_profile:profiles!user2(*)')
        .eq('game_id', gameId)
        .or('user1.eq.$userId,user2.eq.$userId')
        .maybeSingle();

    if (response == null) return null;
    return SecretCrushMatch.fromJson(response);
  }

  Stream<List<Map<String, dynamic>>> streamMatchesTrigger(String gameId) {
    return _supabase
        .from('secret_crush_matches')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId);
  }
}
