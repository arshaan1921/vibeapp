import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../utils/image_utils.dart';
import '../../../services/notification_service.dart';
import '../models/snap_message.dart';
import '../models/streak.dart';
import 'camera_screen.dart';
import 'snap_viewer_screen.dart';
import '../../../screens/premium.dart';
import '../../../widgets/streak_restore_store_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const ChatScreen({super.key, required this.userId, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<SnapMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  int _streak = 0;
  bool _isOnline = false;
  String? _avatarUrl;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  // Streak Restore state
  SnapStreak? _currentStreakData;
  int _freeRestores = 0;
  int _restoresUsed = 0;
  int _purchasedRestores = 0;
  Timer? _countdownTimer;
  bool _isRestoring = false;
  SnapMessage? _replyingTo;
  final Map<String, GlobalKey> _bubbleKeys = {};
  OverlayEntry? _reactionOverlay;

  @override
  void initState() {
    super.initState();
    _loadChatData();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _countdownTimer?.cancel();
    _reactionOverlay?.remove();
    super.dispose();
  }

  void _subscribeToRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = supabase.channel('public:chat_realtime_${widget.userId}');
    
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'snap_recipients',
      callback: (payload) {
        _loadMessages();
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        _loadMessages();
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (payload) {
        _loadMessages();
      },
    ).subscribe();
  }

  Future<void> _loadChatData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch user info
      final userData = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _avatarUrl = userData?['avatar_url'];
        });
      }

      await _fetchStreakData();
      await _fetchUserRestoreLimits();
      await _loadMessages();
    } catch (e) {
      debugPrint("Error loading chat data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStreakData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final streakRes = await supabase
          .from('snap_streaks')
          .select()
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
      
      final streaks = List<dynamic>.from(streakRes as List);
      debugPrint('Loaded streaks: ${streaks.length}');

      final streakMap = streaks.firstWhere(
        (s) =>
            (s['user1_id'] == user.id && s['user2_id'] == widget.userId) ||
            (s['user2_id'] == user.id && s['user1_id'] == widget.userId),
        orElse: () => null,
      );

      if (streakMap != null && mounted) {
        final streak = SnapStreak.fromMap(streakMap);
        final count = streak.streakCount;
        debugPrint('Friend ${widget.userId} streak: $count');

        setState(() {
          _currentStreakData = streak;
          _streak = count;
        });

        if (streak.canBeRestored) {
          _startCountdownTimer();
        }
      } else {
        debugPrint('Friend ${widget.userId} streak: 0');
      }
    } catch (e) {
      debugPrint("Error fetching streak data: $e");
    }
  }

  Future<void> _fetchUserRestoreLimits() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profileRes = await supabase
          .from('profiles')
          .select('free_streak_restores, streak_restores_used_this_month, purchased_streak_restores')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRes != null && mounted) {
        setState(() {
          _freeRestores = profileRes['free_streak_restores'] ?? 0;
          _restoresUsed = profileRes['streak_restores_used_this_month'] ?? 0;
          _purchasedRestores = profileRes['purchased_streak_restores'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching restore limits: $e");
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        if (_currentStreakData != null && !_currentStreakData!.canBeRestored) {
          timer.cancel();
          _fetchStreakData(); // Refresh to hide banner
        } else {
          setState(() {}); // Trigger rebuild to update timer text
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _restoreStreak() async {
    if (_isRestoring || _currentStreakData == null) return;

    setState(() => _isRestoring = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final result = await supabase.rpc(
        'restore_streak',
        params: {
          'p_streak_id': _currentStreakData!.id,
          'p_user_id': user.id,
        },
      );

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("🔥 Streak restored successfully!")),
          );
          await _fetchStreakData();
          await _fetchUserRestoreLimits();
          await _loadMessages();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unable to restore streak")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error restoring streak: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to restore streak")),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('CHAT_SCREEN otherUserId=${widget.userId}');

      // Fetch Received Snaps (me as recipient, they as sender)
      final receivedSnapsRes = await supabase
          .from('snap_recipients')
          .select('*, snaps!inner(*)')
          .eq('recipient_id', user.id)
          .eq('snaps.sender_id', widget.userId)
          .order('delivered_at', ascending: false);

      // Fetch Sent Snaps (me as sender, they as recipient)
      final sentSnapsRes = await supabase
          .from('snap_recipients')
          .select('*, snaps!inner(*)')
          .eq('recipient_id', widget.userId)
          .eq('snaps.sender_id', user.id)
          .order('delivered_at', ascending: false);

      // Fetch regular messages with reactions
      final messagesResponse = await supabase
          .from('messages')
          .select('*, message_reactions(*)')
          .or('and(sender_id.eq.${user.id},receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.${user.id})')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> receivedSnaps = List<Map<String, dynamic>>.from(receivedSnapsRes as List);
      final List<Map<String, dynamic>> sentSnaps = List<Map<String, dynamic>>.from(sentSnapsRes as List);
      final List<Map<String, dynamic>> msgsData = List<Map<String, dynamic>>.from(messagesResponse as List);

      debugPrint('CHAT_LOAD messages count=${msgsData.length}');

      final List<SnapMessage> allMessages = [];

      // Combine and process snaps
      final allSnaps = [...receivedSnaps, ...sentSnaps];

      for (var s in allSnaps) {
        final snap = s['snaps'];
        allMessages.add(SnapMessage(
          id: s['id'],
          snapId: s['snap_id'],
          senderId: snap['sender_id'],
          receiverId: s['recipient_id'],
          imageUrl: snap['image_url'],
          caption: snap['caption'],
          createdAt: DateTime.parse(s['delivered_at'] ?? s['created_at'] ?? snap['created_at']),
          status: _parseSnapStatus(s['status']),
        ));
      }

      for (var m in msgsData) {
        final reactionsData = m['message_reactions'] as List? ?? [];
        final reactions = reactionsData.map((r) => MessageReaction.fromMap(r)).toList();

        allMessages.add(SnapMessage(
          id: m['id'],
          senderId: m['sender_id'],
          receiverId: m['receiver_id'],
          text: m['message'],
          createdAt: DateTime.parse(m['created_at']),
          deliveredAt: m['delivered_at'] != null ? DateTime.parse(m['delivered_at']) : null,
          readAt: m['read_at'] != null ? DateTime.parse(m['read_at']) : null,
          repliedToId: m['replied_to_id'],
          reactions: reactions,
        ));
      }

      // Resolve repliedToMessage references
      for (int i = 0; i < allMessages.length; i++) {
        final msg = allMessages[i];
        if (msg.repliedToId != null) {
          try {
            final repliedMsg = allMessages.firstWhere((m) => m.id == msg.repliedToId);
            allMessages[i] = msg.copyWith(repliedToMessage: repliedMsg);
          } catch (_) {
            // Replied message not found in current list (maybe older)
          }
        }
      }

      allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(allMessages);
        });
      }

      // Mark text messages as delivered/read if we have any incoming ones
      final hasUndeliveredMessages = msgsData.any((m) => m['receiver_id'] == user.id && m['delivered_at'] == null);
      if (hasUndeliveredMessages) {
        _markMessagesAsDelivered();
      }

      final hasUnreadMessages = msgsData.any((m) => m['receiver_id'] == user.id && m['read_at'] == null);
      if (hasUnreadMessages) {
        _markMessagesAsRead();
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }

  Future<void> _markMessagesAsDelivered() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('messages')
          .update({'delivered_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', user.id)
          .eq('sender_id', widget.userId)
          .isFilter('delivered_at', null);
    } catch (e) {
      debugPrint("Error marking messages as delivered: $e");
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', user.id)
          .eq('sender_id', widget.userId)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
  }

  SnapStatus _parseSnapStatus(String status) {
    switch (status) {
      case 'sent': return SnapStatus.sent;
      case 'delivered': return SnapStatus.delivered;
      case 'opened': return SnapStatus.opened;
      default: return SnapStatus.sent;
    }
  }

  Future<void> _markSnapsAsOpened(List<Map<String, dynamic>> snapsData, String myId) async {
    final unreadSnapIds = snapsData
        .where((s) => s['recipient_id'] == myId && s['status'] != 'opened')
        .map((s) => s['id'] as String)
        .toList();

    if (unreadSnapIds.isNotEmpty) {
      final supabase = Supabase.instance.client;
      await supabase
          .from('snap_recipients')
          .update({'status': 'opened', 'opened_at': DateTime.now().toIso8601String()})
          .inFilter('id', unreadSnapIds);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    final repliedToId = _replyingTo?.id;
    
    _textController.clear();
    setState(() => _replyingTo = null);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('CHAT_SEND inserting: $text');
      await supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.userId,
        'message': text,
        'replied_to_id': repliedToId,
      });

      // Fetch sender username for notification
      final profileRes = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      final senderUsername = profileRes?['username'] ?? 'Someone';

      // Send push notification
      await NotificationService.sendNotification(
        userId: widget.userId,
        title: senderUsername,
        body: text,
        data: {
          'type': 'chat',
          'sender_id': user.id,
        },
      );

      // Realtime will pick it up
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              backgroundImage: ImageUtils.getImageProvider(_avatarUrl),
              child: _avatarUrl == null
                  ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.grey[400], size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.userName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_streak > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          "$_streak🔥",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _isOnline ? "Online" : "Recently active",
                    style: TextStyle(fontSize: 11, color: _isOnline ? Colors.green : (isDark ? Colors.white38 : Colors.grey)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_currentStreakData != null && _currentStreakData!.canBeRestored)
            _buildRestoreBanner(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == user?.id;
                    
                    // Find the last outgoing message index
                    bool isLastSent = false;
                    if (isMe && !message.isSnap) {
                      final lastSentIndex = _messages.indexWhere((m) => m.senderId == user?.id && !m.isSnap);
                      isLastSent = index == lastSentIndex;
                    }

                    final key = _bubbleKeys.putIfAbsent(message.id, () => GlobalKey());

                    return Padding(
                      key: key,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _buildMessageBubble(message, isMe, isLastSent),
                    );
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildRestoreBanner() {
    final remainingRestores = (_freeRestores - _restoresUsed).clamp(0, 999) + _purchasedRestores;
    final deadline = _currentStreakData!.timeUntilDeadline;
    final countdownText = deadline != null 
        ? "${deadline.inHours}h ${deadline.inMinutes % 60}m remaining"
        : "";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9D42), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Streak Lost",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "You lost a ${_currentStreakData!.brokenStreakCount} day streak with ${widget.userName}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Restore available for:",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    countdownText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (remainingRestores > 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _isRestoring ? null : _restoreStreak,
                  child: _isRestoring
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        )
                      : const Text(
                          "Restore Streak",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
            ],
          ),
          if (remainingRestores > 0) ...[
            const SizedBox(height: 12),
            Text(
              "Restores remaining: $remainingRestores",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              "No free restores remaining",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Upgrade to Premium for additional streak restores",
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const StreakRestoreStoreDialog(),
                  ).then((value) {
                    if (value == true) {
                      _fetchUserRestoreLimits();
                    }
                  });
                },
                child: const Text("Buy Streak Restores"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Navigate to Premium Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                child: const Text("View Premium Plans"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SnapMessage message, bool isMe, bool isLastSent) {
    debugPrint('RENDER_ITEM_TYPE=${message.isSnap ? 'snap' : 'text'}');
    debugPrint('RENDER_ITEM_STATUS=${message.status}');
    debugPrint('RENDER_IMAGE_URL=${message.imageUrl}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.isSnap)
            _buildSnapItem(message, isMe)
          else
            _buildTextItem(message, isMe, isLastSent),
        ],
      ),
    );
  }

  Widget _buildSnapItem(SnapMessage message, bool isMe) {
    debugPrint('SNAP_WIDGET_BUILD');
    debugPrint('SNAP_STATUS=${message.status}');
    debugPrint('SNAP_URL=${message.imageUrl}');

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    IconData icon;
    Color color;
    String text;

    switch (message.status) {
      case SnapStatus.sent:
      case SnapStatus.delivered:
        icon = isMe ? Icons.play_arrow_rounded : Icons.play_arrow_rounded;
        color = primaryColor;
        text = isMe ? "Delivered" : "Received a snap";
        break;
      case SnapStatus.opened:
        icon = Icons.play_arrow_outlined;
        color = primaryColor.withOpacity(0.7);
        text = isMe ? "Opened" : "Opened";
        break;
      case SnapStatus.screenshot:
        icon = Icons.screenshot_rounded;
        color = theme.colorScheme.secondary;
        text = "Screenshot";
        break;
      default:
        icon = Icons.camera_alt_rounded;
        color = primaryColor;
        text = "Snap";
    }

    return GestureDetector(
      onTap: () => _handleSnapTap(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe 
            ? (theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F8F8)) 
            : (theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              text, 
              style: TextStyle(
                color: color, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTimestampShort(message.createdAt),
              style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white24 : Colors.grey.withOpacity(0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSnapTap(SnapMessage message) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || message.imageUrl == null) {
      debugPrint('PROVE_DELETE: Aborting - User or Image URL is null');
      return;
    }

    final bool isMe = message.senderId == user.id;

    // If it's already opened, do nothing as per requirement
    if (message.status == SnapStatus.opened) {
      debugPrint('PROVE_DELETE: Snap already opened, ignoring tap');
      return;
    }

    // 1. Navigate to viewer
    debugPrint('PROVE_DELETE: Opening snap ${message.snapId} for viewing');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SnapViewerScreen(imageUrl: message.imageUrl!)),
    );

    // Only proceed with status update and storage deletion for received snaps
    if (!isMe) {
      try {
        final supabase = Supabase.instance.client;
        final String? imageUrl = message.imageUrl;

        debugPrint('PROVE_DELETE: --- START CLEANUP ---');
        debugPrint('PROVE_DELETE: Recipient ID: ${user.id}');
        debugPrint('PROVE_DELETE: Snap ID: ${message.snapId}');
        debugPrint('PROVE_DELETE: Recipient Row ID: ${message.id}');
        debugPrint('PROVE_DELETE: Original URL: $imageUrl');

        // 2. Extract file path correctly from image_url
        if (imageUrl != null && imageUrl.contains('/public/snaps/')) {
          // Robust path extraction: split by the bucket part and take everything after it
          // Then remove any query parameters if they exist
          String filePath = imageUrl.split('/public/snaps/').last;
          if (filePath.contains('?')) {
            filePath = filePath.split('?').first;
          }
          
          debugPrint('PROVE_DELETE: Extracted Path: "$filePath"');
          debugPrint('PROVE_DELETE: Path Length: ${filePath.length}');

          // 3. Delete from Supabase Storage
          try {
            debugPrint('PROVE_DELETE: Calling storage.from("snaps").remove(["$filePath"])');
            final List<FileObject> response = await supabase.storage.from('snaps').remove([filePath]);
            
            if (response.isNotEmpty) {
              debugPrint('PROVE_DELETE: ✅ SUCCESS: Storage removal returned objects. Count: ${response.length}');
              for (var f in response) {
                debugPrint('PROVE_DELETE: Removed object: ${f.name}');
              }
            } else {
              debugPrint('PROVE_DELETE: ⚠️ WARNING: Storage removal returned an EMPTY list. This usually means the file was NOT found or the DELETE policy blocked it.');
            }
          } catch (storageErr) {
            debugPrint('PROVE_DELETE: ❌ ERROR during storage.remove: $storageErr');
            if (storageErr.toString().contains('403') || storageErr.toString().contains('Permission denied')) {
              debugPrint('PROVE_DELETE: 🚨 PERMISSION DENIED: The current user (${user.id}) cannot delete this file. Check RLS DELETE policy on "snaps" bucket.');
            }
          }
        } else {
          debugPrint('PROVE_DELETE: ⚠️ ABORT: URL does not contain "/public/snaps/" or is null');
        }

        // 4. Update status in DB
        debugPrint('PROVE_DELETE: Updating DB records...');
        final now = DateTime.now().toIso8601String();
        
        // Update recipient record
        final recipientUpdate = await supabase
            .from('snap_recipients')
            .update({
              'status': 'opened', 
              'opened_at': now
            })
            .eq('id', message.id)
            .select();
        
        debugPrint('PROVE_DELETE: DB snap_recipients update: ${recipientUpdate.isNotEmpty ? 'SUCCESS' : 'FAILED'}');

        // Update main snap record to remove image URL reference
        if (message.snapId != null) {
          final snapUpdate = await supabase
              .from('snaps')
              .update({'image_url': null})
              .eq('id', message.snapId!)
              .select();
          debugPrint('PROVE_DELETE: DB snaps.image_url nullification: ${snapUpdate.isNotEmpty ? 'SUCCESS' : 'FAILED'}');
        }

        debugPrint('PROVE_DELETE: --- END CLEANUP ---');
        
        // Refresh local UI
        _loadMessages();
      } catch (e) {
        debugPrint('PROVE_DELETE: 🔥 CRITICAL EXCEPTION in _handleSnapTap: $e');
      }
    } else {
      debugPrint('PROVE_DELETE: Skipping deletion because viewer is the sender.');
    }
  }

  Widget _buildTextItem(SnapMessage message, bool isMe, bool isLastSent) {
    return _SwipeToReplyWrapper(
      onReply: () {
        debugPrint('REPLY_SET id=${message.id}');
        setState(() => _replyingTo = message);
      },
      child: _buildTextItemContent(message, isMe, isLastSent),
    );
  }

  Widget _buildTextItemContent(SnapMessage message, bool isMe, bool isLastSent) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onLongPress: () => _showReactionPickerOverlay(message, _bubbleKeys[message.id]!),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? primaryColor : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F1F1)),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.repliedToMessage != null)
                  _buildReplyBubble(message.repliedToMessage!, isMe),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.text ?? "",
                        style: TextStyle(
                          color: isMe ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestampShort(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: (isMe ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message.reactions.isNotEmpty)
            _buildReactionsDisplay(message, isMe),
          if (isMe && isLastSent)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  _getMessageStatusText(message),
                  key: ValueKey(_getMessageStatusText(message)),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBubble(SnapMessage repliedMsg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.black12 : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isMe ? Colors.white38 : Colors.green, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repliedMsg.senderId == Supabase.instance.client.auth.currentUser?.id ? "You" : widget.userName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.green,
            ),
          ),
          Text(
            repliedMsg.text ?? (repliedMsg.isSnap ? "Snap" : ""),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay(SnapMessage message, bool isMe) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;
    final reactions = message.reactions;
    
    // Group reactions by type
    final Map<String, int> reactionCounts = {};
    for (var r in reactions) {
      reactionCounts[r.reaction] = (reactionCounts[r.reaction] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: () {
        // Remove my reaction if I have one
        final hasMyReaction = reactions.any((r) => r.userId == user?.id);
        if (hasMyReaction) {
          _removeReaction(message);
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            // Distinguish between entry and exit animations
            final bool isEntrance = animation.status == AnimationStatus.forward || 
                                   animation.status == AnimationStatus.completed;

            if (isEntrance) {
              final scaleAnimation = TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
                TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
              ]).animate(animation);
              
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              );
            } else {
              // Smooth exit: simple shrink and fade
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            }
          },
          child: reactionCounts.isEmpty 
            ? const SizedBox.shrink(key: ValueKey('no_reactions'))
            : Container(
                key: ValueKey(message.id + reactionCounts.keys.join(',') + reactions.length.toString()),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactionCounts.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        "${e.key}${e.value > 1 ? " ${e.value}" : ""}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
        ),
      ),
    );
  }

  String _getMessageStatusText(SnapMessage message) {
    if (message.readAt != null) return "Seen";
    if (message.deliveredAt != null) return "Delivered";
    return "Sent";
  }

  String _formatTimestampShort(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  void _showReactionPickerOverlay(SnapMessage message, GlobalKey bubbleKey) {
    _reactionOverlay?.remove();
    _reactionOverlay = null;

    final RenderBox? renderBox = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    
    _reactionOverlay = OverlayEntry(
      builder: (context) => _ReactionPickerOverlay(
        offset: offset,
        onReactionSelected: (r) {
          _toggleReaction(message, r);
          _reactionOverlay?.remove();
          _reactionOverlay = null;
        },
        onDismiss: () {
          _reactionOverlay?.remove();
          _reactionOverlay = null;
        },
      ),
    );

    Overlay.of(context).insert(_reactionOverlay!);
  }

  Future<void> _toggleReaction(SnapMessage message, String reaction) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // --- OPTIMISTIC UI START ---
    final originalMessages = List<SnapMessage>.from(_messages);
    final msgIndex = _messages.indexWhere((m) => m.id == message.id);
    if (msgIndex == -1) return;

    final currentReactions = List<MessageReaction>.from(_messages[msgIndex].reactions);
    final existingReactionIndex = currentReactions.indexWhere((r) => r.userId == user.id);

    if (existingReactionIndex != -1) {
      currentReactions[existingReactionIndex] = MessageReaction(userId: user.id, reaction: reaction);
    } else {
      currentReactions.add(MessageReaction(userId: user.id, reaction: reaction));
    }

    setState(() {
      _messages[msgIndex] = _messages[msgIndex].copyWith(reactions: currentReactions);
    });
    // --- OPTIMISTIC UI END ---

    try {
      // Logic for picker: Always Add or Update (Upsert)
      await supabase.from('message_reactions').upsert({
        'message_id': message.id,
        'user_id': user.id,
        'reaction_type': reaction,
      }, onConflict: 'message_id,user_id');
      
      // We don't call _loadMessages() here to avoid flicker. 
      // Realtime will handle syncing other clients.
    } catch (e) {
      debugPrint("Error toggling reaction: $e");
      // Rollback on failure
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(originalMessages);
        });
      }
    }
  }

  Future<void> _removeReaction(SnapMessage message) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // --- OPTIMISTIC UI START ---
    final originalMessages = List<SnapMessage>.from(_messages);
    final msgIndex = _messages.indexWhere((m) => m.id == message.id);
    if (msgIndex == -1) return;

    final currentReactions = List<MessageReaction>.from(_messages[msgIndex].reactions);
    currentReactions.removeWhere((r) => r.userId == user.id);

    setState(() {
      _messages[msgIndex] = _messages[msgIndex].copyWith(reactions: currentReactions);
    });
    // --- OPTIMISTIC UI END ---

    try {
      await supabase
          .from('message_reactions')
          .delete()
          .match({'message_id': message.id, 'user_id': user.id});
      
      // No _loadMessages() here either.
    } catch (e) {
      debugPrint("Error removing reaction: $e");
      // Rollback on failure
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(originalMessages);
        });
      }
    }
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: Colors.green, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingTo!.senderId == Supabase.instance.client.auth.currentUser?.id ? "You" : widget.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                          ),
                          Text(
                            _replyingTo!.text ?? (_replyingTo!.isSnap ? "Snap" : ""),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Camera Icon
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.camera_alt_rounded, 
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        size: 22,
                      ), 
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
                      }
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Text Input Pill
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: "Send a Chat",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.grey[500], 
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        filled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send Button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: IconButton(
                        icon: Icon(
                          Icons.send_rounded, 
                          color: primaryColor,
                          size: 28,
                        ),
                        onPressed: hasText ? _sendMessage : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReplyWrapper({required this.child, required this.onReply});

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> with TickerProviderStateMixin {
  late AnimationController _dragController;
  late Animation<Offset> _dragAnimation;
  double _dragX = 0;
  bool _isTriggered = false;
  static const double _threshold = 40.0;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dragAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_dragController);
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    debugPrint('SWIPE_START');
    _isTriggered = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx < 0 && _dragX <= 0) return; // Only right swipe

    setState(() {
      _dragX += details.delta.dx;
      if (_dragX < 0) _dragX = 0;
      if (_dragX > 70) _dragX = 70; // Cap visual drag
      
      debugPrint('SWIPE_PROGRESS x=$_dragX');

      if (_dragX >= _threshold && !_isTriggered) {
        _isTriggered = true;
        HapticFeedback.lightImpact();
        debugPrint('SWIPE_TRIGGERED');
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isTriggered) {
      widget.onReply();
    }
    
    // Animate back
    _dragAnimation = Tween<Offset>(
      begin: Offset(_dragX, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dragController, curve: Curves.easeOut));
    
    _dragX = 0;
    _dragController.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply Icon background
          Positioned(
            left: -30,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: (_dragX / _threshold).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: (_dragX / _threshold).clamp(0.8, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.reply, color: Colors.green, size: 20),
                  ),
                ),
              ),
            ),
          ),
          
          // The message bubble
          AnimatedBuilder(
            animation: _dragAnimation,
            builder: (context, child) {
              final offset = _dragController.isAnimating ? _dragAnimation.value : Offset(_dragX, 0);
              return Transform.translate(
                offset: offset,
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReactionPickerOverlay extends StatefulWidget {
  final Offset offset;
  final Function(String) onReactionSelected;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.offset,
    required this.onReactionSelected,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          left: widget.offset.dx.clamp(20, MediaQuery.of(context).size.width - 250),
          top: widget.offset.dy - 60,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ["❤️", "😂", "🔥", "😮", "👍", "👎"].map((r) => GestureDetector(
                      onTap: () => widget.onReactionSelected(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(r, style: const TextStyle(fontSize: 24)),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
