import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _mainChannel;

  // Stream controller to broadcast events to the UI
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  void startRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Use a single channel for all table changes
    _mainChannel = _supabase.channel('public:realtime');

    // questions -> refresh inbox screen and badge
    _mainChannel!.onPostgresChanges(
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
    _mainChannel!.onPostgresChanges(
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
    _mainChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'answer_likes',
      callback: (payload) {
        _eventController.add('update_like_counters');
      },
    );

    // notifications -> update notification badge
    _mainChannel!.onPostgresChanges(
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
    _mainChannel!.onPostgresChanges(
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

    _mainChannel!.subscribe();
  }

  void stopRealtime() {
    _mainChannel?.unsubscribe();
    _mainChannel = null;
  }

  Stream<AppUser?> getUserPresenceStream(String userId) {
    StreamController<AppUser?> controller = StreamController<AppUser?>();
    RealtimeChannel? channel;
    
    // Initial fetch
    _supabase.from('profiles').select().eq('id', userId).maybeSingle().then((data) {
      if (data != null && !controller.isClosed) {
        controller.add(AppUser.fromJson(data));
      }
    }).catchError((e) => debugPrint('Error fetching user presence: $e'));

    // Subscribe to changes for this specific user only
    channel = _supabase.channel('presence:$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) {
        if (payload.newRecord != null && !controller.isClosed) {
          controller.add(AppUser.fromJson(payload.newRecord));
        }
      },
    ).subscribe();

    controller.onCancel = () {
      channel?.unsubscribe();
      if (!controller.isClosed) {
        controller.close();
      }
    };

    return controller.stream;
  }
}
