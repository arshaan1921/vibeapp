import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/answer.dart';
import '../screens/profile.dart';
import '../utils/premium_utils.dart';
import '../services/like_service.dart';
import '../utils/image_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/primary_button.dart';
import '../services/block_service.dart';
import 'package:http/http.dart' as http;

class AnswerCard extends StatefulWidget {
  final AnswerModel answer;
  final VoidCallback? onLikeChanged;
  final Function(String)? onDelete;
  final Function(String, bool)? onPin;

  const AnswerCard({
    super.key,
    required this.answer,
    this.onLikeChanged,
    this.onDelete,
    this.onPin,
  });

  @override
  State<AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<AnswerCard> {
  late bool _isLiked;
  late int _likeCount;
  bool _isProcessing = false;
  int _replyCount = 0;
  bool _showReplies = false;
  List<Map<String, dynamic>> _replies = [];
  bool _isLoadingReplies = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.answer.isLiked;
    _likeCount = widget.answer.likeCount;
    _fetchReplyCount();
  }

  @override
  void didUpdateWidget(AnswerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isProcessing) {
      if (_isLiked != widget.answer.isLiked || _likeCount != widget.answer.likeCount) {
        setState(() {
          _isLiked = widget.answer.isLiked;
          _likeCount = widget.answer.likeCount;
        });
      }
    }
  }

  Future<void> _fetchReplyCount() async {
    try {
      final response = await Supabase.instance.client
          .from('answer_replies')
          .select('id')
          .eq('answer_id', widget.answer.id);
      
      if (mounted) {
        setState(() {
          _replyCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reply count: $e");
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
          .eq('answer_id', widget.answer.id)
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
    if (_isProcessing) return;

    final originalIsLiked = _isLiked;
    final originalLikeCount = _likeCount;

    setState(() {
      _isProcessing = true;
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });

    widget.onLikeChanged?.call();

    try {
      if (originalIsLiked) {
        await LikeService.unlikeAnswer(widget.answer.id);
      } else {
        await LikeService.likeAnswer(widget.answer.id);
      }
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _isProcessing = false);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = originalIsLiked;
          _likeCount = originalLikeCount;
          _isProcessing = false;
        });
        widget.onLikeChanged?.call();
      }
    }
  }

  void _navigateToProfile(String? userId) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMyAnswer = widget.answer.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyAnswer) ...[
                ListTile(
                  leading: Icon(widget.answer.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                  title: Text(widget.answer.isPinned ? "Unpin Answer" : "Pin Answer"),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPin?.call(widget.answer.id, !widget.answer.isPinned);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Delete Answer", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                  title: const Text("Report Answer", style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(
                      context: context,
                      answerId: widget.answer.id,
                      reportedUserId: widget.answer.userId,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportDialog({
    required BuildContext context,
    required String answerId,
    required String reportedUserId,
  }) async {
    final TextEditingController controller = TextEditingController();
    final supabase = Supabase.instance.client;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Answer 🚨"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Why are you reporting this answer?"),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Write your reason...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isEmpty) return;

                final user = supabase.auth.currentUser;
                if (user == null) return;

                bool dbSuccess = false;
                String? duplicateError;

                try {
                  await supabase.from('reports').insert({
                    'user_id': user.id,
                    'answer_id': answerId,
                    'reported_user_id': reportedUserId,
                    'message': message,
                  });
                  dbSuccess = true;
                } on PostgrestException catch (e) {
                  if (e.message.contains("duplicate key")) {
                    duplicateError = "You already reported this answer 🚨";
                  }
                } catch (e) {
                  debugPrint("DB error: $e");
                }

                // Always send to Telegram
                try {
                  const botToken = "8637680343:AAF7GFChAKkZquMj_Ptm_NDMSgVp4PnAryA";
                  const chatId = "5519527890";
                  const telegramUrl = "https://api.telegram.org/bot$botToken/sendMessage";

                  final telegramMessage = "🚨 Answer Report\n\n"
                      "Reporter ID: ${user.id}\n"
                      "Answer ID: $answerId\n"
                      "Reported User ID: $reportedUserId\n\n"
                      "Message:\n$message\n\n"
                      "DB Status: ${dbSuccess ? 'Saved' : (duplicateError != null ? 'Duplicate' : 'Error')}";

                  final response = await http.post(
                    Uri.parse(telegramUrl),
                    body: {
                      "chat_id": chatId,
                      "text": telegramMessage,
                    },
                  );
                  debugPrint("Telegram status: ${response.statusCode}");
                  debugPrint("Telegram body: ${response.body}");
                } catch (e) {
                  debugPrint("Telegram notification failed: $e");
                }

                if (mounted) {
                  Navigator.pop(context);
                  String feedback = dbSuccess 
                      ? "Reported successfully 🚨" 
                      : (duplicateError ?? "Something went wrong");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(feedback)),
                  );
                }
              },
              child: const Text("Report"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Answer"),
        content: const Text("Are you sure you want to delete this answer?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call(widget.answer.id);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
        bool isSending = false;
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
                    "Reply to @${widget.answer.username}",
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
                          widget.answer.questionText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.answer.text,
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
        'answer_id': widget.answer.id,
        'user_id': user.id,
        'reply': text,
      });

      if (widget.answer.userId != user.id) {
        await supabase.from('notifications').insert({
          'user_id': widget.answer.userId,
          'source_user': user.id,
          'source_id': widget.answer.id,
          'type': 'answer',
          'seen': false,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        _fetchReplyCount();
        if (_showReplies) _fetchReplies();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reply sent!")),
        );
      }
    } catch (e) {
      debugPrint("Error sending reply: $e");
    } finally {
      if (mounted) setModalState(() => {}); 
    }
  }

  void _deleteReply(String replyId) async {
    try {
      await Supabase.instance.client.from('answer_replies').delete().eq('id', replyId);
      setState(() {
        _replies.removeWhere((r) => r['id'] == replyId);
        _replyCount--;
      });
    } catch (e) {
       debugPrint("Error deleting reply: $e");
    }
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
    final textTheme = theme.textTheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.answer.isPinned)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      "Pinned Answer",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent[700],
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(widget.answer.userId),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: PremiumUtils.buildProfileRing(widget.answer.premiumPlan),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: ImageUtils.getImageProvider(widget.answer.avatarUrl),
                      child: ImageUtils.safeUrl(widget.answer.avatarUrl) == null 
                          ? const Icon(Icons.person, size: 20, color: Colors.white) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(widget.answer.userId),
                    child: Row(
                      children: [
                        PremiumUtils.buildBadge(widget.answer.premiumPlan),
                        Flexible(
                          child: Text(
                            "@${widget.answer.username}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                              color: textTheme.bodyLarge?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsMenu(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.answer.isAnonymous ? "@anonymously asked" : "@${widget.answer.askerUsername ?? 'User'} asked",
              style: TextStyle(
                fontSize: 12, 
                color: textTheme.bodySmall?.color ?? Colors.grey, 
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.answer.questionText, 
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 15,
                color: textTheme.bodyLarge?.color,
              ),
            ),
            
            // QUESTION IMAGE
            if (widget.answer.questionImageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.answer.questionImageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              widget.answer.text,
              style: TextStyle(
                fontSize: 14, 
                color: textTheme.bodyMedium?.color,
              ),
            ),
            
            if (_replyCount > 0) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() => _showReplies = !_showReplies);
                  if (_showReplies && _replies.isEmpty) _fetchReplies();
                },
                child: Text(
                  _showReplies ? "Hide replies" : "View replies ($_replyCount)",
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold, 
                    color: theme.primaryColor,
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
                      final isMyReply = reply['user_id'] == currentUserId;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _navigateToProfile(profile?['id']),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: (profile?['avatar_url'] != null && profile?['avatar_url'] != '') ? NetworkImage(profile['avatar_url']) : null,
                                child: (profile?['avatar_url'] == null || profile?['avatar_url'] == '') ? const Icon(Icons.person, size: 14) : null,
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
                                      const Spacer(),
                                      if (isMyReply)
                                        PopupMenuButton<String>(
                                          onSelected: (val) {
                                            if (val == 'delete') _deleteReply(reply['id'].toString());
                                          },
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13))),
                                          ],
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
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : theme.iconTheme.color,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$_likeCount", 
                        style: TextStyle(
                          fontSize: 13, 
                          color: textTheme.bodyMedium?.color, 
                          fontWeight: FontWeight.w600,
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
                      Icon(Icons.chat_bubble_outline, size: 20, color: theme.iconTheme.color),
                      const SizedBox(width: 6),
                      Text(
                        "$_replyCount", 
                        style: TextStyle(
                          fontSize: 13, 
                          color: textTheme.bodyMedium?.color, 
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(widget.answer.createdAt.toLocal()), 
                  style: TextStyle(
                    color: textTheme.bodySmall?.color, 
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
