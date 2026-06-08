import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'auth/welcome.dart';
import '../main.dart';
import '../services/realtime_service.dart';
import '../services/notification_service.dart';
import '../services/block_service.dart';

import '../services/safety_service.dart';

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
    // Increased delay to 2 seconds to ensure splash is seen
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      print("➡️ Navigating to WelcomeScreen");
      RealtimeService().stopRealtime();
      NotificationService.reset();
      safetyService.premiumPlan = null;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    } else {
      print("➡️ Navigating to MainScaffold");
      
      // Initialize SafetyService premium plan
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('premium_plan')
            .eq('id', session.user.id)
            .maybeSingle();
        if (profile != null) {
          safetyService.premiumPlan = profile['premium_plan'];
        }
      } catch (e, st) {
        debugPrint('ERROR: $e');
        debugPrintStack(stackTrace: st);
      }

      RealtimeService().startRealtime();
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
      backgroundColor: const Color(0xFFFEDC00), // Match yellow from image
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/splash.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if asset fails to load
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      children: const [
                        TextSpan(text: "HIGH"),
                        TextSpan(text: "5", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Snap. Ask. Connect.",
                    style: GoogleFonts.poppins(
                      color: Colors.black.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
