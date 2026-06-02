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
import 'services/block_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/reset_password_page.dart';
import 'services/iap_service.dart';
import 'widgets/update_popup.dart';
import 'services/update_service.dart';
import 'features/ai_companion/screens/ai_companion_screen.dart';

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

  // ✅ Modern System UI Style for Android 15 + Modern Theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Default to dark icons for light theme
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // 1. Check for Play Store updates (Priority)
        await UpdateService.checkUpdate(context);
        
        // 2. Show rebrand announcement if no store update was shown
        if (mounted) {
          await UpdatePopup.showIfNeeded(context);
        }
      } catch (e, st) {
        debugPrint('ERROR: $e');
        debugPrintStack(stackTrace: st);
      }
    });
  }

  final List<Widget> _screens = const [
    FeedScreen(),
    QuestionsScreen(),
    AiCompanionScreen(),
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
            body: SafeArea(
              top: false,
              child: IndexedStack(
                index: index,
                children: _screens,
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                onDestinationSelected: (i) {
                  tabIndexNotifier.value = i;
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: "Home",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.mark_chat_unread_outlined),
                    selectedIcon: Icon(Icons.mark_chat_unread_rounded),
                    label: "Questions",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: "AI",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bookmark_outline_rounded),
                    selectedIcon: Icon(Icons.bookmark_rounded),
                    label: "Saved",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: "Profile",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
