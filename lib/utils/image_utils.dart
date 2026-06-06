import 'package:flutter/material.dart';

class ImageUtils {
  static String? safeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) return null;
    return url;
  }

  static ImageProvider? getImageProvider(String? url) {
    final validUrl = safeUrl(url);
    if (validUrl != null) {
      return NetworkImage(validUrl);
    }
    return null;
  }

  static Widget networkImage(
    String? url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final validUrl = safeUrl(url);
    if (validUrl != null) {
      return Image.network(
        validUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.person, color: Colors.white),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.person, color: Colors.white),
    );
  }

  static void showImagePreview(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.8),
              ),
            ),
            GestureDetector(
              onTap: () {}, // Prevent dismissal when tapping the image
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
