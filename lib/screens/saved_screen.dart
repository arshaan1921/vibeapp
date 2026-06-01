import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';
import '../main.dart';
import '../services/block_service.dart';
import '../utils/image_utils.dart';
import '../utils/premium_utils.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> _savedProfiles = [];
  Map<String, int> _userStreaks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    tabIndexNotifier.addListener(_onTabChanged);
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    tabIndexNotifier.removeListener(_onTabChanged);
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (tabIndexNotifier.value == 3) {
      _fetchSavedProfiles();
    }
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _savedProfiles = _savedProfiles.where((p) => !blockService.isBlocked(p['id'])).toList();
      });
    }
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchSavedProfiles();
  }

  Future<void> _fetchSavedProfiles() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch saved user IDs first (most reliable)
      final savedRowsResponse = await supabase
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> savedRows = List<Map<String, dynamic>>.from(savedRowsResponse as List);
      final List<String> savedUserIds = savedRows
          .map((item) => item['saved_user_id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (savedUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedProfiles = [];
            _userStreaks = {};
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch profiles and streaks
      // Splitting these to avoid Future.wait type issues and using correct method name inFilter
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, name, avatar_url, premium_plan')
          .inFilter('id', savedUserIds);

      final streaksResponse = await supabase
          .from('user_streaks')
          .select('user1_id, user2_id, streak_count')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

      final List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(profilesResponse as List);
      final List<Map<String, dynamic>> streaks = List<Map<String, dynamic>>.from(streaksResponse as List);

      final Map<String, int> streaksMap = {};
      for (var row in streaks) {
        final u1 = row['user1_id'] as String;
        final u2 = row['user2_id'] as String;
        streaksMap[(u1 == user.id) ? u2 : u1] = row['streak_count'] as int;
      }

      if (mounted) {
        setState(() {
          // Maintain order of saved items or just show what's found
          _savedProfiles = profiles
              .where((p) => !blockService.isBlocked(p['id']))
              .toList();
          _userStreaks = streaksMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching saved profiles: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Saved", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
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
                child: _savedProfiles.isEmpty
                    ? const Center(child: Text("No saved profiles yet."))
                    : ListView.builder(
                        itemCount: _savedProfiles.length,
                        itemBuilder: (context, index) {
                          final profile = _savedProfiles[index];
                          final avatarUrl = profile['avatar_url'];
                          final streak = _userStreaks[profile['id']] ?? 0;
                          final plan = profile['premium_plan'];

                          return Column(
                            children: [
                              ListTile(
                                leading: Container(
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
                                  ],
                                ),
                                subtitle: Text("@${profile['username']}", style: const TextStyle(color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (streak > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text("🔥 $streak", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                      ),
                                    const Icon(Icons.chevron_right_rounded, size: 24, color: Colors.grey),
                                  ],
                                ),
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
