import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../screens/profile.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔵 Background message: ${message.messageId}");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _lastToken;

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  // ==============================
  // 🔥 INIT
  // ==============================
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    final settings = await messaging.requestPermission();
    debugPrint("🔐 Permission: ${settings.authorizationStatus}");

    const androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidInit);

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final data = jsonDecode(details.payload!);
          _handleNavigation(data);
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'v1be_channel',
      'V1BE Notifications',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await setupToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint("🔄 Token refreshed: $token");
      saveTokenToSupabase(token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("📩 Foreground message: ${message.data}");

      final title =
          message.notification?.title ?? message.data['title'] ?? 'New Message';
      final body =
          message.notification?.body ?? message.data['body'] ?? '';

      showNotification(title, body, payload: message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint("👆 Click (background): ${message.data}");
      _handleNavigation(message.data);
    });

    final initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint("🚀 Opened from terminated: ${initialMessage.data}");
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNavigation(initialMessage.data);
      });
    }
  }

  // ==============================
  // 🔥 NAVIGATION
  // ==============================
  static void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint("➡️ Navigate type: $type");

    if (type == 'question') {
      tabIndexNotifier.value = 1;

    } else if (type == 'like') {
      tabIndexNotifier.value = 0;

    } else if (type == 'vibe' || type == 'profile_save') {
      final userId = data['user_id'];

      if (userId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: userId),
          ),
        );
      } else {
        tabIndexNotifier.value = 4;
      }
    }
  }

  // ==============================
  // 🔥 TOKEN
  // ==============================
  static Future<void> setupToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      debugPrint("📱 FCM TOKEN: $token");

      if (token != null) {
        await saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint("❌ Token error: $e");
    }
  }

  static Future<void> saveTokenToSupabase(String token) async {
    if (_lastToken == token) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint("❌ No user logged in");
      return;
    }

    debugPrint("💾 Saving token for user: ${user.id}");

    await supabase.from('device_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
      },
      onConflict: 'user_id,token',
    );

    _lastToken = token;
  }

  // ==============================
  // 🔥 LOCAL NOTIFICATION
  // ==============================
  static Future<void> showNotification(
      String title,
      String body, {
        Map<String, dynamic>? payload,
      }) async {
    const androidDetails = AndroidNotificationDetails(
      'v1be_channel',
      'V1BE Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ==============================
  // 🔥 SEND CORE (FIXED)
  // ==============================
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint("🚀 Sending notification...");
      debugPrint("➡️ user_id: $userId");

      final res = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint("✅ RESPONSE: ${res.data}");

    } catch (e) {
      debugPrint("🔥 ERROR: $e");
    }
  }

  // ==============================
  // 🔥 TYPES
  // ==============================
  static Future<void> sendLikeNotification({
    required String receiverUserId,
    required String senderUserId,
    required String answerId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: "New Like ❤️",
      body: "Someone liked your answer",
      data: {
        "type": "like",
        "user_id": senderUserId,
        "answer_id": answerId,
      },
    );
  }

  static Future<void> sendQuestionNotification({
    required String receiverUserId,
    required String senderUserId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: "New Question ❓",
      body: "Someone asked you a question",
      data: {
        "type": "question",
        "user_id": senderUserId,
      },
    );
  }

  static Future<void> sendVibeNotification({
    required String receiverUserId,
    required String senderUserId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: "New Vibe 🔥",
      body: "Someone saved your profile",
      data: {
        "type": "vibe",
        "user_id": senderUserId,
      },
    );
  }

  static void reset() {
    _isInitialized = false;
    _lastToken = null;
  }
}