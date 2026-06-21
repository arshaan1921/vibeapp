import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZayloSettingsScreen extends StatelessWidget {
  const ZayloSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Zaylo Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Preferences', isDark),
          _buildSettingTile(
            icon: Icons.person_outline_rounded,
            title: 'Gender Preference',
            trailing: 'Everyone',
            onTap: () {},
            isDark: isDark,
          ),
          _buildSettingTile(
            icon: Icons.public_rounded,
            title: 'Country Preference',
            trailing: 'Global',
            onTap: () {},
            isDark: isDark,
          ),
          _buildSettingTile(
            icon: Icons.interests_rounded,
            title: 'Manage Interests',
            onTap: () {},
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Safety', isDark),
          _buildSettingTile(
            icon: Icons.block_flipped,
            title: 'Blocked Users',
            onTap: () {},
            isDark: isDark,
          ),
          _buildSettingTile(
            icon: Icons.gavel_rounded,
            title: 'Community Guidelines',
            onTap: () {},
            isDark: isDark,
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Zaylo v1.0.0',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? trailing,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing,
                style: GoogleFonts.poppins(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
