import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class GameNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Generic notification method for all game types
  /// [recipientId] - ID of the user receiving the notification
  /// [gameId] - ID of the game instance
  /// [gameType] - 'most_likely', 'truth_lie', or 'meme'
  /// [action] - 'invitation', 'vote', 'completed', 'results', etc.
  /// [title] - Push notification title
  /// [body] - Push notification body
  static Future<void> notify({
    required String recipientId,
    required String gameId,
    required String gameType,
    required String action,
    required String title,
    required String body,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (recipientId == user.id) return;

    // 1. Store in DB (notifications table)
    try {
      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'source_user': user.id,
        'type': 'game:$gameType:$action',
        'source_id': gameId,
        'seen': false,
      });
    } catch (e) {
      // If source_id is not UUID and DB expects it, this might fail.
      // Assuming it's UUID as most IDs in this app seem to be.
    }

    // 2. Send FCM Push via Edge Function
    await NotificationService.sendNotification(
      userId: recipientId,
      title: title,
      body: body,
      data: {
        'type': 'game',
        'game_type': gameType,
        'game_id': gameId,
        'action': action,
      },
    );
  }

  /// Mark specific game notification as seen
  static Future<void> markAsSeen(String gameId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Find notifications for this source_id (gameId) that start with 'game:'
      await _supabase
          .from('notifications')
          .update({'seen': true})
          .eq('user_id', user.id)
          .eq('source_id', gameId)
          .filter('type', 'like', 'game:%');
    } catch (e) {
      debugPrint("Error marking game notification as seen: $e");
    }
  }
}
