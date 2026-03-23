import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/premium_utils.dart';
import 'profile.dart';
import '../widgets/primary_button.dart';
import '../services/block_service.dart';

class AnswerDetailScreen extends StatefulWidget {
  final String answerId;

  const AnswerDetailScreen({super.key, required this.answerId});

  @override
  State<AnswerDetailScreen> createState() => _AnswerDetailScreenState();
}

class _AnswerDetailScreenState extends State<AnswerDetailScreen> {
  Map<String, dynamic>? _answer;
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;
  bool _isLoadingReplies = false;
  bool _showReplies = false;
  final Set<String> _likedAnswerIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAnswerDetail();
  }

  Future<void> _fetchAnswerDetail() async {
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
            questions:questions!answers_question_id_fkey(
              text,
              is_anonymous,
              from_user,
              asker:profiles!from_user(id, username)
            )
          ''')
          .eq('id', widget.answerId)
          .single();

      if (user != null) {
        final likesRes = await supabase
            .from('answer_likes')
            .select('answer_id')
            .eq('user_id', user.id)
            .eq('answer_id', widget.answerId);
        
        if ((likesRes as List).isNotEmpty) {
          _likedAnswerIds.add(widget.answerId);
        }
      }

      if (mounted) {
        setState(() {
          _answer = response;
          _isLoading = false;
        });
        _fetchReplies(); // Fetch initial count/replies
      }
    } catch (e) {
      debugPrint("Error fetching answer detail: $e");
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching replies: $e");
      if (mounted) setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_answer == null) return;
    
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isLiked = _likedAnswerIds.contains(widget.answerId);

    setState(() {
      if (isLiked) {
        _likedAnswerIds.remove(widget.answerId);
        _answer!['likes_count'] = (_answer!['likes_count'] as int? ?? 0) - 1;
      } else {
        _likedAnswerIds.add(widget.answerId);
        _answer!['likes_count'] = (_answer!['likes_count'] as int? ?? 0) + 1;
      }
    });

    try {
      if (isLiked) {
        await supabase
            .from('answer_likes')
            .delete()
            .eq('answer_id', widget.answerId)
            .eq('user_id', user.id);
      } else {
        await supabase.from('answer_likes').insert({
          'answer_id': widget.answerId,
          'user_id': user.id,
        });

        if (_answer!['user_id'] != user.id) {
          await supabase.from('notifications').insert({
            'user_id': _answer!['user_id'],
            'source_user': user.id,
            'source_id': widget.answerId,
            'type': 'like',
            'seen': false,
          });
        }
      }
    } catch (e) {
      _fetchAnswerDetail();
    }
  }

  void _showReplySheet() {
    final TextEditingController replyController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      setModalState(() => isSending = true);
                      _submitReply(text, setModalState);
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

  Future<void> _submitReply(String text, Function(VoidCallback) setModalState) async {
    try {
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply added")));
        setState(() => _showReplies = true);
        _fetchReplies();
      }
    } catch (e) {
      debugPrint("Error sending reply: $e");
    } finally {
      setModalState(() => isSending = false);
    }
  }

  bool isSending = false;

  String _formatTimeAgo(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM d').format(date);
  }

  void _navigateToProfile(String? userId) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text("ANSWER DETAIL"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _answer == null
              ? const Center(child: Text("Answer not found"))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
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
                                              backgroundColor: Colors.grey[300],
                                              backgroundImage: (_answer!['profiles']?['avatar_url'] != null && _answer!['profiles']?['avatar_url'] != '') ? NetworkImage(_answer!['profiles']?['avatar_url']) : null,
                                              child: (_answer!['profiles']?['avatar_url'] == null || _answer!['profiles']?['avatar_url'] == '') ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
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
                                                Flexible(
                                                  child: Text(
                                                    "@${_answer!['profiles']?['username'] ?? "User"}",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildAskerText(),
                                    const SizedBox(height: 4),
                                    Text(
                                      _answer!['questions']?['text'] ?? "",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _answer!['answer_text'] ?? "",
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _toggleLike,
                                          child: Row(
                                            children: [
                                              Icon(
                                                _likedAnswerIds.contains(widget.answerId) ? Icons.favorite : Icons.favorite_border,
                                                color: _likedAnswerIds.contains(widget.answerId) ? Colors.red : Colors.grey,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${_answer!['likes_count'] ?? 0}',
                                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        GestureDetector(
                                          onTap: _showReplySheet,
                                          child: const Row(
                                            children: [
                                              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Reply",
                                                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimeAgo(_answer!['created_at']),
                                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            if (_replies.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () => setState(() => _showReplies = !_showReplies),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    _showReplies ? "Hide replies" : "View replies (${_replies.length})",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13),
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
                                                backgroundImage: (profile?['avatar_url'] != null && profile?['avatar_url'] != '') ? NetworkImage(profile['avatar_url']) : null,
                                                child: (profile?['avatar_url'] == null || profile?['avatar_url'] == '') ? const Icon(Icons.person, size: 16) : null,
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
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                                    style: const TextStyle(fontSize: 13),
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
                            ] else if (!_isLoadingReplies) ...[
                               const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text("No replies yet.", style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            ],
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: PrimaryButton(
                          text: "Write a reply...",
                          onPressed: _showReplySheet,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAskerText() {
    final question = _answer!['questions'];
    final isAnonymous = question?['is_anonymous'] ?? false;
    final askerData = question?['asker'];
    
    Map<String, dynamic>? asker;
    if (askerData is List && askerData.isNotEmpty) {
      asker = askerData.first;
    } else if (askerData is Map<String, dynamic>) {
      asker = askerData;
    }

    if (isAnonymous || asker == null) {
      return const Text(
        "@anonymously asked",
        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
      );
    } else {
      return GestureDetector(
        onTap: () => _navigateToProfile(asker?['id']),
        child: Text(
          "@${asker['username']} asked",
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }
  }
}
