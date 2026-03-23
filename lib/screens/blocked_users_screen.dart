import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id, profiles:blocked_id(username, name, avatar_url)')
          .eq('blocker_id', userId);

      setState(() {
        _blockedUsers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching blocked users: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    try {
      await blockService.unblockUser(blockedId);

      setState(() {
        _blockedUsers.removeWhere((user) => user['blocked_id'] == blockedId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User unblocked")),
        );
      }
    } catch (e) {
      debugPrint("Error unblocking user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to unblock user")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Blocked Users", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? const Center(child: Text("No blocked users"))
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final data = _blockedUsers[index];
                    final profile = data['profiles'] as Map<String, dynamic>?;
                    final username = profile?['username'] ?? "Unknown";
                    final name = profile?['name'] ?? "";
                    final avatarUrl = profile?['avatar_url'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatarUrl != null && avatarUrl != '')
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl == '')
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(name.isNotEmpty ? name : "@$username"),
                      subtitle: name.isNotEmpty ? Text("@$username") : null,
                      trailing: TextButton(
                        onPressed: () => _unblockUser(data['blocked_id']),
                        child: const Text("UNBLOCK", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}
