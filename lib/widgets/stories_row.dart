import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/story_service.dart';
import '../models/story.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/story_preview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoriesRow extends StatefulWidget {
  const StoriesRow({super.key});

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  List<UserStories> _userStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final stories = await storyService.fetchStories();
      if (mounted) {
        setState(() {
          _userStories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadStory() async {
    final picker = ImagePicker();
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image from Gallery'),
              onTap: () => Navigator.pop(context, 'image_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video from Gallery'),
              onTap: () => Navigator.pop(context, 'video_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera (Photo)'),
              onTap: () => Navigator.pop(context, 'image_camera'),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return;

    XFile? file;
    StoryMediaType type = StoryMediaType.image;

    if (selection == 'image_gallery') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else if (selection == 'video_gallery') {
      file = await picker.pickVideo(source: ImageSource.gallery);
      type = StoryMediaType.video;
    } else if (selection == 'image_camera') {
      file = await picker.pickImage(source: ImageSource.camera);
    }

    if (file != null && mounted) {
      final bool? uploaded = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryPreviewScreen(
            file: File(file!.path),
            mediaType: type,
          ),
        ),
      );

      if (uploaded == true) {
        _loadStories();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    UserStories? ownUserStories;
    final List<UserStories> otherUserStories = [];

    for (var us in _userStories) {
      if (us.userId == currentUser?.id) {
        ownUserStories = us;
      } else {
        otherUserStories.add(us);
      }
    }

    return Container(
      height: 110,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          _buildYourStoryItem(ownUserStories),
          ...otherUserStories.map((us) => _StoryCircle(
            userStories: us,
            onTap: () {
              final index = _userStories.indexOf(us);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryViewerScreen(
                    initialUserIndex: index,
                    allUserStories: _userStories,
                  ),
                ),
              ).then((_) => _loadStories());
            },
          )),
        ],
      ),
    );
  }

  Widget _buildYourStoryItem(UserStories? ownUserStories) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] ?? ownUserStories?.avatarUrl;
    final bool hasStories = ownUserStories != null && ownUserStories.stories.isNotEmpty;
    final bool allSeen = ownUserStories?.allSeen ?? false;
    
    return GestureDetector(
      onTap: () {
        if (hasStories) {
          final index = _userStories.indexOf(ownUserStories!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryViewerScreen(
                initialUserIndex: index,
                allUserStories: _userStories,
              ),
            ),
          ).then((_) => _loadStories());
        } else {
          _pickAndUploadStory();
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (hasStories && !allSeen)
                        ? const LinearGradient(
                            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          )
                        : null,
                    border: (hasStories && allSeen)
                        ? Border.all(color: Colors.grey.shade400, width: 1.5)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, color: Colors.grey, size: 40)
                          : null,
                    ),
                  ),
                ),
                if (!hasStories)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Story',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final UserStories userStories;
  final VoidCallback onTap;

  const _StoryCircle({
    required this.userStories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: userStories.allSeen
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                border: userStories.allSeen
                    ? Border.all(color: Colors.grey.shade400, width: 1.5)
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: userStories.avatarUrl != null
                      ? NetworkImage(userStories.avatarUrl!)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: userStories.avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                userStories.username,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
