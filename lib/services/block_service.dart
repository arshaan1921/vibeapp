import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  final _supabase = Supabase.instance.client;
  List<String> _blockedIds = [];
  
  List<String> get blockedIds => _blockedIds;

  final ValueNotifier<List<String>> blockedIdsNotifier = ValueNotifier<List<String>>([]);

  Future<void> refreshBlockedList() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _blockedIds = [];
        blockedIdsNotifier.value = [];
        return;
      }

      // Users I blocked
      final blockedByMeResponse = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);
      
      final blockedByMe = (blockedByMeResponse as List)
          .map((e) => e['blocked_id'] as String)
          .toList();

      // Users who blocked me
      final blockingMeResponse = await _supabase
          .from('blocked_users')
          .select('blocker_id')
          .eq('blocked_id', userId);
      
      final blockingMe = (blockingMeResponse as List)
          .map((e) => e['blocker_id'] as String)
          .toList();

      _blockedIds = {...blockedByMe, ...blockingMe}.toList();
      blockedIdsNotifier.value = _blockedIds;
    } catch (e) {
      debugPrint("Error refreshing blocked list: $e");
    }
  }

  bool isBlocked(String userId) {
    return _blockedIds.contains(userId);
  }

  Future<void> blockUser(String targetUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('blocked_users').upsert({
      'blocker_id': userId,
      'blocked_id': targetUserId,
    });
    await refreshBlockedList();
  }

  Future<void> unblockUser(String targetUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('blocked_users').delete().match({
      'blocker_id': userId,
      'blocked_id': targetUserId,
    });
    await refreshBlockedList();
  }
}

final blockService = BlockService();
