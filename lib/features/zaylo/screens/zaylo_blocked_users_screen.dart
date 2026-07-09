import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/zaylo_service.dart';

class ZayloBlockedUsersScreen extends StatefulWidget {
  const ZayloBlockedUsersScreen({super.key});

  @override
  State<ZayloBlockedUsersScreen> createState() => _ZayloBlockedUsersScreenState();
}

class _ZayloBlockedUsersScreenState extends State<ZayloBlockedUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    final users = await zayloService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    try {
      await zayloService.unblockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unblocked $username'), backgroundColor: Colors.green),
        );
        _loadBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock user'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Blocked Users', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final profile = user['profiles'] as Map<String, dynamic>;
                    final userId = user['blocked_user_id'] as String;
                    final username = profile['username'] as String;
                    final avatarUrl = profile['avatar_url'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(
                          username,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        trailing: TextButton(
                          onPressed: () => _unblockUser(userId, username),
                          child: const Text('Unblock', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No blocked users',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
