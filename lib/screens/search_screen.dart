import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_profile.dart';
import '../utils/premium_utils.dart';
import '../services/block_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _searchResults = _searchResults.where((u) => !blockService.isBlocked(u['id'])).toList();
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final results = await supabase
          .from('profiles')
          .select('id, username, name, avatar_url, premium_plan')
          .ilike('username', '%$query%')
          .limit(20);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(results)
            .where((u) => !blockService.isBlocked(u['id']))
            .toList();
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      final plan = user['premium_plan'];
                      final avatarUrl = user['avatar_url'];

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: PremiumUtils.buildProfileRing(plan),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: (avatarUrl != null && avatarUrl != '') ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                        ),
                        title: Row(
                          children: [
                            PremiumUtils.buildBadge(plan),
                            Text(
                              user['name'] ?? user['username'] ?? 'No Name',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '@${user['username'] ?? ''}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublicProfileScreen(
                                userId: user['id'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
