import 'package:flutter/material.dart';
import '../services/safety_service.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("V 1 B E PREMIUM"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text(
              "Unlock Everything",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Support V 1 B E and get exclusive perks",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _featureRow(Icons.all_inclusive, "Unlimited questions daily"),
            _featureRow(Icons.block, "No ads ever"),
            _featureRow(Icons.verified, "Premium profile badge"),
            _featureRow(Icons.color_lens, "Custom profile themes"),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                safetyService.isPremium = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Welcome to Premium!")),
                );
                Navigator.pop(context);
              },
              child: const Text("UPGRADE FOR \$4.99/MO"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Restore Purchases", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2C4E6E), size: 24),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
