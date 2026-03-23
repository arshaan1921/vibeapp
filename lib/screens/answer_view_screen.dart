import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/v1be_top_bar.dart';
import '../utils/premium_utils.dart';
import '../utils/image_utils.dart';
import '../services/like_service.dart';
import '../widgets/primary_button.dart';
import '../services/block_service.dart';
import 'profile.dart';

class AnswerViewScreen extends StatefulWidget {
  final String answerId;

  const AnswerViewScreen({super.key, required this.answerId});

  @override
  State<AnswerViewScreen> createState() => _AnswerViewScreenState();
}

class _AnswerViewScreenState extends State<AnswerViewScreen> {
  Map<String, dynamic>? _answer;
  bool _isLoading = true;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isProcessing = false;
  int _replyCount = 0;
  bool _showReplies = false;
  List<Map<String, dynamic>> _replies = [];
  bool _isLoadingReplies = false;

  @override
  void initState() {
    super.initState();
    _fetchAnswer();
    _fetchReplyCount();
  }

  Future<void> _fetchReplyCount() async {
    try {
      final response = await Supabase.instance.client
          .from('answer_replies')
          .select('id')
          .eq('answer_id', widget.answerId);
      
      if (mounted) {
        setState(() {
          _replyCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reply count: $e");
    }
  }

  Future<void> _fetchAnswer() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      final response = await supabase
          .from('answers')
          .select('''
            id,
            answer_text,
            created_at,
            likes_count,
            user_id,
            profiles:profiles!answers_user_id_fkey(id, username, avatar_url, premium_plan),
            questions:questions!answers_question_id_fkey(text)
          ''')
          .eq('id', widget.answerId)
          .single();

      bool liked = false;
      if (user != null) {
        final likeRes = await supabase
            .from('answer_likes')
            .select()
            .eq('answer_id', widget.answerId)
            .eq('user_id', user.id)
            .maybeSingle();
        liked = likeRes != null;
      }

      if (mounted) {
        setState(() {
          _answer = response;
          _isLiked = liked;
          _likeCount = response['likes_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching answer: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchReplies() async {
    if (_isLoadingReplies) return;
    setState(() => _isLoadingReplies = true);
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('answer_replies')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
          .eq('answer_id', widget.answerId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _replies = List<Map<String, dynamic>>.from(response)
              .where((r) => !blockService.isBlocked(r['user_id']))
              .toList();
          _isLoadingReplies = false;
          _replyCount = _replies.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching replies: $e");
      if (mounted) setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isProcessing || _answer == null) return;

    final originalIsLiked = _isLiked;
    final originalLikeCount = _likeCount;

    setState(() {
      _isProcessing = true;
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });

    try {
      if (originalIsLiked) {
        await LikeService.unlikeAnswer(widget.answerId);
      } else {
        await LikeService.likeAnswer(widget.answerId);
      }
      setState(() => _isProcessing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = originalIsLiked;
          _likeCount = originalLikeCount;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update like")),
        );
      }
    }
  }

  void _showReplySheet() {
    final TextEditingController replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSending = false; // Step 1: Declare local state variable

        return StatefulBuilder(
          builder: (context, setModalState) { // Step 2: Wrap bottom sheet with StatefulBuilder
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reply to @${_answer!['profiles']?['username']}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _answer!['questions']?['text'] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _answer!['answer_text'] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyController,
                    maxLines: 3,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Write a reply...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: "SEND REPLY",
                    onPressed: isSending ? () {} : () {
                      final text = replyController.text.trim();
                      if (text.isEmpty) return;
                      
                      setModalState(() => isSending = true); // Step 3: Update sending logic
                      
                      _performSubmitReply(text).then((_) {
                        if (mounted) {
                          Navigator.pop(context);
                          _fetchReplyCount();
                          if (_showReplies) _fetchReplies();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Reply sent!")),
                          );
                        }
                      }).catchError((e) {
                        debugPrint("Error: $e");
                      }).whenComplete(() {
                        if (mounted) {
                          setModalState(() => isSending = false);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performSubmitReply(String text) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('answer_replies').insert({
      'answer_id': widget.answerId,
      'user_id': user.id,
      'reply': text,
    });

    if (_answer!['user_id'] != user.id) {
      await supabase.from('notifications').insert({
        'user_id': _answer!['user_id'],
        'source_user': user.id,
        'source_id': widget.answerId,
        'type': 'answer',
        'seen': false,
      });
    }
  }

  void _navigateToProfile(String? userId) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  String _formatTimeAgo(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text("ANSWER"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _answer == null
              ? const Center(child: Text("Answer not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Card(
                        elevation: 0,
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _navigateToProfile(_answer!['profiles']?['id']),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: PremiumUtils.buildProfileRing(_answer!['profiles']?['premium_plan']),
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                        backgroundImage: ImageUtils.getImageProvider(_answer!['profiles']?['avatar_url']),
                                        child: ImageUtils.safeUrl(_answer!['profiles']?['avatar_url']) == null 
                                            ? const Icon(Icons.person, size: 20, color: Colors.white) 
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToProfile(_answer!['profiles']?['id']),
                                      child: Row(
                                        children: [
                                          PremiumUtils.buildBadge(_answer!['profiles']?['premium_plan']),
                                          Text(
                                            "@${_answer!['profiles']?['username'] ?? "User"}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _answer!['questions']?['text'] ?? "",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800, 
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _answer!['answer_text'] ?? "",
                                style: TextStyle(
                                  fontSize: 14, 
                                  color: isDark ? Colors.grey[300] : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _toggleLike,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isLiked ? Icons.favorite : Icons.favorite_border, 
                                          color: _isLiked ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey), 
                                          size: 20
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$_likeCount',
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[400] : Colors.grey, 
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: _showReplySheet,
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          "$_replyCount", 
                                          style: TextStyle(
                                            fontSize: 13, 
                                            color: isDark ? Colors.grey[400] : Colors.grey, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTimeAgo(_answer!['created_at']),
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey, 
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      if (_replyCount > 0) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() => _showReplies = !_showReplies);
                            if (_showReplies && _replies.isEmpty) _fetchReplies();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _showReplies ? "Hide replies" : "View replies ($_replyCount)",
                              style: TextStyle(
                                fontSize: 13, 
                                fontWeight: FontWeight.bold, 
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        if (_showReplies) ...[
                          const SizedBox(height: 12),
                          if (_isLoadingReplies)
                            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _replies.length,
                              itemBuilder: (context, index) {
                                final reply = _replies[index];
                                final profile = reply['profiles'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _navigateToProfile(profile?['id']),
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.grey[200],
                                          backgroundImage: ImageUtils.getImageProvider(profile?['avatar_url']),
                                          child: ImageUtils.safeUrl(profile?['avatar_url']) == null ? const Icon(Icons.person, size: 16) : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _navigateToProfile(profile?['id']),
                                                  child: Text(
                                                    "@${profile?['username'] ?? 'User'}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold, 
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white : Colors.black,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatTimeAgo(reply['created_at']),
                                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              reply['reply'] ?? "",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey[300] : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ] else ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("No replies yet.", style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      ],
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: "Write a reply...",
                        onPressed: _showReplySheet,
                      ),
                    ],
                  ),
                ),
    );
  }
}
