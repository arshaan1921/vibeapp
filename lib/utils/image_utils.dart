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
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.person, color: Colors.grey),
    );
  }
}
