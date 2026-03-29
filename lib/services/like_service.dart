import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class LikeService {
  static final _supabase = Supabase.instance.client;

  static Future<void> likeAnswer(String answerId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Insert like
      await _supabase.from('answer_likes').insert({
        'answer_id': answerId,
        'user_id': user.id,
      });

      // 2. Get answer owner
      final answerData = await _supabase
          .from('answers')
          .select('user_id')
          .eq('id', answerId)
          .maybeSingle();

      if (answerData == null) return;

      final ownerId = answerData['user_id'];

      // ❌ Do not notify yourself
      if (ownerId == user.id) return;

      // 3. Get your username
      final profileData = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      final likerUsername = profileData?['username'] ?? "Someone";

      // 4. Save notification in DB
      await _supabase.from('notifications').insert({
        'user_id': ownerId,
        'source_user': user.id,
        'type': 'like',
        'source_id': answerId,
        'seen': false,
      });

      // 5. Send PUSH (✅ SAME WORKING SYSTEM)
      final session = _supabase.auth.currentSession;
      final accessToken = session?.accessToken;

      await _supabase.functions.invoke(
        'supabase-functions-new-send-push-notification',
        body: {
          "user_id": ownerId,
          "title": "New Like ❤️",
          "body": "@$likerUsername liked your answer",
          "data": {
            "type": "like",
            "answer_id": answerId,
          }
        },
        headers: {
          "Authorization": "Bearer $accessToken",
        },
      );
    } catch (e) {
      debugPrint("Error in likeAnswer: $e");
      rethrow;
    }
  }

  static Future<void> unlikeAnswer(String answerId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('answer_likes')
          .delete()
          .eq('answer_id', answerId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint("Error in unlikeAnswer: $e");
      rethrow;
    }
  }
}
