import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class MentionService {
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final supabase = Supabase.instance.client;
      // Search by username, limit to 5 suggestions
      final response = await supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .ilike('username', '%$query%')
          .limit(5);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching users for mentions: $e');
      return [];
    }
  }

  /// Extracts user IDs from a text containing @mentions
  static Future<List<String>> getMentionedUserIds(String text) async {
    final regex = RegExp(r"@[a-zA-Z0-9_]+");
    final matches = regex.allMatches(text);
    final usernames = matches.map((m) => m.group(0)!.substring(1).toLowerCase()).toSet().toList();
    
    if (usernames.isEmpty) return [];

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('id')
          .inFilter('username', usernames);
      
      return (response as List).map((u) => u['id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting mentioned user IDs: $e');
      return [];
    }
  }

  /// Sends notifications to all mentioned users
  static Future<void> notifyMentionedUsers({
    required String text,
    required String sourceId,
    required String type, // 'answer', 'reply', 'question'
    required String sourceUser,
  }) async {
    final mentionedIds = await getMentionedUserIds(text);
    if (mentionedIds.isEmpty) return;

    final supabase = Supabase.instance.client;
    
    // Fetch source user's username for the notification body
    final profileRes = await supabase.from('profiles').select('username').eq('id', sourceUser).maybeSingle();
    final username = profileRes?['username'] ?? "Someone";

    for (final userId in mentionedIds) {
      if (userId == sourceUser) continue; // Don't notify self

      try {
        // 1. Insert DB notification
        await supabase.from('notifications').insert({
          'user_id': userId,
          'source_user': sourceUser,
          'source_id': sourceId,
          'type': 'mention', 
          'seen': false,
          'data': {'original_type': type}
        });

        // 2. Send Push
        String title = "New Mention! 🏷️";
        String body = "@$username mentioned you in a $type";
        
        await supabase.functions.invoke(
          'supabase-functions-new-send-push-notification',
          body: {
            'user_id': userId,
            'title': title,
            'body': body,
            'data': {
              'type': 'mention',
              'source_id': sourceId,
              'original_type': type,
            },
          },
        );
      } catch (e) {
        debugPrint('Error notifying mentioned user $userId: $e');
      }
    }
  }
}
