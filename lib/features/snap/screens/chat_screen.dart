import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../utils/image_utils.dart';
import '../models/snap_message.dart';
import 'camera_screen.dart';
import 'snap_viewer_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadChatData();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
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

      await _loadMessages();
    } catch (e) {
      debugPrint("Error loading chat data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

      // Fetch regular messages
      final messagesResponse = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.${user.id},receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.${user.id})')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> receivedSnaps = List<Map<String, dynamic>>.from(receivedSnapsRes as List);
      final List<Map<String, dynamic>> sentSnaps = List<Map<String, dynamic>>.from(sentSnapsRes as List);
      final List<Map<String, dynamic>> msgsData = List<Map<String, dynamic>>.from(messagesResponse as List);

      if (msgsData.isNotEmpty) {
        debugPrint('DEBUG_MSG_KEYS: ${msgsData.first.keys.toList()}');
        debugPrint('DEBUG_MSG_FULL: ${msgsData.first}');
      }

      debugPrint('CHAT_SCREEN receivedSnaps=${receivedSnaps.length}');
      debugPrint('CHAT_SCREEN sentSnaps=${sentSnaps.length}');
      debugPrint('CHAT_LOAD messages count=${msgsData.length}');
      debugPrint('CHAT_SCREEN messages returned=${msgsData.length}');

      final List<SnapMessage> allMessages = [];

      // Combine and process snaps
      final allSnaps = [...receivedSnaps, ...sentSnaps];

      for (var s in allSnaps) {
        final snap = s['snaps'];
        debugPrint('SNAP_ITEM: $s');
        debugPrint('SNAP_IMAGE_URL: ${snap['image_url']}');
        
        final msg = SnapMessage(
          id: s['id'],
          snapId: s['snap_id'],
          senderId: snap['sender_id'],
          receiverId: s['recipient_id'],
          imageUrl: snap['image_url'],
          caption: snap['caption'],
          createdAt: DateTime.parse(s['delivered_at'] ?? s['created_at'] ?? snap['created_at']),
          status: _parseSnapStatus(s['status']),
        );
        
        debugPrint('CHAT_ITEM_TYPE: ${msg.isSnap ? 'snap' : 'text'}');
        allMessages.add(msg);
      }

      for (var m in msgsData) {
        allMessages.add(SnapMessage(
          id: m['id'],
          senderId: m['sender_id'],
          receiverId: m['receiver_id'],
          text: m['message'],
          createdAt: DateTime.parse(m['created_at']),
        ));
      }

      allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(allMessages);
        });
      }

      // Mark text messages as read if we have any incoming ones
      final hasUnreadMessages = msgsData.any((m) => m['receiver_id'] == user.id && m['read_at'] == null);
      if (hasUnreadMessages) {
        _markMessagesAsRead();
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
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
    
    _textController.clear();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('CHAT_SEND inserting: $text');
      await supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.userId,
        'message': text,
      });

      // Realtime will pick it up
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[100],
              backgroundImage: ImageUtils.getImageProvider(_avatarUrl),
              child: _avatarUrl == null
                  ? Icon(Icons.person, color: Colors.grey[400], size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Text(
                    _isOnline ? "Online" : "Recently active",
                    style: TextStyle(fontSize: 11, color: _isOnline ? Colors.green : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                    return _buildMessageBubble(message, isMe);
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SnapMessage message, bool isMe) {
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
            _buildTextItem(message, isMe),
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
          color: isMe ? const Color(0xFFF8F8F8) : const Color(0xFFEEEEEE),
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
              style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSnapTap(SnapMessage message) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || message.imageUrl == null) return;

    final bool isMe = message.senderId == user.id;

    // If it's already opened, do nothing as per requirement
    if (message.status == SnapStatus.opened) {
      debugPrint('SNAP_OPEN: Snap already opened, ignoring tap');
      return;
    }

    // 1. Navigate to viewer
    debugPrint('SNAP_OPEN: Opening snap ${message.snapId}');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SnapViewerScreen(imageUrl: message.imageUrl!)),
    );

    // Only proceed with status update and storage deletion for received snaps
    if (!isMe) {
      try {
        final supabase = Supabase.instance.client;

        // 2. Extract file path correctly from image_url
        // URL format: .../public/snaps/USER_ID/FILENAME.jpg
        final String filePath = message.imageUrl!.split('/public/snaps/').last;
        debugPrint('SNAP_DELETE: Removing storage file $filePath');

        // 3. Delete from Supabase Storage
        await supabase.storage.from('snaps').remove([filePath]);

        // 4. Update status in DB (Do not delete rows)
        debugPrint('SNAP_DELETE: Updating snap_recipients status to opened');
        await supabase
            .from('snap_recipients')
            .update({
              'status': 'opened', 
              'opened_at': DateTime.now().toIso8601String()
            })
            .eq('id', message.id);

        debugPrint('SNAP_DELETE: Success');
        
        // Refresh local UI to show "Opened" instead of deleting
        _loadMessages();
      } catch (e) {
        debugPrint('SNAP_DELETE_ERROR: $e');
      }
    }
  }

  Widget _buildTextItem(SnapMessage message, bool isMe) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? primaryColor : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
        ),
      ),
      child: Text(
        message.text ?? "",
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
    );
  }

  String _formatTimestampShort(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
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
        child: Row(
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
      ),
    );
  }
}
