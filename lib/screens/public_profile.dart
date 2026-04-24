import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/primary_button.dart';
import 'ask_any_user.dart';
import 'report_problem_screen.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool isSaved = false;
  String? errorMessage;
  int _likesCount = 0;
  int _answersCount = 0;
  int _v1beCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (blockService.isBlocked(widget.userId)) {
      if (mounted) {
        setState(() {
          errorMessage = "This user is blocked or has blocked you.";
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (blockService.isBlocked(widget.userId)) {
      setState(() {
        errorMessage = "This user is blocked or has blocked you.";
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);
    await Future.wait([
      _fetchProfile(),
      _checkIfSaved(),
      _fetchStats(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchStats() async {
    try {
      final supabase = Supabase.instance.client;
      
      final answersRes = await supabase.from('answers').select('likes_count').eq('user_id', widget.userId);
      final List answersList = answersRes as List;
      
      final v1besRes = await supabase.rpc('get_profile_v1bes', params: {'uid': widget.userId});

      if (mounted) {
        setState(() {
          _answersCount = answersList.length;
          _likesCount = answersList.fold(0, (sum, item) => sum + (item['likes_count'] as int));
          _v1beCount = v1besRes as int;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          profileData = data;
          if (data == null) {
            errorMessage = "Profile not found";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('saved_profiles')
          .select()
          .eq('user_id', user.id)
          .eq('saved_user_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          isSaved = response != null;
        });
      }
    } catch (e) {
      debugPrint("Error checking saved status: $e");
    }
  }

  Future<void> _toggleSave() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (isSaved) {
        await supabase
            .from('saved_profiles')
            .delete()
            .eq('user_id', user.id)
            .eq('saved_user_id', widget.userId);
      } else {
        await supabase.from('saved_profiles').insert({
          'user_id': user.id,
          'saved_user_id': widget.userId,
        });
      }
      setState(() {
        isSaved = !isSaved;
      });
      _fetchStats();
    } catch (e) {
      debugPrint("Error toggling save: $e");
    }
  }

  void _showEllipsisMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text("Block User", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text("Report User"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportProblemScreen(reportedUserId: widget.userId),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block User"),
        content: const Text("Are you sure you want to block this user? You won't see their content, and they won't see yours."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            child: const Text("BLOCK", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      await blockService.blockUser(widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User blocked")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error blocking user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to block user")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (errorMessage == null) ...[
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.black,
              ),
              onPressed: _toggleSave,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onPressed: _showEllipsisMenu,
            ),
          ]
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading && profileData == null && errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (profileData == null) {
      return const Center(child: Text("Profile data missing"));
    }

    final avatarUrl = profileData!['avatar_url'];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMe = widget.userId == currentUserId;
    
    final joinedDate = profileData?['created_at'];
    String joinedText = "";
    if (joinedDate != null) {
      final date = DateTime.parse(joinedDate).toLocal();
      joinedText = "Joined ${DateFormat('MMMM yyyy').format(date)}";
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (avatarUrl != null && avatarUrl != '') ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      profileData!['username'] ?? "user",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "@${profileData!['username'] ?? 'username'}",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  joinedText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    profileData!['bio'] ?? "Ready to V 1 B E",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // "Question" Button
                Expanded(
                  child: PrimaryButton(
                    text: "QUESTION",
                    color: const Color(0xFF2C4E6E),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AskAnyUserScreen(
                            userId: widget.userId,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                ),
                
                if (!isMe) ...[
                  const SizedBox(width: 12),
                  // "Message" Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C4E6E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          final convId = await chatService.getOrCreateConversation(widget.userId);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  conversationId: convId,
                                  otherUserId: widget.userId,
                                  otherUserName: profileData!['username'] ?? 'User',
                                  otherUserAvatar: avatarUrl,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                           if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error starting chat: $e')),
                              );
                           }
                        }
                      },
                      child: const Text("MESSAGE"),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(_likesCount.toString(), "Likes"),
              _buildStat(_answersCount.toString(), "Answers"),
              _buildStat(_v1beCount.toString(), "V1BEs"),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MY ANSWERS",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Text(
                    "No answers yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
