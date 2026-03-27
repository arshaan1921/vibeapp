import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/legal_links.dart';
import 'auth/welcome.dart';
import 'edit_profile.dart';
import 'premium.dart';
import 'blocked_users_screen.dart';
import 'report_problem_screen.dart';
import 'booster_pack_screen.dart';
import 'delete_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Just verifying session/user exists since we removed toggle states
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "SETTINGS",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  children: [
                    _buildSectionTitle("ACCOUNT"),
                    Card(
                      child: Column(
                        children: [
                          _buildRow(Icons.person_outline, "Edit Profile", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            ).then((updated) {
                              if (updated == true) _fetchSettings();
                            });
                          }),
                          const Divider(),
                          _buildRow(Icons.lock_outline, "Change Password", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle("PRIVACY"),
                    Card(
                      child: Column(
                        children: [
                          _buildRow(Icons.block_outlined, "Blocked users", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                            );
                          }),
                          const Divider(),
                          _buildRow(Icons.report_problem_outlined, "Help & Support", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ReportProblemScreen()),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle("PREMIUM"),
                    Card(
                      child: Column(
                        children: [
                          _buildRow(Icons.star_outline, "Premium Plan", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PremiumScreen()),
                            );
                          }),
                          const Divider(),
                          _buildRowWithSubtitle(
                            Icons.flash_on,
                            "Buy Question Booster",
                            "Get extra questions when daily limit is reached.",
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BoosterPackScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle("ABOUT"),
                    Card(
                      child: Column(
                        children: [
                          _buildRow(Icons.description_outlined, "Terms of Service", LegalLinks.launchTermsConditions),
                          const Divider(),
                          _buildRow(Icons.privacy_tip_outlined, "Privacy Policy", LegalLinks.launchPrivacyPolicy),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle("ACCOUNT ACTIONS"),
                    Card(
                      child: Column(
                        children: [
                          _buildActionRow("Log out", Colors.redAccent),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              "Delete account",
                              style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF2C4E6E)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.black12),
          ],
        ),
      ),
    );
  }

  Widget _buildRowWithSubtitle(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF2C4E6E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.black12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String title, Color color) {
    return InkWell(
      onTap: () async {
        if (title == "Log out") {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (r) => false,
            );
          }
        }
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CHANGE PASSWORD"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(labelText: "Current Password"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: "New Password"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: "Confirm New Password"),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("SUBMIT"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
