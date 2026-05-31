import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_companion.dart';
import '../models/ai_message.dart';
import '../models/ai_memory.dart';

class AiCompanionRepository {
  final _supabase = Supabase.instance.client;

  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'companion_avatars/$userId/$fileName';

      await _supabase.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  Future<AiCompanion?> getCompanion() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('ai_companions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AiCompanion.fromMap(response);
  }

  Future<AiCompanion> createCompanion(Map<String, dynamic> companionData) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Prevent duplicate creation
    final existing = await getCompanion();
    if (existing != null) return existing;

    companionData['user_id'] = userId;
    
    final response = await _supabase
        .from('ai_companions')
        .insert(companionData)
        .select()
        .single();

    return AiCompanion.fromMap(response);
  }

  Future<bool> canSendAiMessage() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    
    // Check daily limit and boosters via RPC
    final bool canSend = await _supabase.rpc('can_send_ai_message', params: {'uid': userId});
    return canSend;
  }

  Future<void> registerAiUsage() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // We now use an atomic RPC that handles the logic:
    // 1. If daily limit not reached -> increment ai_messages_today
    // 2. Else -> consume from oldest valid booster
    await _supabase.rpc('register_ai_usage_atomic', params: {'uid': userId});
  }

  Future<int> getRemainingAiMessages() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    
    final int remaining = await _supabase.rpc('get_remaining_ai_messages', params: {'uid': userId});
    return remaining;
  }

  Future<List<AiMessage>> getMessages(String companionId) async {
    final response = await _supabase
        .from('ai_messages')
        .select()
        .eq('companion_id', companionId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List).map((m) => AiMessage.fromMap(m)).toList().reversed.toList();
  }

  Future<void> saveMessage({
    required String companionId,
    required String message,
    required String sender,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('ai_messages').insert({
      'user_id': userId,
      'companion_id': companionId,
      'message': message,
      'sender': sender,
    });

    if (sender == 'user') {
      await _incrementMessageCount(companionId);
    }
  }

  Future<void> _incrementMessageCount(String companionId) async {
    // This is handled via Supabase RPC or just updating the count
    // Given the prompt, we should increment it and the trigger will handle the reset if date changed
    final companion = await getCompanion();
    if (companion != null) {
      await _supabase
          .from('ai_companions')
          .update({'daily_message_count': companion.dailyMessageCount + 1})
          .eq('id', companionId);
    }
  }

  Future<List<AiMemory>> getMemories(String companionId) async {
    final response = await _supabase
        .from('ai_memories')
        .select()
        .eq('companion_id', companionId);

    return (response as List).map((m) => AiMemory.fromMap(m)).toList();
  }

  Future<void> saveMemory(String companionId, String key, String value) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('ai_memories').upsert({
      'user_id': userId,
      'companion_id': companionId,
      'memory_key': key,
      'memory_value': value,
    }, onConflict: 'user_id, companion_id, memory_key');
  }

  Future<AiCompanion> updateCompanion(String id, Map<String, dynamic> companionData) async {
    final response = await _supabase
        .from('ai_companions')
        .update(companionData)
        .eq('id', id)
        .select()
        .single();

    return AiCompanion.fromMap(response);
  }

  Future<void> deleteCompanion(String id) async {
    final companion = await _supabase
        .from('ai_companions')
        .select('avatar_url')
        .eq('id', id)
        .single();

    // 1. Delete messages (handled by cascade in SQL if set, but good to be explicit if not)
    await _supabase.from('ai_messages').delete().eq('companion_id', id);
    
    // 2. Delete memories
    await _supabase.from('ai_memories').delete().eq('companion_id', id);

    // 3. Delete avatar from storage if exists
    final avatarUrl = companion['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(avatarUrl);
        final path = uri.pathSegments.sublist(uri.pathSegments.indexOf('avatars') + 1).join('/');
        await _supabase.storage.from('avatars').remove([path]);
      } catch (e) {
        print('Error deleting avatar from storage: $e');
      }
    }

    // 4. Delete companion
    await _supabase.from('ai_companions').delete().eq('id', id);
  }
}
