import 'package:flutter/material.dart';
import '../../models/meme_mania.dart';
import '../../services/meme_mania_service.dart';

class MemeGameScreen extends StatefulWidget {
  final String gameId;

  const MemeGameScreen({super.key, required this.gameId});

  @override
  State<MemeGameScreen> createState() => _MemeGameScreenState();
}

class _MemeGameScreenState extends State<MemeGameScreen> {
  final _service = MemeManiaService();
  final _commentController = TextEditingController();
  late Future<MemeGame> _gameFuture;
  List<MemeComment> _comments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _gameFuture = _service.getGameDetails(widget.gameId);
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _service.getComments(widget.gameId);
      if (mounted) {
        setState(() {
          _comments = comments;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _service.addComment(widget.gameId, text);
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      if (mounted) {
        debugPrint('❌ UI Comment Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleToggleLike(MemeComment comment) async {
    // Optimistic UI Update
    setState(() {
      if (comment.isUpvotedByMe) {
        comment.isUpvotedByMe = false;
        comment.upvotes--;
      } else {
        comment.isUpvotedByMe = true;
        comment.upvotes++;
      }
    });

    try {
      await _service.toggleLike(comment.id);
      // Optional: reload to ensure sync with server count/state
      // await _loadComments(); 
    } catch (e) {
      debugPrint('Toggle like error: $e');
      // Rollback on error
      setState(() {
        if (comment.isUpvotedByMe) {
          comment.isUpvotedByMe = false;
          comment.upvotes--;
        } else {
          comment.isUpvotedByMe = true;
          comment.upvotes++;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MEME GAME')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<MemeGame>(
              future: _gameFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Game not found'));
                }
                
                final game = snapshot.data!;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.network(
                            game.imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 300,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => const SizedBox(
                              height: 200,
                              child: Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                            ),
                          ),
                          if (game.caption != null && game.caption!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                game.caption!,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              'COMMENTS',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _comments.isEmpty
                        ? const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('No comments yet. Be the first!')),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final comment = _comments[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: comment.user?.avatarUrl != null
                                        ? NetworkImage(comment.user!.avatarUrl!)
                                        : null,
                                    child: comment.user?.avatarUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(
                                    comment.user?.username ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(comment.comment),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          comment.isUpvotedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                                          size: 18,
                                          color: comment.isUpvotedByMe ? Colors.blue : Colors.grey,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _handleToggleLike(comment),
                                      ),
                                      Text('${comment.upvotes}', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                );
                              },
                              childCount: _comments.length,
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: InputBorder.none,
              ),
              maxLines: null,
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.blue),
            onPressed: _isSending ? null : _sendComment,
          ),
        ],
      ),
    );
  }
}
