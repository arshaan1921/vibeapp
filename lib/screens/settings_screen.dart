import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
                    _buildSettingRow(Icons.info_outline_rounded, "About App", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen()));
                    }),
                    _buildSettingRow(Icons.groups_outlined, "About Us", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()));
                    }),
                    _buildSettingRow(Icons.work_outline_rounded, "Careers", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CareersScreen()));
                    }),
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

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  String _version = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = "${packageInfo.version}+${packageInfo.buildNumber}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("About High5"),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: AssetImage('assets/app_icon.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "High5",
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Version $_version",
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Ask anonymous questions and answer honestly with friends.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "Made with ❤️ in India",
              style: TextStyle(
                color: isDark ? Colors.white24 : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("About Us"),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Our Mission",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "At High5, we believe in the power of honest connections. Our mission is to create a safe and fun space where friends can interact authentically through anonymous questions.",
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Our Story",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "High5 was born out of a simple idea: social media should be more about the people you actually know. We wanted to build something that brings out the personality in every conversation, whether it's through a heartfelt answer or a shared moment.",
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "The Team",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "We are a passionate team based in India, dedicated to building the next generation of social experiences. We're constantly listening to our community to make High5 better every single day.",
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                "Thank you for being part of our journey! 🚀",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
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

class CareersScreen extends StatefulWidget {
  const CareersScreen({super.key});

  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  final _linkController = TextEditingController();
  final _resumeController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  File? _resumeFile;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _linkController.dispose();
    _resumeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _attachResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _resumeFile = File(result.files.single.path!);
          _resumeController.text = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("File picking error: $e");
    }
  }

  Future<void> _submitApplication() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final role = _roleController.text.trim();
    final link = _linkController.text.trim();
    final resumeLink = _resumeController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty || role.isEmpty || (resumeLink.isEmpty && _resumeFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields and attach or link your resume")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'Anonymous';

      const botToken = "8637680343:AAF7GFChAKkZquMj_Ptm_NDMSgVp4PnAryA";
      const chatId = "5519527890";
      
      final telegramMessage = "💼 NEW JOB APPLICATION\n\n"
          "👤 Name: $name\n"
          "📧 Email: $email\n"
          "🎯 Role: $role\n"
          "🔗 Profile/LinkedIn: $link\n"
          "📄 Resume: ${resumeLink.isNotEmpty ? resumeLink : 'File attached'}\n"
          "💬 Message: $message\n\n"
          "🆔 User ID: $userId";

      http.BaseResponse response;

      if (_resumeFile != null) {
        // Send as document to Telegram
        final request = http.MultipartRequest(
          'POST',
          Uri.parse("https://api.telegram.org/bot$botToken/sendDocument"),
        );
        request.fields['chat_id'] = chatId;
        request.fields['caption'] = telegramMessage;
        request.files.add(await http.MultipartFile.fromPath(
          'document',
          _resumeFile!.path,
          filename: _resumeController.text,
        ));
        response = await request.send();
      } else {
        // Send as text message to Telegram
        response = await http.post(
          Uri.parse("https://api.telegram.org/bot$botToken/sendMessage"),
          body: {
            "chat_id": chatId,
            "text": telegramMessage,
          },
        );
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Application submitted successfully! 🚀")),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to send to Telegram");
      }
    } catch (e) {
      debugPrint("Application error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit. Please check your connection.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Work with us"),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Text(
              "Join the High5 Team",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We're always looking for passionate people to help us build the future of social interaction.",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildField("Full Name*", _nameController, "Your name"),
            _buildField("Email Address*", _emailController, "How can we reach you?", keyboardType: TextInputType.emailAddress),
            _buildField("Role interested in*", _roleController, "e.g. Flutter Dev, Designer, etc."),
            _buildField("Portfolio / LinkedIn", _linkController, "URL to your work"),
            _buildResumeField(),
            _buildField("Message / Experience", _messageController, "Tell us something about yourself", maxLines: 3),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitApplication,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("SUBMIT APPLICATION", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "* Required fields",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Resume / CV*", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _resumeController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: "Attach file or paste link",
                    hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && _resumeFile != null) {
                      setState(() => _resumeFile = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _attachResume,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text("ATTACH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          if (_resumeFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "File attached: ${_resumeController.text}",
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _resumeFile = null;
                      _resumeController.clear();
                    }),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}
