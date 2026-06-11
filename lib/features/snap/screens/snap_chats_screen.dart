import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../main.dart';
import '../../../utils/image_utils.dart';
import '../../../screens/profile.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';
import '../../../screens/streak_achievement_screen.dart';
import '../../../screens/friend_requests_screen.dart';

class SnapChatsScreen extends StatefulWidget {
  const SnapChatsScreen({super.key});

  @override
  State<SnapChatsScreen> createState() => _SnapChatsScreenState();
}

class _SnapChatsScreenState extends State<SnapChatsScreen> with RouteAware {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _chats = [];
  Map<String, int> _streakMap = {};
  Map<String, String> _streakIdMap = {};
  int _pendingRequestsCount = 0;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;
  static bool _hasCleanedUpThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
    tabIndexNotifier.addListener(_onTabChanged);
    
    // Auto refresh every 30 seconds as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && tabIndexNotifier.value == 3) {
        _loadData();
      }
    });
  }

  Future<void> _cleanupAbandonedSnaps() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      debugPrint('CLEANUP: Checking for abandoned snaps...');
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      // Find old snaps SENT BY ME that still have image files
      // These are "abandoned" if they were never opened or just old system junk
      final oldSentSnapsRes = await supabase
          .from('snaps')
          .select('id, image_url')
          .eq('sender_id', user.id)
          .not('image_url', 'is', null)
          .lt('created_at', thirtyDaysAgo);

      final List<dynamic> oldSnaps = oldSentSnapsRes as List;
      if (oldSnaps.isEmpty) {
        debugPrint('CLEANUP: No abandoned snaps found');
        return;
      }

      for (var snap in oldSnaps) {
        final snapId = snap['id'];
        final imageUrl = snap['image_url'] as String?;
        
        if (imageUrl != null && imageUrl.contains('/public/snaps/')) {
          final String filePath = imageUrl.split('/public/snaps/').last;
          
          // 1. Delete from storage
          try {
            await supabase.storage.from('snaps').remove([filePath]);
          } catch (e) {
            debugPrint('CLEANUP: Storage removal failed for $filePath: $e');
          }
          
          // 2. Nullify image_url in DB
          await supabase.from('snaps').update({'image_url': null}).eq('id', snapId);
          
          // 3. Mark all recipients as 'opened' if they weren't, to clear their UI
          await supabase
              .from('snap_recipients')
              .update({'status': 'opened', 'opened_at': thirtyDaysAgo})
              .eq('snap_id', snapId)
              .isFilter('opened_at', null);
              
          debugPrint('CLEANUP: Processed snap $snapId');
        }
      }
    } catch (e) {
      debugPrint('CLEANUP_ERROR: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    tabIndexNotifier.removeListener(_onTabChanged);
    routeObserver.unsubscribe(this);
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped off, and this route shows up again.
    debugPrint('CHAT_SCREEN: Returned to screen, refreshing...');
    _loadData();
  }

  void _onTabChanged() {
    if (tabIndexNotifier.value == 3) {
      debugPrint('CHAT_SCREEN: Tab selected, refreshing data');
      _loadData();
    }
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
    // Abandoned Snap Cleanup (Once per app session)
    if (!_hasCleanedUpThisSession) {
      _hasCleanedUpThisSession = true;
      _cleanupAbandonedSnaps();
    }

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

      // 1.7. Fetch streaks
      Map<String, int> streakMap = {};
      Map<String, String> streakIdMap = {};
      try {
        final streaksRes = await supabase
            .from('snap_streaks')
            .select('id, user1_id, user2_id, streak_count')
            .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
        
        final List<dynamic> streaksData = List<dynamic>.from(streaksRes as List);
        debugPrint('Loaded streaks: ${streaksData.length}');

        for (var row in streaksData) {
          final u1 = row['user1_id'] as String;
          final u2 = row['user2_id'] as String;
          final friendId = (u1 == user.id) ? u2 : u1;
          final count = row['streak_count'] as int;
          streakMap[friendId] = count;
          streakIdMap[friendId] = row['id'] as String;
          debugPrint('Friend $friendId streak: $count');
        }
      } catch (e) {
        debugPrint("CHAT_SCREEN: Streaks fetch error: $e");
      }

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
          _streakMap = streakMap;
          _streakIdMap = streakIdMap;
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
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
                backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                backgroundImage: ImageUtils.getImageProvider(_profileData?['avatar_url']),
                child: _profileData?['avatar_url'] == null
                    ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.grey[400], size: 20)
                    : null,
              ),
            ),
          ),
        ),
        title: Text(
          "Chats",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
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
                  icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurface, size: 28),
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
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 80,
                        color: isDark ? Colors.white10 : const Color(0xFFF1F1F1),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = chat['is_unread'] as bool? ?? false;
    final isSnap = chat['type'] == 'snap';
    final streak = _streakMap[chat['id']] ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
        backgroundImage: ImageUtils.getImageProvider(chat['avatar_url']),
        child: chat['avatar_url'] == null
            ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.grey[300], size: 30)
            : null,
      ),
      title: Text(
        (streak >= 100 ? "🏆 " : "") + chat['name'],
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
          fontSize: 16,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
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
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13),
                  children: [
                    TextSpan(
                      text: chat['last_activity'],
                      style: TextStyle(
                        color: isUnread 
                          ? (isDark ? Colors.white : Colors.black) 
                          : (isDark ? Colors.white38 : Colors.grey[600]),
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    TextSpan(
                      text: " • ",
                      style: TextStyle(color: isDark ? Colors.white12 : Colors.grey[400]),
                    ),
                    TextSpan(
                      text: chat['timestamp'],
                      style: TextStyle(
                        color: isUnread 
                          ? (isDark ? Colors.white : Colors.black) 
                          : (isDark ? Colors.white38 : Colors.grey[600]),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (streak > 0) ...[
                      TextSpan(
                        text: " • ",
                        style: TextStyle(color: isDark ? Colors.white12 : Colors.grey[400]),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () {
                            final streakId = _streakIdMap[chat['id']];
                            if (streakId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StreakAchievementScreen(
                                    streakId: streakId,
                                    friendName: chat['name'],
                                    currentStreak: streak,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            "${streak}🔥",
                            style: TextStyle(
                              color: isUnread 
                                ? (isDark ? Colors.white : Colors.black) 
                                : (isDark ? Colors.white38 : Colors.grey[600]),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
          : Icon(Icons.chevron_right, color: isDark ? Colors.white10 : const Color(0xFFE0E0E0), size: 20),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 100,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          ),
          const SizedBox(height: 24),
          Text(
            "No conversations yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
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
