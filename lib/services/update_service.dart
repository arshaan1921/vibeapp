import 'dart:io';
import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/update_available_popup.dart';

class UpdateService {
  static Future<void> checkUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return; // Currently focusing on Android as requested

    try {
      final newVersion = NewVersionPlus(
        androidId: 'com.v1be.v1be', // Reverting to com.v1be.v1be as per previous user request
      );

      final status = await newVersion.getVersionStatus();
      if (status != null && status.canUpdate) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false, // Force decision
            builder: (context) => UpdateAvailablePopup(
              storeVersion: status.storeVersion,
              appStoreLink: status.appStoreLink,
              allowDismiss: true, // You can make this dynamic based on major version diff
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  static Future<void> openPlayStore() async {
    const url = 'https://play.google.com/store/apps/details?id=com.v1be.v1be';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
