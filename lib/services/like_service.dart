import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class LikeService {
  static final _supabase = Supabase.instance.client;

  /// Toggles a like on an answer.
  /// If liked, it removes it. If not liked, it adds it and sends a notification.
  static Future<bool> toggleLike(String answerId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if already liked
      final existingLike = await _supabase
          .from('answer_likes')
          .select()
          .eq('answer_id', answerId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        // Already liked, so UNLIKE
        await _supabase
            .from('answer_likes')
            .delete()
            .eq('answer_id', answerId)
            .eq('user_id', user.id);
        debugPrint("❤️ Like removed for answer: $answerId");
        return false; // Result is NOT liked
      } else {
        // Not liked, so LIKE
        await _supabase.from('answer_likes').insert({
          'answer_id': answerId,
          'user_id': user.id,
        });
        debugPrint("❤️ Like inserted for answer: $answerId");

        // Send notification asynchronously
        _sendLikePushNotification(answerId, user.id).catchError((e) {
          debugPrint("❌ Non-critical error in like notification: $e");
        });
        return true; // Result is liked
      }
    } catch (e) {
      debugPrint("❌ Error in toggleLike: $e");
      rethrow;
    }
  }

  static Future<void> _sendLikePushNotification(String answerId, String userId) async {
    try {
      // 1. Find answer owner
      final answerData = await _supabase
          .from('answers')
          .select('user_id')
          .eq('id', answerId)
          .maybeSingle();

      if (answerData == null) {
        debugPrint("⚠️ Could not find answer owner for notification");
        return;
      }

      final ownerId = answerData['user_id'];
      debugPrint("👤 Answer owner found: $ownerId");

      // ❌ Do not notify yourself
      if (ownerId == userId) {
        debugPrint("ℹ️ Skipping notification: Self-like");
        return;
      }

      // 2. Get liker's username
      final profileData = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();

      final likerUsername = profileData?['username'] ?? "Someone";

      // 3. Save notification in DB for Activity Feed
      await _supabase.from('notifications').upsert({
        'user_id': ownerId,
        'source_user': userId,
        'type': 'answer_like',
        'source_id': answerId,
        'seen': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 4. Invoke Edge Function for Push
      final payload = {
        "user_id": ownerId,
        "title": "❤️ New Like",
        "body": "$likerUsername liked your answer",
        "data": {
          "type": "answer_like",
          "answer_id": answerId,
          "liker_id": userId
        }
      };

      debugPrint("🚀 Sending notification payload: $payload");

      await NotificationService.sendNotification(
        userId: ownerId,
        title: payload["title"] as String,
        body: payload["body"] as String,
        data: payload["data"] as Map<String, dynamic>,
      );

      debugPrint("✅ Like notification sent successfully");
      
    } catch (e) {
      debugPrint("❌ Error sending like notification: $e");
    }
  }

  // Legacy methods kept for compatibility if needed, 
  // but recommended to use toggleLike
  static Future<void> likeAnswer(String answerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    await _supabase.from('answer_likes').upsert({
      'answer_id': answerId,
      'user_id': user.id,
    });
    
    _sendLikePushNotification(answerId, user.id).catchError((e) => debugPrint(e.toString()));
  }

  static Future<void> unlikeAnswer(String answerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    await _supabase
        .from('answer_likes')
        .delete()
        .eq('answer_id', answerId)
        .eq('user_id', user.id);
  }
}
