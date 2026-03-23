import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_profile.dart';

class SavedProfilesScreen extends StatefulWidget {
  const SavedProfilesScreen({super.key});

  @override
  State<SavedProfilesScreen> createState() => _SavedProfilesScreenState();
}

class _SavedProfilesScreenState extends State<SavedProfilesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedProfiles();
  }

  Future<void> _fetchSavedProfiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('saved_profiles')
          .select('*, profiles:saved_user_id(id, username, name, avatar_url)')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _savedUsers = (response as List)
              .map((item) => item['profiles'] as Map<String, dynamic>)
              .toList();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("SAVED PROFILES"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSavedProfiles,
              child: _savedUsers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: const _EmptyState(
                            icon: Icons.bookmark_border,
                            message: "No saved profiles yet",
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _savedUsers.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = _savedUsers[index];
                        final avatarUrl = user['avatar_url'];

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(user["username"] ?? "User",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(user["name"] ?? "",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PublicProfileScreen(userId: user['id']),
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
