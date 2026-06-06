import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../utils/image_utils.dart';
import '../../../screens/profile.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';
import '../../../screens/friend_requests_screen.dart';

class SnapChatsScreen extends StatefulWidget {
  const SnapChatsScreen({super.key});

  @override
  State<SnapChatsScreen> createState() => _SnapChatsScreenState();
}

class _SnapChatsScreenState extends State<SnapChatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _chats = [];
  int _pendingRequestsCount = 0;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
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

    _realtimeChannel = supabase.channel('public:chats_updates');
    
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'snap_recipients',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch user profile for header
      final profileRes = await supabase
          .from('profiles')
          .select('avatar_url, username')
          .eq('id', user.id)
          .maybeSingle();
      
      if (mounted) setState(() => _profileData = profileRes);

      // 1.5. Fetch pending friend requests count
      final requestsRes = await supabase
          .from('friend_requests')
          .select('id')
          .eq('receiver_id', user.id)
          .eq('status', 'pending');
      
      if (mounted) setState(() => _pendingRequestsCount = (requestsRes as List).length);

      // 2. Fetch recent messages and snaps
      final messagesRes = await supabase
          .from('messages')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(50);

      // Fetch received snaps
      final receivedSnapsRes = await supabase
          .from('snap_recipients')
          .select('*, snaps!inner(*)')
          .eq('recipient_id', user.id)
          .order('delivered_at', ascending: false)
          .limit(50);

      // Fetch sent snaps
      final sentSnapsRes = await supabase
          .from('snaps')
          .select('*, snap_recipients!inner(*)')
          .eq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> rawMessages = List<Map<String, dynamic>>.from(messagesRes as List);
      final List<Map<String, dynamic>> receivedSnaps = List<Map<String, dynamic>>.from(receivedSnapsRes as List);
      final List<Map<String, dynamic>> sentSnaps = List<Map<String, dynamic>>.from(sentSnapsRes as List);

      debugPrint('CHAT_LOAD messages count=${rawMessages.length}');

      // Collect all unique user IDs we need profiles for
      final Set<String> userIds = {};
      for (var m in rawMessages) {
        final senderId = m['sender_id']?.toString();
        final receiverId = m['receiver_id']?.toString();
        
        if (senderId != null) userIds.add(senderId);
        if (receiverId != null) userIds.add(receiverId);
      }
      for (var s in receivedSnaps) {
        final senderId = s['snaps']?['sender_id']?.toString();
        if (senderId != null) userIds.add(senderId);
      }
      for (var s in sentSnaps) {
        final recipients = s['snap_recipients'] as List?;
        if (recipients != null) {
          for (var r in recipients) {
            final recipientId = r['recipient_id']?.toString();
            if (recipientId != null) userIds.add(recipientId);
          }
        }
      }
      userIds.remove(user.id);

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        final profilesRes = await supabase
            .from('profiles')
            .select('id, username, name, avatar_url')
            .inFilter('id', userIds.toList());
        
        for (var p in (profilesRes as List)) {
          profileMap[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      final Map<String, Map<String, dynamic>> interactions = {};

      // Process Messages
      for (var m in rawMessages) {
        final senderId = m['sender_id']?.toString();
        final receiverId = m['receiver_id']?.toString();
        final otherId = senderId == user.id ? receiverId : senderId;
        
        if (otherId == null) continue;
        final otherProfile = profileMap[otherId];
        if (otherProfile == null) continue;

        final rawTime = m['created_at']?.toString();
        if (rawTime == null) continue;
        
        final timestamp = DateTime.parse(rawTime);
        if (!interactions.containsKey(otherId) || 
            timestamp.isAfter(DateTime.parse(interactions[otherId]!['raw_time']))) {
          
          interactions[otherId] = {
            'id': otherId,
            'name': otherProfile['name'] ?? otherProfile['username'] ?? 'User',
            'username': otherProfile['username'] ?? 'user',
            'avatar_url': otherProfile['avatar_url'],
            'last_activity': senderId == user.id ? "You: ${m['message'] ?? ''}" : (m['message'] ?? ''),
            'timestamp': _formatTimestamp(timestamp),
            'raw_time': rawTime,
            'is_unread': senderId != user.id && (m['read_at'] == null),
            'type': 'message',
          };
        }
      }

      // Process Snaps (Received)
      for (var s in receivedSnaps) {
        final snapObj = s['snaps'] as Map<String, dynamic>?;
        if (snapObj == null) continue;
        
        final otherId = snapObj['sender_id']?.toString();
        if (otherId == null) continue;
        
        final otherProfile = profileMap[otherId];
        if (otherProfile == null) continue;

        // Fallback: Use created_at if delivered_at is null
        final rawTime = (s['delivered_at'] ?? s['created_at'] ?? snapObj['created_at'])?.toString();
        if (rawTime == null) continue;

        final timestamp = DateTime.parse(rawTime);
        if (!interactions.containsKey(otherId) || 
            timestamp.isAfter(DateTime.parse(interactions[otherId]!['raw_time']))) {
          
          interactions[otherId] = {
            'id': otherId,
            'name': otherProfile['name'] ?? otherProfile['username'] ?? 'User',
            'username': otherProfile['username'] ?? 'user',
            'avatar_url': otherProfile['avatar_url'],
            'last_activity': s['status'] == 'opened' ? 'Opened' : 'Received a snap',
            'timestamp': _formatTimestamp(timestamp),
            'raw_time': rawTime,
            'is_unread': s['status'] != 'opened',
            'type': 'snap',
            'status': s['status'],
          };
        }
      }

      // Process Snaps (Sent)
      for (var s in sentSnaps) {
        final recipients = s['snap_recipients'] as List?;
        if (recipients == null) continue;
        
        for (var r in recipients) {
          final otherId = r['recipient_id']?.toString();
          if (otherId == null) continue;
          
          final otherProfile = profileMap[otherId];
          if (otherProfile == null) continue;

          final rawTime = s['created_at']?.toString();
          if (rawTime == null) continue;

          final timestamp = DateTime.parse(rawTime);
          if (!interactions.containsKey(otherId) || 
              timestamp.isAfter(DateTime.parse(interactions[otherId]!['raw_time']))) {
            
            interactions[otherId] = {
              'id': otherId,
              'name': otherProfile['name'] ?? otherProfile['username'] ?? 'User',
              'username': otherProfile['username'] ?? 'user',
              'avatar_url': otherProfile['avatar_url'],
              'last_activity': r['status'] == 'opened' ? 'Opened your snap' : 'Delivered',
              'timestamp': _formatTimestamp(timestamp),
              'raw_time': rawTime,
              'is_unread': false,
              'type': 'snap',
              'status': r['status'],
            };
          }
        }
      }

      final chatList = interactions.values.toList();
      chatList.sort((a, b) => b['raw_time'].compareTo(a['raw_time']));

      if (mounted) {
        setState(() {
          _chats = chatList;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint("Error loading integrated chats: $e");
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[100],
                backgroundImage: ImageUtils.getImageProvider(_profileData?['avatar_url']),
                child: _profileData?['avatar_url'] == null
                    ? Icon(Icons.person, color: Colors.grey[400], size: 20)
                    : null,
              ),
            ),
          ),
        ),
        title: const Text(
          "Chats",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen())).then((_) => _loadData());
                  },
                ),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_pendingRequestsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _chats.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _chats.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 80,
                        color: Color(0xFFF1F1F1),
                      ),
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        return _buildChatTile(chat);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
        },
        backgroundColor: const Color(0xFF00E676),
        elevation: 4,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final isUnread = chat['is_unread'] as bool? ?? false;
    final isSnap = chat['type'] == 'snap';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              userId: chat['id'],
              userName: chat['name'],
            ),
          ),
        ).then((_) => _loadData());
      },
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[100],
        backgroundImage: ImageUtils.getImageProvider(chat['avatar_url']),
        child: chat['avatar_url'] == null
            ? Icon(Icons.person, color: Colors.grey[300], size: 30)
            : null,
      ),
      title: Text(
        chat['name'],
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (isSnap) ...[
              Icon(
                chat['last_activity'].contains('Received') || chat['last_activity'] == 'Opened' 
                  ? Icons.play_arrow_rounded 
                  : Icons.play_arrow_outlined,
                size: 14,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                "${chat['last_activity']} • ${chat['timestamp']}",
                style: TextStyle(
                  color: isUnread ? Colors.black : Colors.grey[600],
                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      trailing: isUnread
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            )
          : const Icon(Icons.chevron_right, color: Color(0xFFE0E0E0), size: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 100,
            color: Colors.grey[100],
          ),
          const SizedBox(height: 24),
          const Text(
            "No conversations yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Send your first snap and start a conversation.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
