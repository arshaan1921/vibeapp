import 'package:flutter/material.dart';

class AbuseService {
  static int reportCount = 0;
  static bool isShadowBanned = false;
  static DateTime? bannedUntil;

  static bool canSend(BuildContext context) {
    if (bannedUntil != null && bannedUntil!.isAfter(DateTime.now())) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Restricted"),
          content: const Text("Account temporarily restricted due to reports."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  static void registerReport() {
    reportCount++;
    if (reportCount >= 5) {
      bannedUntil = DateTime.now().add(const Duration(hours: 24));
    } else if (reportCount >= 3) {
      isShadowBanned = true;
    }
  }
}
