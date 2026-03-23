import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';
import '../widgets/input_field.dart';
import 'create_profile.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Account',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign up to get started',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const InputField(
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const InputField(
              label: 'Password',
              isPassword: true,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Signup',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
