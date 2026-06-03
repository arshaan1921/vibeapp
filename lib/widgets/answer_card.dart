import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/answer.dart';
import '../screens/profile.dart';
import '../screens/answer_view_screen.dart';
import '../utils/premium_utils.dart';
import '../services/like_service.dart';
import '../utils/image_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/block_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

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
  
  final ScreenshotController _screenshotController = ScreenshotController();

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
      
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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

  Future<void> _shareCard() async {
    try {
      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 2.0,
      );

      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/high5_share_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Check out this answer on High5! 🔥',
      );
    } catch (e) {
      debugPrint("Error sharing card: $e");
    }
  }

  void _showOptionsMenu(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMyAnswer = widget.answer.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomSheetItem(
                icon: Icons.send_rounded,
                title: "Share Answer",
                onTap: () {
                  Navigator.pop(context);
                  _shareCard();
                },
              ),
              if (isMyAnswer) ...[
                _buildBottomSheetItem(
                  icon: widget.answer.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  title: widget.answer.isPinned ? "Unpin Answer" : "Pin Answer",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPin?.call(widget.answer.id, !widget.answer.isPinned);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.delete_outline_rounded,
                  title: "Delete Answer",
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete();
                  },
                ),
              ] else ...[
                _buildBottomSheetItem(
                  icon: Icons.report_problem_outlined,
                  title: "Report Answer",
                  isDestructive: true,
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
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _showReportDialog({
    required BuildContext context,
    required String answerId,
    required String reportedUserId,
  }) async {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Answer"),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Reason...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(context);
                _submitAnswerReport(reason);
              },
              child: const Text("Report"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAnswerReport(String reason) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Save report to Supabase
      // Using only columns verified to exist in the 'reports' table
      await supabase.from('reports').insert({
        'user_id': user.id,
        'reported_user_id': widget.answer.userId,
        'message': "REPORTED ANSWER ID: ${widget.answer.id}\n"
            "ANSWER TEXT: ${widget.answer.text}\n"
            "REASON: $reason",
      });

      // 2. Fetch reporter info for Telegram
      final profile = await supabase
          .from('profiles')
          .select('username, name')
          .eq('id', user.id)
          .single();

      final reporterName = profile['name'] ?? 'N/A';
      final reporterUsername = profile['username'] ?? 'N/A';

      // 3. Send to Telegram
      const botToken = "8637680343:AAF7GFChAKkZquMj_Ptm_NDMSgVp4PnAryA";
      const chatId = "5519527890";
      const telegramUrl = "https://api.telegram.org/bot$botToken/sendMessage";

      final telegramMessage = "🚨 ANSWER REPORT\n\n"
          "Reporter: $reporterName (@$reporterUsername)\n"
          "Reported User ID: ${widget.answer.userId}\n"
          "Answer ID: ${widget.answer.id}\n"
          "Answer Text: ${widget.answer.text}\n"
          "\nReason:\n$reason";

      await http.post(
        Uri.parse(telegramUrl),
        body: {
          "chat_id": chatId,
          "text": telegramMessage,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answer reported successfully")),
        );
      }
    } catch (e) {
      debugPrint("Reporting error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit report. Please try again.")),
        );
      }
    }
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
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reply to @${widget.answer.username}",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyController,
                    maxLines: null,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Write a reply...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSending ? null : () {
                      final text = replyController.text.trim();
                      if (text.isEmpty) return;
                      setModalState(() => isSending = true);
                      _submitReply(text, setModalState);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("SEND REPLY"),
                  ),
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

      if (mounted) {
        Navigator.pop(context);
        _fetchReplyCount();
        if (_showReplies) _fetchReplies();
      }
    } catch (e) {
      debugPrint("Error sending reply: $e");
    }
  }

  void _confirmDeleteReply(String replyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Reply"),
        content: const Text("Are you sure you want to delete this reply?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReply(replyId);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteReply(String replyId) async {
    try {
      await Supabase.instance.client.from('answer_replies').delete().eq('id', replyId);
      setState(() {
        _replies.removeWhere((r) => r['id'].toString() == replyId);
        _replyCount--;
      });
    } catch (e) {
      debugPrint("Error deleting reply: $e");
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return DateFormat('MMM d').format(date);
  }

  Future<void> _onOpen(LinkableElement link) async {
    final Uri url = Uri.parse(link.url);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    // Using Screenshot as the root boundary. It already has a RepaintBoundary inside.
    return Screenshot(
      controller: _screenshotController,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // HEADER
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => ImageUtils.showImagePreview(context, widget.answer.avatarUrl),
                      onLongPress: () => _navigateToProfile(widget.answer.userId),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: PremiumUtils.buildProfileRing(widget.answer.premiumPlan),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: ImageUtils.getImageProvider(widget.answer.avatarUrl),
                          child: ImageUtils.safeUrl(widget.answer.avatarUrl) == null
                              ? const Icon(Icons.person, size: 22, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: () => _navigateToProfile(widget.answer.userId),
                                  child: Text(
                                    widget.answer.username,
                                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              PremiumUtils.buildBadge(widget.answer.premiumPlan),
                              if (widget.answer.isVerified) 
                                const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
                              if (widget.answer.isFounder)
                                const Icon(Icons.star_rounded, color: Colors.orange, size: 14),
                            ],
                          ),
                          Text(
                            _formatTimeAgo(widget.answer.createdAt.toLocal()),
                            style: textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (widget.answer.streakCount != null && widget.answer.streakCount! > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text("🔥 ${widget.answer.streakCount}", 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)
                        ),
                      ),
                    IconButton(
                      onPressed: () => _showOptionsMenu(context),
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),

                // QUESTION SECTION
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!widget.answer.isAnonymous && widget.answer.askerId != null) {
                            _navigateToProfile(widget.answer.askerId);
                          }
                        },
                        child: Text(
                          widget.answer.isAnonymous ? "Anonymously asked" : "@${widget.answer.askerUsername ?? 'User'} asked",
                          style: textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic, 
                            color: theme.brightness == Brightness.dark ? Colors.greenAccent : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    Linkify(
                      onOpen: _onOpen,
                      text: widget.answer.questionText,
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3),
                      maxLines: null,
                    ),
                    if (widget.answer.questionImageUrl != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.answer.questionImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ANSWER SECTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Linkify(
                    onOpen: _onOpen,
                    text: widget.answer.text,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15, 
                      height: 1.5,
                    ),
                    options: const LinkifyOptions(humanize: false),
                    maxLines: null,
                  ),
                ),

                const SizedBox(height: 16),

                // METADATA & ACTIONS
                Row(
                  children: [
                    _buildAction(
                      icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isLiked ? Colors.red : theme.colorScheme.onSurface,
                      label: _likeCount.toString(),
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 20),
                    _buildAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: theme.colorScheme.onSurface,
                      label: _replyCount.toString(),
                      onTap: _showReplySheet,
                    ),
                    const SizedBox(width: 20),
                    _buildAction(
                      icon: Icons.send_rounded,
                      color: theme.colorScheme.onSurface,
                      label: "",
                      onTap: _shareCard,
                    ),
                    const Spacer(),
                    if (widget.answer.isPinned)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.push_pin_rounded, size: 14, color: Colors.blueAccent),
                      ),
                    Text(
                      DateFormat('MMM d, yyyy').format(widget.answer.createdAt.toLocal()),
                      style: textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                
                if (_replyCount > 0) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() => _showReplies = !_showReplies);
                      if (_showReplies && _replies.isEmpty) _fetchReplies();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _showReplies ? "Hide replies" : "View $_replyCount replies",
                        style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                
                if (_showReplies && _replies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // PERFORMANCE: Using list literal + spread for better build efficiency than builder + shrinkwrap
                  for (final reply in _replies)
                    _buildReplyItem(reply),
                ],
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> reply) {
    final profile = reply['profiles'];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMyReply = reply['user_id'] == currentUserId;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: ImageUtils.getImageProvider(profile?['avatar_url']),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("@${profile?['username']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (isMyReply)
                      GestureDetector(
                        onTap: () => _confirmDeleteReply(reply['id'].toString()),
                        child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.grey),
                      ),
                  ],
                ),
                Text(reply['reply'] ?? "", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({required IconData icon, Color? color, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurface),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: color ?? theme.colorScheme.onSurface)),
          ],
        ],
      ),
    );
  }
}
