import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../screens/profile.dart';
import '../screens/inbox.dart';
import '../screens/questions_screen.dart';
import '../screens/answer_detail_screen.dart';
import '../screens/my_tickets_screen.dart';
import '../features/games/games_screen.dart';
import '../screens/friend_requests_screen.dart';
import 'update_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _lastToken;
  static String? _cachedToken; // To store token if user is not yet logged in
  static StreamSubscription<AuthState>? _authSubscription;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ==============================
  // 🔥 INIT
  // ==============================
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint("🔔 NotificationService already initialized. Checking token...");
      await setupToken(); // Ensure we have latest token
      return;
    }
    
    _isInitialized = true;
    debugPrint("🔔 Initializing NotificationService (First Time)...");

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Request permissions
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint("🔐 Notification Permission Result: ${settings.authorizationStatus}");

    // 2. Local Notification Setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("👆 Local notification clicked: ${details.payload}");
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _handleNavigation(data);
          } catch (e) {
            debugPrint("❌ Error parsing notification payload: $e");
          }
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'high5_channel',
      'High5 Notifications',
      description: 'Important notifications for High5',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Setup Listeners
    
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint("🔄 FCM Token refreshed: $token");
      _cachedToken = token;
      saveTokenToSupabase(token);
    });

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground message received: ${message.messageId}");
      final title = message.notification?.title ?? message.data['title'] ?? 'High5';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      showNotification(title, body, payload: message.data);
    });

    // Background click listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("👆 Notification clicked (Background): ${message.data}");
      _handleNavigation(message.data);
    });

    // Terminated state click listener
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("🚀 App opened from terminated state: ${message.data}");
        // Wait slightly longer than splash screen (1000ms) to ensure navigation persists
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNavigation(message.data);
        });
      }
    });

    // 4. 🔥 AUTH LISTENER: Critical for saving token after login
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final user = data.session?.user;
      
      debugPrint("🔐 NotificationService: Auth Event - $event");

      if (user != null && 
          (event == AuthChangeEvent.signedIn || 
           event == AuthChangeEvent.initialSession || 
           event == AuthChangeEvent.tokenRefreshed)) {
        
        debugPrint("👤 User session active ($event), retrying token save...");
        if (_cachedToken != null) {
          saveTokenToSupabase(_cachedToken!);
        } else {
          setupToken();
        }
      }
    });

    // 5. Initial token fetch
    await setupToken();

    // Topic subscription
    FirebaseMessaging.instance.subscribeToTopic('high5_updates').then((_) {
      debugPrint("✅ Subscribed to high5_updates topic");
    }).catchError((e) {
      debugPrint("❌ Topic subscription error: $e");
      return null;
    });
  }

  // ==============================
  // 🔥 NAVIGATION
  // ==============================
  static void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final String? answerId = data['answer_id']?.toString();
    debugPrint("➡️ Navigating for type: $type");

    if (type == 'support_ticket') {
      debugPrint("🎫 Support ticket tapped");
      debugPrint("➡️ Opening MyTicketsScreen");
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
      );
    } else if (type == 'question') {
      debugPrint("📥 Question notification tapped");
      debugPrint("➡️ Opening Questions tab (Inbox)");
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const QuestionsScreen()));
    } else if (type == 'answer') {
      debugPrint("💬 Answer notification tapped");
      if (answerId != null) {
        debugPrint("➡️ Opening AnswerDetailScreen");
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AnswerDetailScreen(answerId: answerId)),
        );
      }
    } else if (type == 'reply' || type == 'answer_reply') {
      debugPrint("💬 Reply notification tapped");
      if (answerId != null) {
        debugPrint("➡️ Opening AnswerDetailScreen");
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AnswerDetailScreen(answerId: answerId)),
        );
      }
    } else if (type == 'like') {
      debugPrint("❤️ Like notification tapped");
      if (answerId != null) {
        debugPrint("➡️ Opening AnswerDetailScreen");
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AnswerDetailScreen(answerId: answerId)),
        );
      }
    } else if (type == 'daily_question') {
      debugPrint("🌙 Daily question tapped");
      debugPrint("➡️ Opening Questions tab (Inbox)");
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const QuestionsScreen()));
    } else if (type == 'update') {
      UpdateService.openPlayStore();
    } else if (type == 'vibe' || type == 'profile_save') {
      final userId = data['user_id'];
      if (userId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
        );
      } else {
        tabIndexNotifier.value = 4;
      }
    } else if (type == 'game') {
      debugPrint("🎮 Game notification tapped");
      debugPrint("➡️ Opening GamesScreen");
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const GamesScreen()),
      );
    } else if (type == 'friend_request') {
      debugPrint("👥 Friend request notification tapped");
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
      );
    } else if (type == 'friend_accepted' || type == 'snap') {
      debugPrint("👻 Friend accepted/Snap notification tapped");
      tabIndexNotifier.value = 3; // Navigate to SnapChats tab
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  static Future<void> sendGameNotification({
    required String targetUserId,
    required String creatorUsername,
  }) async {
    await sendNotification(
      userId: targetUserId,
      title: "New Game! 🎮",
      body: "@$creatorUsername started a new game with you",
      data: {"type": "game"},
    );
  }

  // ==============================
  // 🔥 TOKEN MANAGEMENT
  // ==============================
  static Future<void> setupToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint("📱 Current FCM TOKEN: $token");

      if (token != null) {
        _cachedToken = token;
        await saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint("❌ FCM Token retrieval error: $e");
    }
  }

  static Future<void> saveTokenToSupabase(String token) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint("⚠️ Cannot save token: No user logged in. Token cached.");
      _cachedToken = token;
      return;
    }

    if (_lastToken == token) {
      debugPrint("ℹ️ Token already saved for this session. Skipping.");
      return;
    }

    try {
      debugPrint("💾 Saving token to Supabase for user: ${user.id}");
      
      await supabase.from('device_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      
      debugPrint("✅ Token saved successfully to Supabase");
      _lastToken = token;
      _cachedToken = null; // Clear cache after successful save
    } catch (e) {
      debugPrint("❌ Error saving token to Supabase: $e");
    }
  }

  // ==============================
  // 🔥 DISPLAY NOTIFICATION
  // ==============================
  static Future<void> showNotification(
    String title,
    String body, {
    Map<String, dynamic>? payload,
  }) async {
    debugPrint("🔔 Showing local notification: $title");
    
    const androidDetails = AndroidNotificationDetails(
      'high5_channel',
      'High5 Notifications',
      channelDescription: 'Notifications for questions, likes, and social updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
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
  // 🔥 EDGE FUNCTION INVOCATION
  // ==============================
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint("🚀 Invoking Edge Function for user_id: $userId");

      final res = await supabase.functions.invoke(
        'supabase-functions-new-send-push-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint("✅ Edge Function Result: ${res.data}");
    } catch (e) {
      debugPrint("🔥 Edge Function Invocation Error: $e");
    }
  }

  static Future<void> sendTestNotification() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    debugPrint("🧪 Sending TEST notification to self...");
    await sendNotification(
      userId: user.id,
      title: "Test Notification 🚀",
      body: "If you see this, push notifications are working correctly!",
      data: {"type": "test"},
    );
  }

  static void reset() {
    debugPrint("🔄 Resetting NotificationService session state");
    _lastToken = null;
    _cachedToken = null;
    // We keep _isInitialized = true and keep listeners active
    // so they can handle the next login event.
  }
}
