import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';
import '../services/block_service.dart';
import '../utils/image_utils.dart';
import '../features/snap/models/streak.dart';
import '../utils/premium_utils.dart';

class FriendsListScreen extends StatefulWidget {
  final String? userId;
  const FriendsListScreen({super.key, this.userId});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  List<Map<String, dynamic>> _friends = [];
  Map<String, SnapStreak> _userStreaks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _friends = _friends.where((p) => !blockService.isBlocked(p['id'])).toList();
      });
    }
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      final targetId = widget.userId ?? currentUser?.id;
      
      if (targetId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch friend IDs
      final response = await supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$targetId,user2_id.eq.$targetId');

      final List<dynamic> data = response as List<dynamic>;
      final List<String> userIds = data
          .map((item) => item['user1_id'] == targetId ? item['user2_id'] : item['user1_id'])
          .cast<String>()
          .toList();

      if (userIds.isEmpty) {
        if (mounted) {
          setState(() {
            _friends = [];
            _userStreaks = {};
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch profiles for these IDs
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, name, avatar_url, premium_plan')
          .inFilter('id', userIds);

      final List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(profilesResponse as List);

      // 3. Fetch streaks for current user
      final Map<String, SnapStreak> streaksMap = {};
      if (currentUser != null) {
        try {
          final streaksResponse = await supabase
              .from('snap_streaks')
              .select('*, id, user1_id, user2_id, streak_count, broken_streak_count, is_restoreable, restore_deadline')
              .or('user1_id.eq.${currentUser.id},user2_id.eq.${currentUser.id}');
          
          final List<dynamic> streaksData = List<dynamic>.from(streaksResponse as List);
          debugPrint('Loaded streaks: ${streaksData.length}');

          for (var row in streaksData) {
            final u1 = row['user1_id'] as String;
            final u2 = row['user2_id'] as String;
            final friendId = (u1 == currentUser.id) ? u2 : u1;
            final streak = SnapStreak.fromMap(row);
            streaksMap[friendId] = streak;
            debugPrint('STREAK_DEBUG: friendId=$friendId, streakId=${streak.id}, streakCount=${streak.streakCount}, brokenStreakCount=${streak.brokenStreakCount}, isRestoreable=${streak.isRestoreable}, canBeRestored=${streak.canBeRestored}');
          }
        } catch (e) {
          debugPrint("Streaks fetch error: $e");
        }
      }

      if (mounted) {
        setState(() {
          _friends = profiles
              .where((p) => !blockService.isBlocked(p['id']))
              .toList();
          _userStreaks = streaksMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR fetching friends: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Friends (${_friends.length})", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: _friends.isEmpty
                    ? const Center(child: Text("No friends yet."))
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final profile = _friends[index];
                          final avatarUrl = profile['avatar_url'];
                          final plan = profile['premium_plan'] ?? 'free';
                          final streakData = _userStreaks[profile['id']];

                          return Column(
                            children: [
                              ListTile(
                                leading: GestureDetector(
                                  onTap: () => ImageUtils.showImagePreview(context, avatarUrl),
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: PremiumUtils.buildProfileRing(plan),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: ImageUtils.getImageProvider(avatarUrl),
                                      child: ImageUtils.safeUrl(avatarUrl) == null
                                          ? const Icon(Icons.person, color: Colors.white, size: 28)
                                          : null,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile['name'] ?? profile['username'] ?? "User",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    PremiumUtils.buildBadge(plan),
                                    if (streakData != null && (streakData.streakCount > 0 || (streakData.brokenStreakCount > 0 && streakData.canBeRestored))) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        streakData.streakCount > 0 
                                            ? "${streakData.streakCount}🔥" 
                                            : "${streakData.brokenStreakCount}💔", 
                                        style: TextStyle(
                                          fontSize: 14, 
                                          fontWeight: FontWeight.bold, 
                                          color: streakData.streakCount > 0 ? Colors.orange : Colors.redAccent
                                        )
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text("@${profile['username']}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 24, color: Colors.grey),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: profile['id']))).then((_) => _loadData());
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              ),
                              const Divider(height: 1, thickness: 0.5, indent: 90),
                            ],
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
