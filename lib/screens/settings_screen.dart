import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/legal_links.dart';
import 'auth/welcome.dart';
import 'edit_profile.dart';
import 'premium.dart';
import 'blocked_users_screen.dart';
import 'report_problem_screen.dart';
import 'booster_pack_screen.dart';
import 'streak_restore_screen.dart';
import 'delete_account_screen.dart';
import 'my_tickets_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _buildSection("Account", [
                    _buildSettingRow(Icons.person_outline_rounded, "Edit Profile", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    }),
                    _buildSettingRow(Icons.lock_outline_rounded, "Change Password", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                    }),
                  ]),
                  _buildSection("Privacy & Safety", [
                    _buildSettingRow(Icons.block_rounded, "Blocked Users", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
                    }),
                    _buildSettingRow(Icons.help_outline_rounded, "Help & Support", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
                    }),
                    _buildSettingRow(Icons.confirmation_num_outlined, "My Tickets", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
                    }),
                  ]),
                  _buildSection("Subscription", [
                    _buildSettingRow(Icons.star_outline_rounded, "Premium Plan", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    }),
                    _buildSettingRow(Icons.bolt_outlined, "Question Booster", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BoosterPackScreen()));
                    }),
                    _buildSettingRow(Icons.local_fire_department_outlined, "Streak Restore", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakRestoreScreen()));
                    }),
                  ]),
                  _buildSection("About", [
                    _buildSettingRow(Icons.description_outlined, "Terms of Service", LegalLinks.launchTermsConditions),
                    _buildSettingRow(Icons.privacy_tip_outlined, "Privacy Policy", LegalLinks.launchPrivacyPolicy),
                  ]),
                  _buildSection("Actions", [
                    _buildSettingRow(Icons.logout_rounded, "Log Out", _handleLogout, isDestructive: true),
                    _buildSettingRow(Icons.delete_forever_rounded, "Delete Account", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
                    }, isDestructive: true),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : theme.colorScheme.primary.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingRow(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 22, color: isDestructive ? Colors.redAccent : theme.iconTheme.color),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.redAccent : theme.textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isDestructive ? null : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      dense: true,
    );
  }

  Future<void> _handleLogout() async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
    }
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty || newPassword != _confirmPasswordController.text.trim()) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Update password error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _newPasswordController, decoration: const InputDecoration(labelText: "New Password"), obscureText: true),
            const SizedBox(height: 16),
            TextField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: "Confirm New Password"), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _isLoading ? null : _updatePassword, child: const Text("Update Password")),
          ],
        ),
      ),
    );
  }
}
