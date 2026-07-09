import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/zaylo_widgets.dart';
import '../services/zaylo_service.dart';
import 'video_chat_screen.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with SingleTickerProviderStateMixin {
  Timer? _matchingTimer;
  late AnimationController _pulseController;
  bool _isNavigating = false;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _startMatchingLoop();
  }

  void _startMatchingLoop() {
    if (_matchingTimer != null) return;

    _matchingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isPolling || _isNavigating) return;
      
      _isPolling = true;
      debugPrint('ZAYLO: Poll started');
      
      try {
        final result = await zayloService.findZayloMatch();
        final bool isMatched = result['matched'] == true;
        final String? matchId = result['match_id'];
        
        // CRITICAL: Verify both matched=true AND match_id exists
        if (isMatched && matchId != null && mounted && !_isNavigating) {
          debugPrint('ZAYLO: Match confirmed with match_id: $matchId');
          _isNavigating = true;
          _matchingTimer?.cancel();
          
          debugPrint('ZAYLO: navigation triggered');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const VideoChatScreen()),
          );
        } else {
          if (isMatched && matchId == null) {
            debugPrint('ZAYLO: ERROR - Match reported true but match_id is null. Staying in Finding Someone screen.');
          } else if (!isMatched) {
            debugPrint('ZAYLO: No match yet. Staying on Finding Someone screen.');
          }
        }
      } catch (e) {
        debugPrint('ZAYLO: Poll error: $e');
      } finally {
        _isPolling = false;
      }
    });
  }

  @override
  void dispose() {
    _matchingTimer?.cancel();
    _pulseController.dispose();
    zayloService.leaveZayloQueue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ZayloColors.primaryGradient[0].withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                SizedBox(
                  width: 350,
                  height: 350,
                  child: _buildPulseCircle(),
                ),
                const SizedBox(height: 60),
                Text(
                  'Finding someone...',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Based on your interests',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(3, (index) {
              final double delay = index * 0.4;
              final double value = (_pulseController.value + delay) % 1.0;
              return Opacity(
                opacity: (1.0 - value) * 0.5,
                child: Container(
                  width: 150 + (200 * value),
                  height: 150 + (200 * value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ZayloColors.electricBlue,
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: ZayloColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZayloColors.primaryGradient[0].withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
          ],
        );
      },
    );
  }
}
