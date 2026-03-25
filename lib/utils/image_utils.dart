import 'package:flutter/material.dart';

class ImageUtils {
  static String? safeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) return null;
    return url;
  }

  static ImageProvider getImageProvider(String? url, {String fallback = 'assets/default.png'}) {
    final validUrl = safeUrl(url);
    if (validUrl != null) {
      return NetworkImage(validUrl);
    }
    return AssetImage(fallback);
  }

  static Widget networkImage(
    String? url, {
    String fallback = 'assets/default.png',
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
        errorBuilder: (context, error, stackTrace) => Image.asset(
          fallback,
          width: width,
          height: height,
          fit: fit,
        ),
      );
    }
    return Image.asset(
      fallback,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
