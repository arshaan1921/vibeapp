import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SnapViewerScreen extends StatefulWidget {
  final String imageUrl;
  const SnapViewerScreen({super.key, required this.imageUrl});

  @override
  State<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends State<SnapViewerScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-close after 10 seconds (Snapchat style)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (context, url, error) => const Center(
              child: Text("Failed to load snap", style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
