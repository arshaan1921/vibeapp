import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdatePopup extends StatefulWidget {
  const UpdatePopup({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('show_high5_rename_popup_v1') ?? false;
    
    if (!hasShown && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const UpdatePopup(),
      );
    }
  }

  @override
  State<UpdatePopup> createState() => _UpdatePopupState();
}

class _UpdatePopupState extends State<UpdatePopup> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _mascotController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _mascotController.dispose();
    super.dispose();
  }

  Future<void> _markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_high5_rename_popup_v1', true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: size.height * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A3321),
                    Color(0xFF144D3A),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Celebration Sparkles
                  ...List.generate(5, (index) => Positioned(
                    top: 20.0 + (index * 40),
                    left: index % 2 == 0 ? 20 : null,
                    right: index % 2 != 0 ? 20 : null,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        size: 24,
                      ),
                    ),
                  )),

                  SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _mascotController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, 8 * (0.5 - (0.5 - _mascotController.value).abs())),
                              child: child,
                            );
                          },
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: const DecorationImage(
                                image: AssetImage('assets/app_icon.png'),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.3),
                                  blurRadius: 25,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        Text(
                          "Welcome to HIGH5",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "HIGH5 is your space to ask, answer, and connect with your vibe.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Join the social network where every interaction matters — not just endless scrolling.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _markAsShown,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: const Color(0xFF0A3321),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0xFFFFD700).withOpacity(0.4),
                            ),
                            child: Text(
                              "Explore HIGH5",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
