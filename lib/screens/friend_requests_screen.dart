import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/friend_service.dart';
import '../utils/image_utils.dart';
import 'public_profile.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch raw requests
      final incomingRes = await supabase
          .from('friend_requests')
          .select()
          .eq('receiver_id', user.id)
          .eq('status', 'pending');

      final sentRes = await supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', user.id)
          .eq('status', 'pending');

      final List<Map<String, dynamic>> rawIncoming = List<Map<String, dynamic>>.from(incomingRes as List);
      final List<Map<String, dynamic>> rawSent = List<Map<String, dynamic>>.from(sentRes as List);

      // 2. Collect all unique user IDs to fetch profiles for
      final Set<String> userIds = {};
      for (var req in rawIncoming) userIds.add(req['sender_id']);
      for (var req in rawSent) userIds.add(req['receiver_id']);

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

      // 3. Combine requests with profile data
      final List<Map<String, dynamic>> incomingWithProfiles = rawIncoming.map((req) {
        return {
          ...req,
          'profiles': profileMap[req['sender_id']] ?? {'username': 'Unknown', 'id': req['sender_id']}
        };
      }).toList();

      final List<Map<String, dynamic>> sentWithProfiles = rawSent.map((req) {
        return {
          ...req,
          'profiles': profileMap[req['receiver_id']] ?? {'username': 'Unknown', 'id': req['receiver_id']}
        };
      }).toList();

      if (mounted) {
        setState(() {
          _incomingRequests = incomingWithProfiles;
          _sentRequests = sentWithProfiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading requests: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(String requestId, String senderId) async {
    try {
      await friendService.acceptFriendRequest(requestId, senderId);
      _loadRequests();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request accepted")));
    } catch (e) {
      debugPrint("Error accepting request: $e");
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      await friendService.declineFriendRequest(requestId);
      _loadRequests();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request declined")));
    } catch (e) {
      debugPrint("Error declining request: $e");
    }
  }

  Future<void> _blockUser(String requestId) async {
    try {
      await friendService.blockUser(requestId);
      _loadRequests();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User blocked")));
    } catch (e) {
      debugPrint("Error blocking user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Friend Requests", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                children: [
                  if (_incomingRequests.isNotEmpty) ...[
                    const _SectionHeader(title: "INCOMING REQUESTS"),
                    ..._incomingRequests.map((req) => _buildRequestTile(req, isIncoming: true)),
                  ],
                  if (_sentRequests.isNotEmpty) ...[
                    const _SectionHeader(title: "SENT REQUESTS"),
                    ..._sentRequests.map((req) => _buildRequestTile(req, isIncoming: false)),
                  ],
                  if (_incomingRequests.isEmpty && _sentRequests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Text("No pending requests", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> req, {required bool isIncoming}) {
    final profile = req['profiles'] as Map<String, dynamic>;
    final userId = profile['id'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId))),
        child: CircleAvatar(
          radius: 24,
          backgroundImage: ImageUtils.getImageProvider(profile['avatar_url']),
        ),
      ),
      title: Text(
        profile['name'] ?? profile['username'] ?? "User", 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "@${profile['username'] ?? ''}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isIncoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  onTap: () => _acceptRequest(req['id'], req['sender_id']),
                  tooltip: "Accept",
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.cancel,
                  color: Colors.red,
                  onTap: () => _declineRequest(req['id']),
                  tooltip: "Decline",
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.block_flipped,
                  color: Colors.grey,
                  onTap: () => _blockUser(req['id']),
                  tooltip: "Block",
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text("Pending", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
      ),
    );
  }
}
