import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/zaylo_widgets.dart';
import 'matching_screen.dart';

class VideoChatScreen extends StatefulWidget {
  const VideoChatScreen({super.key});

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  bool _isMicOn = true;
  bool _isCameraOn = true;
  String _status = 'Connecting...';

  @override
  void initState() {
    super.initState();
    // Simulate connection phase
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _status = '⚡ Connected';
        });
      }
    });
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Report User',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            _reportOption('Spam'),
            _reportOption('Harassment'),
            _reportOption('Inappropriate Content'),
            _reportOption('Fake User'),
            _reportOption('Other'),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _reportOption(String title) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for keeping Zaylo safe!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 50/50 Split Screen Layout
          Column(
            children: [
              // Top 50%: Stranger
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Stack(
                    children: [
                      // Placeholder for stranger video
                      const Center(
                        child: Icon(Icons.person, size: 80, color: Colors.white12),
                      ),
                      _buildLabel('Stranger'),
                    ],
                  ),
                ),
              ),
              // Bottom 50%: You
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Stack(
                    children: [
                      // Placeholder for self video
                      if (_isCameraOn)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      const Center(
                        child: Icon(Icons.person, size: 60, color: Colors.white12),
                      ),
                      if (!_isCameraOn)
                        const Center(
                          child: Icon(Icons.videocam_off, color: Colors.white38),
                        ),
                      _buildLabel('You'),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Status Pill - Exactly in the middle
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _status.contains('Connected') ? Colors.greenAccent : Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Controls - Overlaid on the bottom section
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _glassButton(
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  onTap: () => setState(() => _isMicOn = !_isMicOn),
                  isActive: _isMicOn,
                ),
                _glassButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                  isActive: _isCameraOn,
                ),
                // Next Button (Largest)
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MatchingScreen()),
                    );
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: ZayloColors.electricBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ZayloColors.electricBlue.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.black87, size: 35),
                  ),
                ),
                _glassButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                  color: Colors.redAccent,
                ),
                _glassButton(
                  icon: Icons.flag_outlined,
                  onTap: _showReportDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Positioned(
      top: 15,
      left: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color?.withOpacity(0.2) ?? (isActive ? Colors.white12 : Colors.redAccent.withOpacity(0.2)),
              shape: BoxShape.circle,
              border: Border.all(
                color: color?.withOpacity(0.3) ?? (isActive ? Colors.white24 : Colors.redAccent.withOpacity(0.3)),
              ),
            ),
            child: Icon(
              icon,
              color: color ?? (isActive ? Colors.white : Colors.redAccent),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
