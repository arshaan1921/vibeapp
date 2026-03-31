import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';
import '../main.dart';
import '../services/block_service.dart';

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
    
    // Refresh data whenever this tab becomes active
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
    if (tabIndexNotifier.value == 3) { // 3 is the index of Saved tab based on MainScaffold
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

      // 1. Fetch saved user IDs
      final savedRows = await supabase
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', user.id);

      final List<String> savedUserIds = (savedRows as List)
          .map((item) => item['saved_user_id'] as String)
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

      // 2. Fetch profiles and streaks in parallel for performance
      final results = await Future.wait([
        supabase
            .from('profiles')
            .select('id, username, name, avatar_url')
            .inFilter('id', savedUserIds),
        supabase
            .from('user_streaks')
            .select('user1_id, user2_id, streak_count')
            .or('user1_id.eq.${user.id},user2_id.eq.${user.id}'),
      ]);

      final profilesResponse = results[0] as List;
      final streaksResponse = results[1] as List;

      // 3. Map streaks efficiently: key is the "other" user ID
      final Map<String, int> streaksMap = {};
      for (var row in streaksResponse) {
        final u1 = row['user1_id'] as String;
        final u2 = row['user2_id'] as String;
        final count = row['streak_count'] as int;
        
        final otherId = (u1 == user.id) ? u2 : u1;
        streaksMap[otherId] = count;
      }

      if (mounted) {
        setState(() {
          _savedProfiles = List<Map<String, dynamic>>.from(profilesResponse)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("SAVED"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSavedProfiles,
              child: _savedProfiles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            "No saved profiles yet.",
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedProfiles.length,
                      separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor),
                      itemBuilder: (context, index) {
                        final profile = _savedProfiles[index];
                        final avatarUrl = profile['avatar_url'];
                        final streak = _userStreaks[profile['id']] ?? 0;

                        return ListTile(
                          tileColor: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            backgroundImage: (avatarUrl != null && avatarUrl != '')
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl == '')
                                ? Icon(Icons.person, color: Theme.of(context).iconTheme.color)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile['name'] ?? profile['username'] ?? "User",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (streak > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    "🔥 $streak",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            "@${profile['username']}",
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                          trailing: Icon(
                            Icons.chevron_right, 
                            size: 20,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: profile['id']),
                              ),
                            ).then((_) => _fetchSavedProfiles());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
