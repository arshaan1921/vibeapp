import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class LikeService {
  static final _supabase = Supabase.instance.client;

  static Future<void> likeAnswer(String answerId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('answer_likes').insert({
        'answer_id': answerId,
        'user_id': user.id,
      });
      
      // Fetch answer owner to send notification
      final answerData = await _supabase
          .from('answers')
          .select('user_id, profiles:user_id(username)')
          .eq('id', answerId)
          .maybeSingle();
      
      if (answerData != null && answerData['user_id'] != user.id) {
        final ownerId = answerData['user_id'];
        final likerUsername = (await _supabase.from('profiles').select('username').eq('id', user.id).single())['username'];
        
        NotificationService.sendNotification(
          userId: ownerId,
          title: "New Like!",
          body: "@$likerUsername liked your answer",
          data: {"type": "like", "answer_id": answerId},
        );
      }
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
