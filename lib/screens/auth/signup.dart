import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/legal_links.dart';
import '../edit_profile.dart';
import 'login.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final username = usernameController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || username.isEmpty || password.isEmpty || name.isEmpty) {
      _showError("All fields are required");
      return;
    }

    if (!_agreeToTerms) {
      _showError("Please agree to Terms & Privacy Policy");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Call auth.signUp
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'name': name},
      );

      // 2. Wait until session is established (Polling loop)
      Session? session = res.session ?? supabase.auth.currentSession;
      int retries = 0;
      while (session == null && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        session = supabase.auth.currentSession;
        retries++;
      }

      if (session == null || session.user == null) {
        throw AuthException("Auth session not established. Please try logging in.");
      }

      final user = session.user!;

      // 3. Insert into profiles (using .insert() to respect RLS and confirmed constraints)
      try {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'username': username,
          'name': name,
        });
      } on PostgrestException catch (pgError) {
        // Log the real database error
        debugPrint("Database Error: ${pgError.message} (Code: ${pgError.code})");
        
        // Handle specific unique constraint violation (username or email taken)
        if (pgError.code == '23505') {
          throw "This username or email is already taken. Please use a different one.";
        }
        rethrow;
      }

      // 4. Success - Navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(
              isSignupFlow: true,
              initialData: {'name': name, 'username': username},
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      debugPrint("Auth Error: ${e.message}");
      _showError(e.message);
    } catch (e) {
      debugPrint("Signup Flow Error: $e");
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("CREATE ACCOUNT"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Join V 1 B E",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              _buildField(nameController, "Name",
                  cap: TextCapitalization.words),
              const SizedBox(height: 16),
              _buildField(emailController, "Email",
                  type: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField(usernameController, "Username", formatters: [
                LowerCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: "Password",
                  fillColor: theme.cardColor,
                  filled: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (val) =>
                        setState(() => _agreeToTerms = val ?? false),
                  ),
                  const Expanded(
                      child: Text("I agree to the Terms & Privacy Policy")),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text("CREATE ACCOUNT"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint,
      {TextInputType? type,
      List<TextInputFormatter>? formatters,
      TextCapitalization cap = TextCapitalization.none}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      textCapitalization: cap,
      decoration: InputDecoration(
          hintText: hint, fillColor: Theme.of(context).cardColor, filled: true),
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
