import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import 'notification_service.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  Future<String> getOrCreateConversation(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    
    try {
      final myMemberRes = await _supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', currentUserId);
      
      final myConvIds = (myMemberRes as List).map((m) => m['conversation_id'].toString()).toList();
      
      if (myConvIds.isNotEmpty) {
        final existingRes = await _supabase
            .from('conversation_members')
            .select('conversation_id')
            .eq('user_id', otherUserId)
            .inFilter('conversation_id', myConvIds)
            .maybeSingle();
            
        if (existingRes != null) {
          return existingRes['conversation_id'].toString();
        }
      }

      final convRes = await _supabase.from('conversations').insert({}).select().single();
      final convId = convRes['id'];

      await _supabase.from('conversation_members').insert([
        {'conversation_id': convId, 'user_id': currentUserId, 'unread_count': 0},
        {'conversation_id': convId, 'user_id': otherUserId, 'unread_count': 0},
      ]);

      return convId.toString();
    } catch (e) {
      debugPrint("Error in getOrCreateConversation: $e");
      try {
        final response = await _supabase.rpc('get_conversation_by_users', params: {
          'user_id_1': currentUserId,
          'user_id_2': otherUserId,
        });
        if (response != null) return response.toString();
      } catch (_) {}
      rethrow;
    }
  }

  Stream<List<Conversation>> getConversationsStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);
    
    return _supabase
        .from('conversation_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .asyncMap((memberships) async {
          final conversations = <Conversation>[];
          
          for (var membership in memberships) {
            final convId = membership['conversation_id'];
            try {
              final res = await _supabase
                  .from('conversations')
                  .select('*, participants:conversation_members(*, profiles!user_id(id, username, avatar_url))')
                  .eq('id', convId)
                  .single();
              
              final fullMap = Map<String, dynamic>.from(res);

              final lastMsgRes = await _supabase
                  .from('messages')
                  .select('message, created_at, media_type, sender_id, status')
                  .eq('conversation_id', convId)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();

              if (lastMsgRes != null) {
                String text = lastMsgRes['message'] ?? '';
                if (text.isEmpty && lastMsgRes['media_type'] != null) {
                  text = "Shared a ${lastMsgRes['media_type']}";
                }
                fullMap['last_message'] = text;
                fullMap['last_message_at'] = lastMsgRes['created_at'];
                fullMap['last_message_sender_id'] = lastMsgRes['sender_id'];
                fullMap['last_message_status'] = lastMsgRes['status'];
              }
              
              conversations.add(Conversation.fromMap(fullMap, user.id));
            } catch (e) {
              debugPrint("Error fetching details for conversation $convId: $e");
            }
          }
          
          conversations.sort((a, b) {
            final dateA = a.lastMessageAt ?? a.createdAt;
            final dateB = b.lastMessageAt ?? b.createdAt;
            return dateB.compareTo(dateA);
          });
          
          return conversations;
        });
  }

  Stream<int> getTotalUnreadCountStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value(0);

    return _supabase
        .from('conversation_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map((memberships) {
          int total = 0;
          for (var m in memberships) {
            total += (m['unread_count'] as int? ?? 0);
          }
          return total;
        });
  }

  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data.map((m) => MessageModel.fromMap(m)).toList());
  }

  Future<String?> uploadMedia(File file, String path) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split("/").last}';
      final fullPath = '$path/$fileName';
      await _supabase.storage.from('chat_media').upload(fullPath, file);
      return _supabase.storage.from('chat_media').getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('Media upload error: $e');
      return null;
    }
  }

  Future<void> sendMessage(String conversationId, String text, {String? mediaUrl, String? mediaType}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Get sender's info (username and avatar)
    final senderProfile = await _supabase
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', user.id)
        .single();
    final senderName = senderProfile['username'] ?? 'Someone';
    final senderAvatar = senderProfile['avatar_url'];
    
    final messageData = {
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message': text,
      'status': 'sent',
    };
    if (mediaUrl != null) messageData['media_url'] = mediaUrl;
    if (mediaType != null) messageData['media_type'] = mediaType;

    // 1. Insert message
    await _supabase.from('messages').insert(messageData);
    
    String lastMsg = text.isEmpty ? "Shared a $mediaType" : text;
    
    try {
      // Get receiver's ID
      final membersRes = await _supabase
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', user.id)
          .single();
      
      final receiverId = membersRes['user_id'];

      await Future.wait([
        _supabase.from('conversations').update({
          'last_message': lastMsg,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', conversationId),
        
        _supabase.rpc('increment_conversation_unread', params: {
          'conv_id': conversationId,
          'exclude_user_id': user.id,
        }),
      ]);

      // 🔥 SEPARATE CHAT PUSH NOTIFICATION BLOCK
      try {
        final session = _supabase.auth.currentSession;
        final accessToken = session?.accessToken;

        if (accessToken != null && receiverId != user.id) {
          await _supabase.functions.invoke(
            'supabase-functions-new-send-push-notification',
            body: {
              "user_id": receiverId,
              "title": senderName,
              "body": text.isNotEmpty ? text : "Shared a $mediaType",
              "data": {
                "type": "chat_message",
                "conversation_id": conversationId,
                "sender_id": user.id,
                "receiver_id": receiverId,
                "sender_name": senderName,
                "avatar_url": senderAvatar
              }
            },
            headers: {
              "Authorization": "Bearer $accessToken",
            },
          );
        }
      } catch (e) {
        debugPrint("Chat push failed: $e");
      }

    } catch (e) {
      debugPrint("Failed to update unread or send notification: $e");
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      await _supabase
          .from('messages')
          .update({'status': 'read'})
          .eq('conversation_id', conversationId)
          .neq('sender_id', user.id)
          .neq('status', 'read');

      await _supabase
          .from('conversation_members')
          .update({'unread_count': 0})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('conversation_members')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', user.id);
  }
}

final chatService = ChatService();
