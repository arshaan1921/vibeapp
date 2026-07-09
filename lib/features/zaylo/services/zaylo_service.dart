import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ZayloService {
  static final ZayloService _instance = ZayloService._internal();
  factory ZayloService() => _instance;
  ZayloService._internal();

  final _supabase = Supabase.instance.client;
  String? _currentMatchId;
  String? _remoteUserId;

  String? get currentMatchId => _currentMatchId;
  String? get remoteUserId => _remoteUserId;

  Future<void> joinZayloQueue() async {
    debugPrint('ZAYLO: Calling join_zaylo_queue RPC');
    try {
      await _supabase.rpc('join_zaylo_queue');
    } catch (e) {
      debugPrint('ZAYLO: Error joining queue: $e');
    }
  }

  Future<void> leaveZayloQueue() async {
    debugPrint('ZAYLO: Calling leave_zaylo_queue RPC');
    try {
      await _supabase.rpc('leave_zaylo_queue');
    } catch (e) {
      debugPrint('ZAYLO: Error leaving queue: $e');
    }
  }

  Future<Map<String, dynamic>> findZayloMatch() async {
    try {
      debugPrint('ZAYLO: Calling find_zaylo_match RPC');
      final response = await _supabase.rpc('find_zaylo_match');
      final result = Map<String, dynamic>.from(response);
      
      debugPrint('ZAYLO: find_zaylo_match result: $result');
      
      if (result['matched'] == true && result['match_id'] != null) {
        _currentMatchId = result['match_id'];
        _remoteUserId = result['remote_user_id'];
      } else {
        _currentMatchId = null;
        _remoteUserId = null;
      }

      return result;
    } catch (e) {
      debugPrint('ZAYLO: RPC Error: $e');
      return {'matched': false};
    }
  }

  Future<void> endZayloMatch(String matchId) async {
    try {
      await _supabase.rpc('end_zaylo_match', params: {'match_uuid': matchId});
      _currentMatchId = null;
      _remoteUserId = null;
    } catch (e) {
      debugPrint('ZAYLO: Error ending match: $e');
    }
  }

  Future<Map<String, dynamic>> nextZayloMatch(String currentMatchId) async {
    try {
      final response = await _supabase.rpc('next_zaylo_match', params: {'current_match_uuid': currentMatchId});
      final result = Map<String, dynamic>.from(response);
      
      if (result['matched'] == true && result['match_id'] != null) {
        _currentMatchId = result['match_id'];
        _remoteUserId = result['remote_user_id'];
      }
      return result;
    } catch (e) {
      debugPrint('ZAYLO: Error getting next match: $e');
      return {'matched': false};
    }
  }

  Future<void> reportZayloUser(String matchId, String reason) async {
    try {
      await _supabase.rpc('report_zaylo_user', params: {
        'match_uuid': matchId,
        'report_reason': reason
      });
    } catch (e) {
      debugPrint('ZAYLO: Error reporting user: $e');
    }
  }

  // --- Settings & Preferences ---

  Future<Map<String, dynamic>?> getUserPreferences() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('zaylo_gender_preference, zaylo_country_preference, interests, country')
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      debugPrint('ZAYLO: Error fetching preferences: $e');
      return null;
    }
  }

  Future<void> updatePreference(String column, dynamic value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('profiles').update({column: value}).eq('id', user.id);
    } catch (e) {
      debugPrint('ZAYLO: Error updating $column: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('zaylo_blocks')
          .select('blocked_user_id, profiles!zaylo_blocks_blocked_user_id_fkey(username, avatar_url)')
          .eq('blocker_user_id', user.id);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ZAYLO: Error fetching blocked users: $e');
      return [];
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('zaylo_blocks')
          .delete()
          .eq('blocker_user_id', user.id)
          .eq('blocked_user_id', blockedUserId);
    } catch (e) {
      debugPrint('ZAYLO: Error unblocking user: $e');
      throw e;
    }
  }
}

final zayloService = ZayloService();
