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

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
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
        style: GoogleFonts.poppins(fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          // Remote Video Placeholder
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF880E4F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 100, color: Colors.white24),
                    const SizedBox(height: 20),
                    Text(
                      'Matching you with Alex, 21',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Self Preview
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _isCameraOn
                    ? Stack(
                        children: [
                          Container(color: Colors.grey[900]),
                          const Center(
                            child: Icon(Icons.person, color: Colors.white38),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Text(
                              'You',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white38),
                      ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  color: _isMicOn ? Colors.white24 : Colors.redAccent,
                  onTap: () => setState(() => _isMicOn = !_isMicOn),
                ),
                _controlButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  color: _isCameraOn ? Colors.white24 : Colors.redAccent,
                  onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                ),
                _controlButton(
                  icon: Icons.navigate_next,
                  color: ZayloColors.electricBlue,
                  isLarge: true,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MatchingScreen()),
                    );
                  },
                ),
                _controlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onTap: () => Navigator.pop(context),
                ),
                _controlButton(
                  icon: Icons.report_problem_outlined,
                  color: Colors.white12,
                  onTap: _showReportDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLarge ? 70 : 55,
        height: isLarge ? 70 : 55,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            if (isLarge)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isLarge ? 35 : 25,
        ),
      ),
    );
  }
}
