import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'answer_view_screen.dart';
import '../services/block_service.dart';

class LikesActivityScreen extends StatefulWidget {
  const LikesActivityScreen({super.key});

  @override
  State<LikesActivityScreen> createState() => _LikesActivityScreenState();
}

class _LikesActivityScreenState extends State<LikesActivityScreen> {
  List<Map<String, dynamic>> _likes = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _likes = _likes.where((item) => !blockService.isBlocked(item['source_user'])).toList();
      });
    }
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchLikes();
  }

  void _subscribeToRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = supabase.channel('likes_realtime');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) async {
        if (payload.newRecord['type'] != 'like') return;

        if (payload.eventType == PostgresChangeEvent.insert) {
          try {
            // Fetch profile for the new like
            final senderId = payload.newRecord['source_user'];
            if (blockService.isBlocked(senderId)) return;

            final profileRes = await supabase
                .from('profiles')
                .select('id, username, avatar_url')
                .eq('id', senderId)
                .single();

            if (mounted) {
              setState(() {
                final newLike = Map<String, dynamic>.from(payload.newRecord);
                newLike['profiles'] = profileRes;
                
                // Prevent duplicates
                _likes.removeWhere((item) => item['id'] == newLike['id']);
                _likes.insert(0, newLike);
              });
            }
          } catch (e) {
            debugPrint("Error fetching profile for realtime like: $e");
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          if (mounted) {
            setState(() {
              final index = _likes.indexWhere((item) => item['id'] == payload.newRecord['id']);
              if (index != -1) {
                _likes[index]['seen'] = payload.newRecord['seen'];
              }
            });
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          if (mounted) {
            setState(() {
              _likes.removeWhere((item) => item['id'] == payload.oldRecord['id']);
            });
          }
        }
      },
    );

    _realtimeChannel!.subscribe();
  }

  Future<void> markLikesAsRead() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Mark all unread like notifications as seen
      await supabase
          .from('notifications')
          .update({'seen': true})
          .eq('user_id', user.id)
          .eq('type', 'like')
          .eq('seen', false);
    } catch (e) {
      debugPrint("Error marking as read on exit: $e");
    }
  }

  Future<void> _fetchLikes() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      // Step 1: Fetch notifications for this category
      final List<dynamic> notifications = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .eq('type', 'like')
          .order('created_at', ascending: false);

      if (notifications.isEmpty) {
        if (mounted) {
          setState(() {
            _likes = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Step 2: Extract unique source_user IDs
      final List<String> sourceUserIds = notifications
          .where((n) => n['source_user'] != null)
          .map((n) => n['source_user'] as String)
          .toSet()
          .toList();

      // Step 3: Fetch profile data for senders
      Map<String, dynamic> profileMap = {};
      if (sourceUserIds.isNotEmpty) {
        final List<dynamic> profiles = await supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', sourceUserIds);
        profileMap = {for (var p in profiles) p['id']: p};
      }

      // Step 4: Merge profile data
      final List<Map<String, dynamic>> mergedLikes = notifications
          .where((n) => !blockService.isBlocked(n['source_user']))
          .map((n) {
            final notification = Map<String, dynamic>.from(n);
            notification['profiles'] = profileMap[n['source_user']];
            return notification;
          }).toList();

      if (mounted) {
        setState(() {
          _likes = mergedLikes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching likes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String timestamp) {
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

    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await markLikesAsRead();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("LIKES"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              await markLikesAsRead();
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchLikes,
                child: _likes.isEmpty
                    ? Center(
                        child: Text("No likes yet.", 
                          style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _likes.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (context, index) {
                          final item = _likes[index];
                          final sender = item['profiles'] as Map<String, dynamic>?;
                          final username = sender?['username'] ?? "User";
                          final avatarUrl = sender?['avatar_url'];
                          
                          // New notifications highlighted
                          final bool isNew = item['seen'] == false;

                          return Container(
                            color: isNew 
                              ? (isDark ? Colors.blueAccent.withOpacity(0.1) : const Color(0xFFEAF3FF)) 
                              : Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                                backgroundImage: (avatarUrl != null && avatarUrl != '') ? NetworkImage(avatarUrl) : null,
                                child: (avatarUrl == null || avatarUrl == '') ? Icon(Icons.person, color: theme.iconTheme.color) : null,
                              ),
                              title: RichText(
                                text: TextSpan(
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: "@$username",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: " liked your answer"),
                                  ],
                                ),
                              ),
                              subtitle: Text(
                                _formatTime(item['created_at']),
                                style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AnswerViewScreen(
                                      answerId: item['source_id'].toString(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
