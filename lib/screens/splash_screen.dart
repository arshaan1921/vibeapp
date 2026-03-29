import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'auth/welcome.dart';
import '../main.dart';
import '../services/realtime_service.dart';
import '../services/notification_service.dart';
import '../services/block_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print("🚀 Splash started");

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
    _navigateToNext();
  }

  void _navigateToNext() async {
    print("🔍 Checking user/session...");
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      print("➡️ Navigating to WelcomeScreen");
      RealtimeService().stopRealtime();
      NotificationService.reset();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    } else {
      print("➡️ Navigating to MainScaffold");
      RealtimeService().startRealtime();
      NotificationService.initialize();
      blockService.refreshBlockedList();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScaffold()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C5D8C),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "V1BE",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Ask, Answer, Play",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
