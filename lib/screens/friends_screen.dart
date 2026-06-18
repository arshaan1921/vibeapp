import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_profile.dart';
import '../widgets/streak_badge.dart';
import '../features/snap/models/streak.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = [];
  Map<String, SnapStreak> _streakMap = {};
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
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

    _realtimeChannel = supabase.channel('public:friends_streaks_updates');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'snap_streaks',
      callback: (payload) {
        _fetchFriends();
      },
    ).subscribe();
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('friends')
          .select('user1_id, user2_id, profiles!user1_id(id, username, name, avatar_url), profiles2:profiles!user2_id(id, username, name, avatar_url)')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

      // Fetch streaks
      Map<String, SnapStreak> streakMap = {};
      try {
        final streaksRes = await supabase
            .from('snap_streaks')
            .select('*, id, user1_id, user2_id, streak_count, broken_streak_count, is_restoreable, restore_deadline, last_exchange_at')
            .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

        final List<dynamic> streaksData = List<dynamic>.from(streaksRes as List);
        debugPrint('Loaded streaks: ${streaksData.length}');

        for (var row in streaksData) {
          final u1 = row['user1_id'] as String;
          final u2 = row['user2_id'] as String;
          final friendId = (u1 == user.id) ? u2 : u1;
          final streak = SnapStreak.fromMap(row);
          streakMap[friendId] = streak;
          debugPrint('STREAK_DEBUG: friendId=$friendId, streakId=${streak.id}, streakCount=${streak.streakCount}, brokenStreakCount=${streak.brokenStreakCount}, isRestoreable=${streak.isRestoreable}, canBeRestored=${streak.canBeRestored}');
        }
      } catch (e) {
        debugPrint("FRIENDS_SCREEN: Streaks fetch error: $e");
      }

      if (mounted) {
        setState(() {
          _friends = (response as List).map((item) {
            final isUser1 = item['user1_id'] == user.id;
            return Map<String, dynamic>.from(isUser1 ? item['profiles2'] : item['profiles']);
          }).toList();
          _streakMap = streakMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friends: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("FRIENDS"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFriends,
              child: _friends.isEmpty
                  ? const _EmptyState(
                      icon: Icons.group_add_outlined,
                      message: "No friends yet",
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _friends.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = _friends[index];
                        final avatarUrl = user['avatar_url'];
                        final streakData = _streakMap[user['id']];
                        final streak = streakData?.streakCount ?? 0;
                        final brokenStreak = streakData?.brokenStreakCount ?? 0;
                        final canBeRestored = streakData?.canBeRestored ?? false;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: avatarUrl != null && avatarUrl != ''
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl == ''
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(user["name"] ?? user["username"] ?? "User",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              if (streakData != null) ...[
                                const SizedBox(width: 4),
                                StreakBadge(streakData: streakData, fontSize: 14),
                              ],
                            ],
                          ),
                          subtitle: Text("@${user["username"] ?? ""}",
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicProfileScreen(
                                    userId: user['id']),
                              ),
                            ).then((_) => _fetchFriends());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
