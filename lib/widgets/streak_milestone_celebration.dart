import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class StreakMilestoneCelebration extends StatefulWidget {
  final int milestone;
  final String friendName;
  final VoidCallback onDismiss;

  const StreakMilestoneCelebration({
    super.key,
    required this.milestone,
    required this.friendName,
    required this.onDismiss,
  });

  @override
  State<StreakMilestoneCelebration> createState() => _StreakMilestoneCelebrationState();
}

class _StreakMilestoneCelebrationState extends State<StreakMilestoneCelebration> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _titleController;
  late Animation<double> _titleScale;
  late AnimationController _fireController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
    
    HapticFeedback.heavyImpact();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleScale = CurvedAnimation(parent: _titleController, curve: Curves.elasticOut);
    _titleController.forward();

    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _titleController.dispose();
    _fireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
          ),
        ),
        child: Stack(
          children: [
            // Animated Flames Background Effect
            ...List.generate(5, (index) {
              return Positioned(
                bottom: -20,
                left: MediaQuery.of(context).size.width * (index / 4) - 50,
                child: AnimatedBuilder(
                  animation: _fireController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.3,
                      child: Transform.translate(
                        offset: Offset(0, -20 * _fireController.value),
                        child: Transform.scale(
                          scale: 1.0 + (0.2 * sin(_fireController.value * pi)),
                          child: const Icon(Icons.local_fire_department, size: 150, color: Colors.orangeAccent),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
                shouldLoop: false,
                colors: const [Colors.orange, Colors.yellow, Colors.white, Colors.red],
              ),
            ),

            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _titleScale,
                      child: const Text(
                        "🏆 CENTURY CLUB 🏆",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.orange, blurRadius: 20)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "You and ${widget.friendName} reached",
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Fire particle effect behind streak
                        AnimatedBuilder(
                          animation: _fireController,
                          builder: (context, child) {
                            return Container(
                              width: 200,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3 * _fireController.value),
                                    blurRadius: 40,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Text(
                          "${widget.milestone} DAYS 🔥",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.red, blurRadius: 10)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    const Text(
                      "Rewards Unlocked:",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("🏆", style: TextStyle(fontSize: 24)),
                          SizedBox(width: 12),
                          Text(
                            "Century Club Badge",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 10,
                          shadowColor: Colors.orange.withOpacity(0.5),
                        ),
                        child: const Text(
                          "AWESOME",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
