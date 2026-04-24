import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../models/story.dart';
import '../services/story_service.dart';

class StoryPreviewScreen extends StatefulWidget {
  final File file;
  final StoryMediaType mediaType;

  const StoryPreviewScreen({
    super.key,
    required this.file,
    required this.mediaType,
  });

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == StoryMediaType.video) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      await storyService.uploadStory(
        widget.file,
        widget.mediaType,
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      );
      if (mounted) {
        // Return true to the calling screen so it can refresh the list
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Media Preview
          Positioned.fill(
            child: widget.mediaType == StoryMediaType.image
                ? Image.file(widget.file, fit: BoxFit.cover)
                : (_videoController != null && _videoController!.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white))),
          ),

          // Top Bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                Row(
                  children: [
                    _buildTopIcon(Icons.text_fields, () {
                      // Logic for text overlay could go here
                    }),
                    _buildTopIcon(Icons.emoji_emotions, () {}),
                    _buildTopIcon(Icons.music_note, () {}),
                    _buildTopIcon(Icons.brush, () {}),
                    _buildTopIcon(Icons.unfold_more, () {}),
                  ],
                ),
              ],
            ),
          ),

          // Caption Input and Action Buttons
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Caption Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Bottom Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Your Story Button
                      Expanded(
                        child: GestureDetector(
                          onTap: _handleUpload,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                  backgroundColor: Colors.grey,
                                  child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Your story',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Close Friends Button
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.stars, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Close Friends',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Forward Button
                      GestureDetector(
                        onTap: _handleUpload,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Uploading Story...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopIcon(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
