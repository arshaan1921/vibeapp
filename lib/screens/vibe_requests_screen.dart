import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VibeRequestsScreen extends StatefulWidget {
  const VibeRequestsScreen({super.key});

  @override
  State<VibeRequestsScreen> createState() => _VibeRequestsScreenState();
}

class _VibeRequestsScreenState extends State<VibeRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Directly query the vibe_requests table.
      final response = await supabase
          .from('vibe_requests')
          .select('*, profiles:sender_id(username)')
          .eq('receiver_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      final supabase = Supabase.instance.client;
      
      // STEP 1: Update request status to 'accepted' in vibe_requests.
      await supabase
          .from('vibe_requests')
          .update({'status': 'accepted'})
          .eq('id', request['id']);

      // STEP 2: Create follow relationship in vibes table.
      await supabase.from('vibes').insert({
        'follower_id': request['sender_id'],
        'following_id': request['receiver_id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vibe request accepted")),
        );
        _fetchRequests();
      }
    } catch (e) {
      debugPrint("Error accepting request: $e");
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final supabase = Supabase.instance.client;
      // Update request status to 'rejected' in vibe_requests.
      await supabase
          .from('vibe_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vibe request rejected")),
        );
        _fetchRequests();
      }
    } catch (e) {
      debugPrint("Error rejecting request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text("VIBE REQUESTS"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: _requests.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            "No pending requests",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        final username = request['profiles']?['username'] ?? "User";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "@$username wants to vibe with you",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _acceptRequest(request),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text("ACCEPT"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _rejectRequest(request['id']),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        child: const Text("REJECT"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
