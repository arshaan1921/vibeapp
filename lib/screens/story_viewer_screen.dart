import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../models/story.dart';
import '../services/story_service.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserStories> allUserStories;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.allUserStories,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  int _currentUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _pageController = PageController(initialPage: widget.initialUserIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        itemCount: widget.allUserStories.length,
        onPageChanged: (index) {
          setState(() {
            _currentUserIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return UserStorySection(
            userStories: widget.allUserStories[index],
            isActive: _currentUserIndex == index,
            onUserComplete: () {
              if (index < widget.allUserStories.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              } else {
                Navigator.pop(context, true);
              }
            },
            onUserPrevious: () {
              if (index > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            onStoryDeleted: () {
              Navigator.pop(context, true);
            },
          );
        },
      ),
    );
  }
}

class UserStorySection extends StatefulWidget {
  final UserStories userStories;
  final bool isActive;
  final VoidCallback onUserComplete;
  final VoidCallback onUserPrevious;
  final VoidCallback onStoryDeleted;

  const UserStorySection({
    super.key,
    required this.userStories,
    required this.isActive,
    required this.onUserComplete,
    required this.onUserPrevious,
    required this.onStoryDeleted,
  });

  @override
  State<UserStorySection> createState() => _UserStorySectionState();
}

class _UserStorySectionState extends State<UserStorySection> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  bool _isPaused = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
    
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    if (widget.isActive) {
      _loadStory(story: widget.userStories.stories[_currentIndex]);
    }
  }

  @override
  void didUpdateWidget(UserStorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadStory(story: widget.userStories.stories[_currentIndex]);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pauseStory();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _pauseStory() {
    _animController.stop();
    _videoController?.pause();
    setState(() => _isPaused = true);
  }

  void _resumeStory() {
    if (!_isInitialized) return;
    _animController.forward();
    _videoController?.play();
    setState(() => _isPaused = false);
  }

  void _nextStory() {
    _animController.stop();
    _animController.reset();
    if (_currentIndex + 1 < widget.userStories.stories.length) {
      setState(() {
        _currentIndex++;
      });
      _loadStory(story: widget.userStories.stories[_currentIndex]);
    } else {
      widget.onUserComplete();
    }
  }

  void _previousStory() {
    _animController.stop();
    _animController.reset();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory(story: widget.userStories.stories[_currentIndex]);
    } else {
      widget.onUserPrevious();
    }
  }

  Future<void> _loadStory({required StoryModel story}) async {
    _isInitialized = false;
    _animController.stop();
    _animController.reset();
    _videoController?.dispose();
    _videoController = null;

    // Mark as seen IMMEDIATELY using upsert
    await storyService.markStoryAsSeen(story.id);

    if (story.mediaType == StoryMediaType.video) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl))
        ..initialize().then((_) {
          if (mounted && widget.isActive) {
            setState(() {
              _isInitialized = true;
            });
            _animController.duration = _videoController!.value.duration;
            _videoController!.play();
            _animController.forward();
          }
        });
    } else {
      setState(() {
        _isInitialized = true;
      });
      _animController.duration = const Duration(seconds: 5);
      _animController.forward();
    }
  }

  void _showViewers(String storyId) async {
    _pauseStory();
    final viewers = await storyService.fetchStoryViewers(storyId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Viewers (${viewers.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Expanded(
                child: viewers.isEmpty 
                  ? const Center(child: Text('No views yet', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (context, index) {
                        final viewer = viewers[index]['profiles'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (viewer != null && viewer['avatar_url'] != null) ? NetworkImage(viewer['avatar_url']) : null,
                            child: (viewer == null || viewer['avatar_url'] == null) ? const Icon(Icons.person) : null,
                          ),
                          title: Text(viewer?['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _resumeStory());
  }

  void _showMenu(StoryModel story) {
    _pauseStory();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnStory = story.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isOwnStory)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Story', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await storyService.deleteStory(story.id, story.mediaUrl);
                    widget.onStoryDeleted();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text('Cancel', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    ).then((_) => _resumeStory());
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.userStories.stories[_currentIndex];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnStory = story.userId == currentUserId;

    return GestureDetector(
      onTapDown: (_) => _pauseStory(),
      onTapUp: (details) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dx = details.globalPosition.dx;
        if (dx < screenWidth / 3) {
          _previousStory();
        } else {
          _nextStory();
        }
        _resumeStory();
      },
      onLongPress: _pauseStory,
      onLongPressUp: _resumeStory,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 10) {
          Navigator.pop(context, true);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildMedia(story),
            ),
          ),
          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: widget.userStories.stories.asMap().entries.map((entry) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _AnimatedBar(
                            animController: _animController,
                            position: entry.key,
                            currentIndex: _currentIndex,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: widget.userStories.avatarUrl != null
                            ? NetworkImage(widget.userStories.avatarUrl!)
                            : null,
                        backgroundColor: Colors.grey[800],
                        child: widget.userStories.avatarUrl == null
                            ? const Icon(Icons.person, size: 20, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userStories.username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                            ),
                            Text(
                              _timeAgo(story.createdAt),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showMenu(story),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Caption
          if (story.caption != null && story.caption!.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Text(
                story.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              ),
            ),
          // View count / Interaction Bar
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: isOwnStory 
              ? GestureDetector(
                  onTap: () => _showViewers(story.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                        Text('Activity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              : _buildInteractionBar(story),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(StoryModel story) {
    if (story.mediaType == StoryMediaType.video) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Center(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    } else {
      return CachedNetworkImage(
        key: ValueKey(story.id),
        imageUrl: story.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
  }

  Widget _buildInteractionBar(StoryModel story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(25),
                color: Colors.black26,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.centerLeft,
              child: const Text('Send message', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 15),
          IconButton(
            icon: Icon(story.isLiked ? Icons.favorite : Icons.favorite_border, color: story.isLiked ? Colors.red : Colors.white),
            onPressed: () => storyService.likeStory(story.id),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _AnimatedBar extends StatelessWidget {
  final AnimationController animController;
  final int position;
  final int currentIndex;

  const _AnimatedBar({
    required this.animController,
    required this.position,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            _buildContainer(double.infinity, position < currentIndex ? Colors.white : Colors.white.withOpacity(0.3)),
            position == currentIndex
                ? AnimatedBuilder(
                    animation: animController,
                    builder: (context, child) {
                      return _buildContainer(constraints.maxWidth * animController.value, Colors.white);
                    },
                  )
                : const SizedBox.shrink(),
          ],
        );
      },
    );
  }

  Container _buildContainer(double width, Color color) {
    return Container(
      height: 2.5,
      width: width,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(blurRadius: 1, color: Colors.black26)]),
    );
  }
}
