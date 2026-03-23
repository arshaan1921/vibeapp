import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';
import '../widgets/input_field.dart';
import 'home.dart';

class CreateProfileScreen extends StatelessWidget {
  const CreateProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.add_a_photo, size: 40),
            ),
            const SizedBox(height: 32),
            const InputField(label: 'Username'),
            const SizedBox(height: 20),
            const InputField(
              label: 'Bio',
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Continue',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
