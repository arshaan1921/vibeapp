import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class SnapViewerScreen extends StatefulWidget {
  final String imageUrl;
  const SnapViewerScreen({super.key, required this.imageUrl});

  @override
  State<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends State<SnapViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    
    _isVideo = widget.imageUrl.toLowerCase().contains('.mp4') || 
               widget.imageUrl.toLowerCase().contains('.mov');

    if (_isVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.imageUrl))
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          // Auto-close after video ends or max 10 seconds
          final duration = _videoController!.value.duration;
          Future.delayed(duration, () {
            if (mounted) Navigator.pop(context);
          });
        });
    } else {
      // Auto-close after 10 seconds for images
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: _isVideo
              ? (_videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : const CircularProgressIndicator(color: Colors.white))
              : CachedNetworkImage(
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
