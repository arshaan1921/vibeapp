import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meme_mania.dart';
import '../models/user.dart';
import 'notification_service.dart';
import 'block_service.dart';

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
            meme_participants!inner (user_id)
          ''')
          .eq('meme_participants.user_id', userId)
          .eq('is_active', true)
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> gamesData = List<Map<String, dynamic>>.from(response);
      
      for (var game in gamesData) {
        final creatorId = game['creator_id'];
        final creator = await _supabase.from('profiles').select().eq('id', creatorId).single();
        game['profiles'] = creator; // The model expects 'profiles' for creator data
      }

      return gamesData.map((data) => MemeGame.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching memes: $e');
      rethrow;
    }
  }

  Future<MemeGame> getGameDetails(String memeId) async {
    final response = await _supabase
        .from('meme_games')
        .select('*')
        .eq('id', memeId)
        .single();
    
    final creatorId = response['creator_id'];
    final creator = await _supabase.from('profiles').select().eq('id', creatorId).single();
    response['profiles'] = creator;

    return MemeGame.fromJson(response);
  }

  Future<int> getUnreadGamesCount() async {
    try {
      final response = await _supabase
          .from('meme_participants')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('is_seen', false);
      
      return (response as List).length;
    } catch (e) {
      print('Error getting unread memes count: $e');
      return 0;
    }
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

    // Fetch creator username
    final creatorProfile = await _supabase.from('profiles').select('username').eq('id', userId).single();
    final creatorUsername = creatorProfile['username'] ?? "Someone";

    final allParticipantIds = {userId, ...participantIds};
    
    final participants = allParticipantIds.map((id) => {
      'meme_id': memeId, 
      'user_id': id,
      'is_seen': id == userId,
    }).toList();

    await _supabase.from('meme_participants').insert(participants);

    // Send notifications
    for (final friendId in participantIds) {
      if (friendId != userId) {
        NotificationService.sendGameNotification(
          targetUserId: friendId,
          creatorUsername: creatorUsername,
        );
      }
    }
  }

  Future<void> markAsSeen(String memeId) async {
    await _supabase
        .from('meme_participants')
        .update({'is_seen': true})
        .match({'meme_id': memeId, 'user_id': currentUserId});
  }

  Future<void> deleteMemeGame(String memeId) async {
    final userId = currentUserId;
    await _supabase
        .from('meme_games')
        .delete()
        .match({'id': memeId, 'creator_id': userId});
  }

  Future<List<MemeComment>> getComments(String memeId) async {
    final userId = currentUserId;
    final response = await _supabase
        .from('meme_comments')
        .select('*, comment_votes(user_id)')
        .eq('meme_id', memeId)
        .order('upvotes', ascending: false)
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> commentsData = List<Map<String, dynamic>>.from(response);
    
    for (var comment in commentsData) {
      final commenterId = comment['user_id'];
      final profile = await _supabase.from('profiles').select().eq('id', commenterId).single();
      comment['profiles'] = profile;
    }

    return commentsData.map((data) => MemeComment.fromJson(data, currentUserId: userId)).toList();
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

  Future<List<AppUser>> getFriends() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final userId = user.id;
      debugPrint('MEME_DEBUG: currentUserId = $userId');

      // 1. Fetch friend IDs (Exact logic from Most Likely To)
      final friendsRes = await supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');

      debugPrint('MEME_DEBUG: friendships = $friendsRes');

      final List<String> friendIds = (friendsRes as List)
          .map((item) => item['user1_id'] == userId 
              ? item['user2_id'].toString() 
              : item['user1_id'].toString())
          .toList();

      debugPrint('MEME_DEBUG: friendIds = $friendIds');

      if (friendIds.isEmpty) return [];

      // 2. Fetch profiles
      final profilesResponse = await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', friendIds);

      debugPrint('MEME_DEBUG: profiles = $profilesResponse');

      final List<AppUser> friends = (profilesResponse as List)
          .map((p) => AppUser.fromJson(p))
          .where((f) => !blockService.isBlocked(f.id))
          .toList();

      debugPrint('MEME_DEBUG: FINAL friends count = ${friends.length}');
      return friends;
    } catch (e) {
      debugPrint('MEME_DEBUG: Error fetching friends: $e');
      return [];
    }
  }

  Future<List<AppUser>> getSavedUsers() async {
    final response = await _supabase.from('profiles').select('*').limit(50);
    return (response as List).map((data) => AppUser.fromJson(data)).toList();
  }
}
