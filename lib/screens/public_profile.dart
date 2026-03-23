import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/primary_button.dart';
import 'ask_any_user.dart';
import 'report_problem_screen.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';

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
    ]);
    if (mounted) setState(() => isLoading = false);
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
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.grey,
                    backgroundImage: (avatarUrl != null && avatarUrl != '') ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profileData!['name'] ?? "No Name",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "@${profileData!['username'] ?? 'username'}",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    profileData!['bio'] ?? "Ready to V 1 B E",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PrimaryButton(
              text: "ASK ME A QUESTION",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AskAnyUserScreen(
                      userId: widget.userId,
                    ),
                  ),
                ).then((_) {
                  _loadData();
                });
              },
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat("Likes", "0"),
              _buildStat("Answers", "0"),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(height: 1),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ANSWERS",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 40),
                Center(
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

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
