import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/zaylo_widgets.dart';
import 'matching_screen.dart';
import 'zaylo_settings_screen.dart';

class ZayloHomeScreen extends StatefulWidget {
  const ZayloHomeScreen({super.key});

  @override
  State<ZayloHomeScreen> createState() => _ZayloHomeScreenState();
}

class _ZayloHomeScreenState extends State<ZayloHomeScreen> {
  final List<String> _allInterests = [
    'Gaming', 'Anime', 'Movies', 'Music', 'Travel',
    'Sports', 'Fitness', 'Technology', 'Food', 'Fashion'
  ];
  final Set<String> _selectedInterests = {};

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zaylo',
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: ZayloColors.primaryGradient,
                            ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                        ),
                      ),
                      Text(
                        'Meet someone new instantly.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ZayloSettingsScreen()),
                    ),
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildOnlineCounter(isDark),
              const SizedBox(height: 40),
              Text(
                'Your Interests',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _allInterests.map((interest) {
                  return ZayloInterestChip(
                    label: interest,
                    isSelected: _selectedInterests.contains(interest),
                    onTap: () => _toggleInterest(interest),
                  );
                }).toList(),
              ),
              const SizedBox(height: 50),
              ZayloGradientButton(
                text: 'Start Matching',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MatchingScreen()),
                ),
              ),
              const SizedBox(height: 40),
              _buildSafetyCard(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineCounter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            '12,547 Online',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ZayloColors.electricBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.greenAccent),
              const SizedBox(width: 12),
              Text(
                'Stay Safe',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _safetyItem('Be respectful'),
          _safetyItem('No harassment'),
          _safetyItem('Report inappropriate behavior'),
          _safetyItem('Follow community guidelines'),
        ],
      ),
    );
  }

  Widget _safetyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
