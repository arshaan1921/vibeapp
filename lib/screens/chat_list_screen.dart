import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/realtime_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Stream<List<Conversation>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    _refreshStream();
  }

  void _refreshStream() {
    if (mounted) {
      setState(() {
        _conversationsStream = chatService.getConversationsStream();
      });
    }
  }

  Future<void> _handleRefresh() async {
    _refreshStream();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _showDeleteConfirmation(BuildContext context, Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete the conversation with ${conversation.otherUserName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await chatService.deleteConversation(conversation.id);
                _refreshStream(); 
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    const whatsappGreen = Color(0xFF25D366);
    const v1beRed = Color(0xFFFF3B30);

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: StreamBuilder<List<Conversation>>(
          stream: _conversationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Error loading chats. Please try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final conversations = snapshot.data ?? [];

            if (conversations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No conversations yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: conversations.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 85,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final hasUnread = conversation.unreadCount > 0;
                final isMe = conversation.lastMessageSenderId == currentUserId;

                return ListTile(
                  onTap: () async {
                    await chatService.markAsRead(conversation.id);
                    if (!mounted) return;
                    _refreshStream();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: conversation.id,
                          otherUserId: conversation.otherUserId,
                          otherUserName: conversation.otherUserName,
                          otherUserAvatar: conversation.otherUserAvatar,
                        ),
                      ),
                    );
                    _refreshStream();
                  },
                  onLongPress: () => _showDeleteConfirmation(context, conversation),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: conversation.otherUserAvatar != null &&
                                conversation.otherUserAvatar!.isNotEmpty
                            ? NetworkImage(conversation.otherUserAvatar!)
                            : null,
                        child: conversation.otherUserAvatar == null ||
                                conversation.otherUserAvatar!.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 30)
                            : null,
                      ),
                      StreamBuilder<AppUser?>(
                        stream: RealtimeService().getUserPresenceStream(conversation.otherUserId),
                        builder: (context, presenceSnapshot) {
                          final user = presenceSnapshot.data;
                          final isOnline = user?.isOnline ?? false;
                          
                          if (!isOnline) return const SizedBox.shrink();
                          
                          return Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: whatsappGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? theme.scaffoldBackgroundColor : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  title: Text(
                    conversation.otherUserName,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        if (isMe) ...[
                          _buildStatusIcon(conversation.lastMessageStatus ?? 'sent', v1beRed),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 15,
                              color: hasUnread 
                                  ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black87) 
                                  : Colors.grey.shade600,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            color: hasUnread ? whatsappGreen : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (hasUnread)
                        Container(
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: whatsappGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation.unreadCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 22), 
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status, Color readColor) {
    if (status == 'read') {
      return Icon(Icons.done_all, size: 16, color: readColor);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();

    if (now.year == localDate.year &&
        now.month == localDate.month &&
        now.day == localDate.day) {
      return DateFormat('h:mm a').format(localDate).toLowerCase();
    }

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (yesterday.year == localDate.year &&
        yesterday.month == localDate.month &&
        yesterday.day == localDate.day) {
      return 'Yesterday';
    }

    if (now.difference(localDate).inDays < 7) {
      return DateFormat('EEEE').format(localDate);
    }

    return DateFormat('dd/MM/yy').format(localDate);
  }
}
