import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme.dart';
import 'screens/feed.dart';
import 'screens/questions_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/profile.dart';
import 'screens/auth/welcome.dart';
import 'services/realtime_service.dart';
import 'services/notification_service.dart';
import 'features/games/games_screen.dart';
import 'services/rate_game_service.dart';
import 'services/block_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/reset_password_page.dart';

final ValueNotifier<int> tabIndexNotifier = ValueNotifier(0);

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'v1be_channel',
  'V1BE Notifications',
  description: 'Important notifications',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// ✅ Centralized Background Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification body is handled by the system if it contains a 'notification' payload.
  // Data-only messages in background should be handled here if needed, 
  // but we avoid manual show() to prevent duplicates.
  debugPrint("📩 Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Background handler registration
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await Supabase.initialize(
    url: "https://litammrxzsndissedizt.supabase.co",
    anonKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpdGFtbXJ4enNuZGlzc2VkaXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MzE1MzIsImV4cCI6MjA4NzUwNzUzMn0._MqAAWpExMvi0vMHFhegqmx_gDPiJZWtUIbjJKvzfoQ",
  );

  /// 🔥 PASSWORD RECOVERY LISTENER
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      NotificationService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ResetPasswordPage(),
        ),
      );
    }
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const V1beApp());
}

class V1beApp extends StatelessWidget {
  const V1beApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V1BE',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  DateTime? _lastBackPressed;
  final _gameService = RateGameService();

  final List<Widget> _screens = const [
    FeedScreen(),
    QuestionsScreen(),
    GamesScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: tabIndexNotifier,
      builder: (context, index, _) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;

            if (index != 0) {
              tabIndexNotifier.value = 0;
              return;
            }

            final now = DateTime.now();
            if (_lastBackPressed == null ||
                now.difference(_lastBackPressed!) >
                    const Duration(seconds: 2)) {
              _lastBackPressed = now;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Press back again to exit"),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            SystemNavigator.pop();
          },
          child: Scaffold(
            body: IndexedStack(
              index: index,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) {
                tabIndexNotifier.value = i;
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: isDark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).primaryColor,
              selectedItemColor:
              isDark ? Colors.blueAccent : const Color(0xFF9FD3FF),
              unselectedItemColor:
              isDark ? Colors.grey : Colors.white54,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: "Home",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.question_answer_rounded),
                  label: "Questions",
                ),
                BottomNavigationBarItem(
                  icon: StreamBuilder<int>(
                    stream: _gameService.streamUnseenGamesCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 9 ? '9+' : count.toString()),
                        child: const Icon(Icons.sports_esports_rounded),
                      );
                    },
                  ),
                  label: "Games",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark),
                  label: "Saved",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: "Profile",
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
