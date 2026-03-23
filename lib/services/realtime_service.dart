import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  // Stream controller to broadcast events to the UI
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  void startRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Use a single channel for all table changes
    _channel = _supabase.channel('realtime');

    // questions -> refresh inbox screen and badge
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'questions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'to_user',
        value: user.id,
      ),
      callback: (payload) {
        _eventController.add('refresh_inbox');
      },
    );

    // answers -> refresh profile answers
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'answers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) {
        _eventController.add('refresh_profile_answers');
      },
    );

    // answer_likes -> update like counters
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'answer_likes',
      callback: (payload) {
        _eventController.add('update_like_counters');
      },
    );

    // notifications -> update notification badge
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) {
        _eventController.add('update_notification_badge');
      },
    );

    // vibe_requests -> update vibe request badge
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vibe_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: user.id,
      ),
      callback: (payload) {
        _eventController.add('update_vibe_request_badge');
      },
    );

    _channel!.subscribe();
  }

  void stopRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
