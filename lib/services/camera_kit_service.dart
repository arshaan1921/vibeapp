import 'package:flutter/services.dart';

class CameraKitService {
  static const _channel = MethodChannel('com.v1be.high5/camera_kit');

  /// Launches the Snapchat Camera Kit UI.
  /// Returns the file path of the captured media, or null if cancelled.
  Future<String?> launchCameraKit(String lensGroupId) async {
    try {
      final String? result = await _channel.invokeMethod('launchCameraKit', {
        'lensGroupId': lensGroupId,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to launch Camera Kit: '${e.message}'.");
      return null;
    }
  }
}
