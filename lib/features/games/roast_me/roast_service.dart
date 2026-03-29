import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RoastService {
  static final _supabase = Supabase.instance.client;

  static Future<void> createRoast(String text, List<String> invitedUserIds) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final post = await _supabase.from('roast_posts').insert({
      'user_id': user.id,
      'text': text,
    }).select().single();

    if (invitedUserIds.isNotEmpty) {
      final invites = invitedUserIds.map((invitedId) => {
        'roast_id': post['id'],
        'invited_user_id': invitedId,
      }).toList();
      await _supabase.from('roast_invites').insert(invites);
      
      // Notify invited users
      final creatorProfile = await _supabase.from('profiles').select('username').eq('id', user.id).single();
      final username = creatorProfile['username'] ?? "Someone";

      for (var invitedId in invitedUserIds) {
        try {
          final session = _supabase.auth.currentSession;
          final accessToken = session?.accessToken;

          if (accessToken != null) {
            await _supabase.functions.invoke(
              'supabase-functions-new-send-push-notification',
              body: {
                "user_id": invitedId,
                "title": "Roast Invitation!",
                "body": "@$username invited you to a roast: $text",
                "data": {"type": "roast_invite", "roast_id": post['id']}
              },
              headers: {
                "Authorization": "Bearer $accessToken",
              },
            );
          }
        } catch (e) {
          debugPrint("Push failed: $e");
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getRoastsForUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('roast_posts')
        .select('''
          *,
          profiles:user_id(username, avatar_url, premium_plan),
          roast_replies(count)
        ''')
        .or('user_id.eq.${user.id},id.in.(select roast_id from roast_invites where invited_user_id = "${user.id}")')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getRoastReplies(String roastId) async {
    final response = await _supabase
        .from('roast_replies')
        .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
        .eq('roast_id', roastId)
        .order('created_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addReply(String roastId, String text) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('roast_replies').insert({
      'roast_id': roastId,
      'user_id': user.id,
      'roast_text': text,
    });
    
    // Notify roast creator
    final roastData = await _supabase.from('roast_posts').select('user_id, text').eq('id', roastId).single();
    if (roastData['user_id'] != user.id) {
      final replierProfile = await _supabase.from('profiles').select('username').eq('id', user.id).single();
      final username = replierProfile['username'] ?? "Someone";

      try {
        final session = _supabase.auth.currentSession;
        final accessToken = session?.accessToken;

        if (accessToken != null) {
          await _supabase.functions.invoke(
            'supabase-functions-new-send-push-notification',
            body: {
              "user_id": roastData['user_id'],
              "title": "New Roast Reply!",
              "body": "@$username replied to your roast",
              "data": {"type": "roast_reply", "roast_id": roastId}
            },
            headers: {
              "Authorization": "Bearer $accessToken",
            },
          );
        }
      } catch (e) {
        debugPrint("Push failed: $e");
      }
    }
  }

  static Future<void> likeReply(String replyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('roast_likes').insert({
      'reply_id': replyId,
      'user_id': user.id,
    });
    
    // Notify reply author
    final replyData = await _supabase.from('roast_replies').select('user_id, roast_id').eq('id', replyId).single();
    if (replyData['user_id'] != user.id) {
       final likerProfile = await _supabase.from('profiles').select('username').eq('id', user.id).single();
       final username = likerProfile['username'] ?? "Someone";

       try {
         final session = _supabase.auth.currentSession;
         final accessToken = session?.accessToken;

         if (accessToken != null) {
           await _supabase.functions.invoke(
             'supabase-functions-new-send-push-notification',
             body: {
               "user_id": replyData['user_id'],
               "title": "Roast Like!",
               "body": "@$username liked your roast reply",
               "data": {"type": "roast_like", "roast_id": replyData['roast_id']}
             },
             headers: {
               "Authorization": "Bearer $accessToken",
             },
           );
         }
       } catch (e) {
         debugPrint("Push failed: $e");
       }
    }
  }

  static Future<void> unlikeReply(String replyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('roast_likes')
        .delete()
        .eq('reply_id', replyId)
        .eq('user_id', user.id);
  }

  static Future<Set<String>> getMyLikedReplies() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    final res = await _supabase
        .from('roast_likes')
        .select('reply_id')
        .eq('user_id', user.id);
    
    return (res as List).map((l) => l['reply_id'].toString()).toSet();
  }
}
