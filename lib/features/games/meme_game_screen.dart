import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meme_mania.dart';
import '../../services/meme_mania_service.dart';
import '../../providers/game_provider.dart';
import '../../utils/image_utils.dart';

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
    _markSeen();
  }

  Future<void> _markSeen() async {
    await _service.markAsSeen(widget.gameId);
    if (mounted) Provider.of<GameProvider>(context, listen: false).decrementCount();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _service.getComments(widget.gameId);
      if (mounted) setState(() => _comments = comments);
    } catch (e) {
      debugPrint('Error: $e');
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
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleVote(MemeComment comment) async {
    // Optimistic UI
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
    } catch (e) {
      _loadComments(); // Rollback
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("MEME BATTLE", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<MemeGame>(
              future: _gameFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData) return const Center(child: Text("Meme not found"));
                
                final game = snapshot.data!;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(game.imageUrl, fit: BoxFit.contain),
                            ),
                          ),
                          if (game.caption != null && game.caption!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Text(
                                game.caption!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text("BATTLE COMMENTS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _comments.isEmpty
                        ? const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text("No roasts yet. Be the first!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _MemeCommentTile(
                                  comment: _comments[index],
                                  onVote: () => _handleVote(_comments[index]),
                                  isCreator: _comments[index].userId == game.creatorId,
                                ),
                                childCount: _comments.length,
                              ),
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Roast this meme...",
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F2F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendComment,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
              child: _isSending 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemeCommentTile extends StatelessWidget {
  final MemeComment comment;
  final VoidCallback onVote;
  final bool isCreator;

  const _MemeCommentTile({required this.comment, required this.onVote, required this.isCreator});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCreator ? const Color(0xFFF59E0B).withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: ImageUtils.getImageProvider(comment.user?.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.user?.username ?? "Someone", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    if (isCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
                        child: const Text("OP", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.comment, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onVote,
            child: Column(
              children: [
                Icon(
                  comment.isUpvotedByMe ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  size: 20,
                  color: comment.isUpvotedByMe ? Colors.redAccent : Colors.grey,
                ),
                Text("${comment.upvotes}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
