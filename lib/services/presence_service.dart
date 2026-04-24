import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(true);
    _startHeartbeat();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _setOnlineStatus(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _stopHeartbeat();
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      _setOnlineStatus(true);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static String formatLastSeen(DateTime? lastSeen, bool isOnline) {
    if (isOnline && lastSeen != null) {
      final difference = DateTime.now().difference(lastSeen);
      if (difference.inSeconds < 60) {
        return 'Online';
      }
    }

    if (lastSeen == null) return '';

    final now = DateTime.now();
    final localLastSeen = lastSeen.toLocal();
    final difference = now.difference(localLastSeen);

    if (now.year == localLastSeen.year &&
        now.month == localLastSeen.month &&
        now.day == localLastSeen.day) {
      final hour = localLastSeen.hour > 12 ? localLastSeen.hour - 12 : (localLastSeen.hour == 0 ? 12 : localLastSeen.hour);
      final minute = localLastSeen.minute.toString().padLeft(2, '0');
      final period = localLastSeen.hour >= 12 ? 'PM' : 'AM';
      return 'Last seen today at $hour:$minute $period';
    }

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (yesterday.year == localLastSeen.year &&
        yesterday.month == localLastSeen.month &&
        yesterday.day == localLastSeen.day) {
      return 'Last seen yesterday';
    }

    return 'Last seen ${localLastSeen.day}/${localLastSeen.month}/${localLastSeen.year}';
  }
}
