import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/realtime_service.dart';
import '../services/presence_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    chatService.markAsRead(widget.conversationId);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      final XFile? media = isVideo 
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source, imageQuality: 70);

      if (media != null) {
        setState(() => _isUploading = true);
        
        final file = File(media.path);
        final path = 'conversations/${widget.conversationId}/${isVideo ? 'videos' : 'images'}';
        
        final mediaUrl = await chatService.uploadMedia(file, path);
        
        if (mediaUrl != null) {
          await chatService.sendMessage(
            widget.conversationId, 
            '', 
            mediaUrl: mediaUrl, 
            mediaType: isVideo ? 'video' : 'image'
          );
          _scrollToBottom();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload media')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking media: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Image from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.red),
                title: const Text('Video from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, isVideo: true);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    
    try {
      await chatService.sendMessage(widget.conversationId, text);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF0F2F5),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 1,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.9),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar!)
                  : null,
              backgroundColor: Colors.white24,
              child: (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<AppUser?>(
                stream: RealtimeService().getUserPresenceStream(widget.otherUserId),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final statusText = PresenceService.formatLastSeen(user?.lastSeen, user?.isOnline ?? false);
                  final isOnline = statusText == 'Online';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (isOnline)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11, 
                              color: isOnline ? Colors.white : Colors.white70,
                              fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_isUploading || _isSending)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: chatService.getMessagesStream(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];
                  messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                  // 🚀 PROACTIVE READ RECEIPT: 
                  // If we detect new unread incoming messages, mark them read instantly
                  final hasUnreadIncoming = messages.any((m) => 
                    m.senderId == widget.otherUserId && m.status != 'read');
                  
                  if (hasUnreadIncoming) {
                    Future.microtask(() => chatService.markAsRead(widget.conversationId));
                  }

                  // Auto scroll when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId != widget.otherUserId;

                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                        theme: theme,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    final bool canSend = _messageController.text.trim().isNotEmpty && !_isSending && !_isUploading;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: theme.primaryColor),
            onPressed: (_isUploading || _isSending) ? null : _showAttachmentMenu,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canSend ? _sendMessage : null,
            child: CircleAvatar(
              backgroundColor: canSend ? theme.primaryColor : Colors.grey,
              radius: 24,
              child: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final ThemeData theme;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const v1beRed = Color(0xFFFF3B30);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              _buildMediaContent(context),
            if (message.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 15, 
                    color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    DateFormat.Hm().format(message.createdAt),
                    style: TextStyle(
                      fontSize: 10, 
                      color: isMe ? Colors.white70 : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(message.status, v1beRed),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status, Color readColor) {
    if (status == 'read') {
      return Icon(Icons.done_all, size: 16, color: readColor);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 16, color: Colors.white60);
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.white60);
    }
  }

  Widget _buildMediaContent(BuildContext context) {
    if (message.mediaType == 'video') {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: _VideoMessagePlayer(url: message.mediaUrl!),
      );
    } else {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, message.mediaUrl!),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
          body: Center(
            child: CachedNetworkImage(
              imageUrl: url,
              placeholder: (context, url) => const CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoMessagePlayer extends StatefulWidget {
  final String url;
  const _VideoMessagePlayer({required this.url});

  @override
  State<_VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<_VideoMessagePlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 50,
            ),
            onPressed: () {
              setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              });
            },
          ),
        ],
      ),
    );
  }
}
