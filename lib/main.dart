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
import 'services/iap_service.dart';
import 'widgets/update_popup.dart';
import 'services/update_service.dart';

final ValueNotifier<int> tabIndexNotifier = ValueNotifier(0);
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high5_channel',
  'High5 Notifications',
  description: 'Important notifications',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// ✅ Correctly placed top-level background handler
@pragma('vm:entry-point')
Future<void> notificationServiceBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is ready in the background isolate
  await Firebase.initializeApp();
  debugPrint("📩 Background message received: ${message.messageId}");
  // Data-only messages are handled here. If the message contains a notification object,
  // FCM will display it automatically.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Enable Edge-to-Edge for Android 15+
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp();
  debugPrint("🔥 Firebase initialized in main");

  // Background handler registration - MUST be here and MUST be top-level
  FirebaseMessaging.onBackgroundMessage(notificationServiceBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await Supabase.initialize(
    url: "https://litammrxzsndissedizt.supabase.co",
    anonKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpdGFtbXJ4enNuZGlzc2VkaXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MzE1MzIsImV4cCI6MjA4NzUwNzUzMn0._MqAAWpExMvi0vMHFhegqmx_gDPiJZWtUIbjJKvzfoQ",
  );
  debugPrint("🟢 Supabase initialized");

  // ✅ Initialize Notifications immediately after Supabase
  await NotificationService.initialize();

  // Initialize In-App Purchases
  IAPService().initialize();

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

  // ✅ Modern System UI Style for Android 15 + Dark Green Theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons for dark green background
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const High5App());
}

class High5App extends StatelessWidget {
  const High5App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'High5',
      navigatorKey: NotificationService.navigatorKey,
      navigatorObservers: [routeObserver],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Check for Play Store updates (Priority)
      await UpdateService.checkUpdate(context);
      
      // 2. Show rebrand announcement if no store update was shown
      if (mounted) {
        await UpdatePopup.showIfNeeded(context);
      }
    });
  }

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
            // ✅ Use SafeArea to prevent overlap with navigation bar
            body: SafeArea(
              top: false, // Top bar already handles its own SafeArea
              child: IndexedStack(
                index: index,
                children: _screens,
              ),
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
              selectedItemColor: const Color(0xFFFFD700),
              unselectedItemColor: Colors.white.withOpacity(0.7),
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
