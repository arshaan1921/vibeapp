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

  static Future<void> _sendLikePushNotification(String answerId, String likerId) async {
    try {
      debugPrint("💓 LIKE_NOTIFICATION: Starting flow for answer: $answerId by liker: $likerId");
      
      // 1. Find answer owner ID (recipient)
      final answerData = await _supabase
          .from('answers')
          .select('user_id')
          .eq('id', answerId)
          .maybeSingle();

      if (answerData == null) {
        debugPrint("💓 LIKE_NOTIFICATION: ⚠️ Could not find answer owner for answerId: $answerId");
        return;
      }

      final String? ownerId = answerData['user_id']?.toString();
      debugPrint("💓 LIKE_NOTIFICATION: Answer owner ID found: $ownerId");

      if (ownerId == null) {
        debugPrint("💓 LIKE_NOTIFICATION: ⚠️ ownerId is null");
        return;
      }

      // ❌ Do not notify yourself
      if (ownerId == likerId) {
        debugPrint("💓 LIKE_NOTIFICATION: ℹ️ Skipping notification: Self-like");
        return;
      }

      // 2. Get liker's username (sender)
      final profileData = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', likerId)
          .maybeSingle();

      final likerUsername = profileData?['username'] ?? "Someone";
      debugPrint("💓 LIKE_NOTIFICATION: Liker username: $likerUsername");

      // 3. Save notification in DB for Activity Feed
      // We use 'like' to match LikesActivityScreen expectations
      try {
        await _supabase.from('notifications').insert({
          'user_id': ownerId,
          'source_user': likerId,
          'type': 'like',
          'source_id': answerId,
          'seen': false,
        });
        debugPrint("💓 LIKE_NOTIFICATION: ✅ DB notification record created");
      } catch (e) {
        debugPrint("💓 LIKE_NOTIFICATION: ⚠️ Failed to create DB notification: $e");
      }

      // 4. Invoke Edge Function for Push
      debugPrint("💓 LIKE_NOTIFICATION: 🚀 Calling NotificationService.sendNotification for recipient: $ownerId");
      await NotificationService.sendNotification(
        userId: ownerId,
        title: "New Like ❤️",
        body: "@$likerUsername liked your answer",
        data: {
          "type": "like",
          "answer_id": answerId,
          "sender_id": likerId, // Added to match working notifications
        },
      );
      debugPrint("💓 LIKE_NOTIFICATION: ✅ Like notification flow complete");
      
    } catch (e) {
      debugPrint("💓 LIKE_NOTIFICATION: 🔥 CRITICAL ERROR: $e");
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
