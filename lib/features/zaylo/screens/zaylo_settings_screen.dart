import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/zaylo_service.dart';
import 'zaylo_blocked_users_screen.dart';
import 'zaylo_community_guidelines_screen.dart';
import 'zaylo_interests_screen.dart';

class ZayloSettingsScreen extends StatefulWidget {
  const ZayloSettingsScreen({super.key});

  @override
  State<ZayloSettingsScreen> createState() => _ZayloSettingsScreenState();
}

class _ZayloSettingsScreenState extends State<ZayloSettingsScreen> {
  bool _isLoading = true;
  String _genderPreference = 'Everyone';
  String _countryPreference = 'Global';
  List<String> _interests = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    final prefs = await zayloService.getUserPreferences();
    if (mounted && prefs != null) {
      setState(() {
        _genderPreference = prefs['zaylo_gender_preference'] ?? 'Everyone';
        _countryPreference = prefs['zaylo_country_preference'] ?? 'Global';
        _interests = List<String>.from(prefs['interests'] ?? []);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePreference(String column, dynamic value, String displayValue) async {
    try {
      await zayloService.updatePreference(column, value);
      if (mounted) {
        setState(() {
          if (column == 'zaylo_gender_preference') _genderPreference = value;
          if (column == 'zaylo_country_preference') _countryPreference = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences Updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: 'Gender Preference',
        options: ['Everyone', 'Male', 'Female'],
        currentValue: _genderPreference,
        onSelected: (val) => _updatePreference('zaylo_gender_preference', val, val),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: 'Country Preference',
        options: ['Global', 'Same Country'],
        currentValue: _countryPreference,
        onSelected: (val) => _updatePreference('zaylo_country_preference', val, val),
      ),
    );
  }

  Widget _buildPickerSheet({
    required String title,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ...options.map((option) => ListTile(
                title: Text(option, style: GoogleFonts.poppins(fontSize: 16)),
                trailing: currentValue == option ? const Icon(Icons.check_circle_rounded, color: Colors.purpleAccent) : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(option);
                },
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader('Preferences', isDark),
                _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Gender Preference',
                  trailing: _genderPreference,
                  onTap: _showGenderPicker,
                  isDark: isDark,
                ),
                _buildSettingTile(
                  icon: Icons.public_rounded,
                  title: 'Country Preference',
                  trailing: _countryPreference,
                  onTap: _showCountryPicker,
                  isDark: isDark,
                ),
                _buildSettingTile(
                  icon: Icons.interests_rounded,
                  title: 'Manage Interests',
                  trailing: '${_interests.length}/10',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ZayloInterestsScreen(initialInterests: _interests),
                      ),
                    );
                    _loadPreferences();
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Safety', isDark),
                _buildSettingTile(
                  icon: Icons.block_flipped,
                  title: 'Blocked Users',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ZayloBlockedUsersScreen()),
                  ),
                  isDark: isDark,
                ),
                _buildSettingTile(
                  icon: Icons.gavel_rounded,
                  title: 'Community Guidelines',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ZayloCommunityGuidelinesScreen()),
                  ),
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
