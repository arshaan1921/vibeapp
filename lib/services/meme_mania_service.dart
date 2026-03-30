import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meme_mania.dart';
import '../models/user.dart';

class MemeManiaService {
  final _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser!.id;

  Future<List<MemeGame>> getActiveGames() async {
    final userId = currentUserId;
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final response = await _supabase
          .from('meme_games')
          .select('''
            *,
            profiles:creator_id (*),
            meme_participants!inner (user_id)
          ''')
          .eq('meme_participants.user_id', userId)
          .eq('is_active', true)
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      return (response as List).map((data) {
        return MemeGame.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching memes: $e');
      rethrow;
    }
  }

  Future<MemeGame> getGameDetails(String memeId) async {
    final response = await _supabase
        .from('meme_games')
        .select('*, profiles:creator_id(*)')
        .eq('id', memeId)
        .single();
    return MemeGame.fromJson(response);
  }

  Future<void> createMemeGame({
    required File imageFile,
    String? caption,
    required List<String> participantIds,
  }) async {
    final userId = currentUserId;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'memes/$userId/$fileName';

    await _supabase.storage.from('memes').upload(path, imageFile);
    final imageUrl = _supabase.storage.from('memes').getPublicUrl(path);

    final game = await _supabase.from('meme_games').insert({
      'creator_id': userId,
      'image_url': imageUrl,
      'caption': caption,
      'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
    }).select().single();

    final memeId = game['id'];

    final allParticipantIds = {userId, ...participantIds};
    
    final participants = allParticipantIds.map((id) => {
      'meme_id': memeId, 
      'user_id': id
    }).toList();

    await _supabase.from('meme_participants').insert(participants);
  }

  Future<void> deleteMemeGame(String memeId) async {
    final userId = currentUserId;
    // RLS will also handle this, but we match for safety
    await _supabase
        .from('meme_games')
        .delete()
        .match({'id': memeId, 'creator_id': userId});
  }

  Future<List<MemeComment>> getComments(String memeId) async {
    final userId = currentUserId;
    final response = await _supabase
        .from('meme_comments')
        .select('*, profiles:user_id(*), comment_votes(user_id)')
        .eq('meme_id', memeId)
        .order('upvotes', ascending: false)
        .order('created_at', ascending: true);

    return (response as List).map((data) => MemeComment.fromJson(data, currentUserId: userId)).toList();
  }

  Future<void> addComment(String memeId, String commentText) async {
    final userId = currentUserId;
    await _supabase.from('meme_comments').insert({
      'meme_id': memeId,
      'user_id': userId,
      'comment': commentText,
    });
  }

  Future<void> toggleLike(String commentId) async {
    final userId = currentUserId;

    final existing = await _supabase
        .from('comment_votes')
        .select()
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('comment_votes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);

      await _supabase.rpc('decrement_comment_upvotes',
          params: {'row_id': commentId});

    } else {
      await _supabase.from('comment_votes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });

      await _supabase.rpc('increment_comment_upvotes',
          params: {'row_id': commentId});
    }
  }

  Future<List<AppUser>> getSavedUsers() async {
    final response = await _supabase.from('profiles').select('*').limit(50);
    return (response as List).map((data) => AppUser.fromJson(data)).toList();
  }
}
