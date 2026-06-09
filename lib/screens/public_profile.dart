import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import '../widgets/primary_button.dart';
import '../widgets/answer_card.dart';
import '../models/answer.dart';
import '../utils/image_utils.dart';
import '../utils/link_utils.dart';
import 'ask_any_user.dart';
import 'report_problem_screen.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';
import '../services/friend_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? _friendshipStatus;
  int _mutualFriendsCount = 0;
  int _streak = 0;
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
      _checkFriendship(),
      _fetchStreak(),
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
      
      // Fetch dynamic stats
      if (data != null) {
        await Future.wait([
          _fetchStats(),
          _fetchAnswers(),
        ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch answers for total likes and count
      final answersRes = await supabase
          .from('answers')
          .select('id, likes_count')
          .eq('user_id', widget.userId)
          .eq('is_hidden', false);
      
      final answers = answersRes as List;
      int totalLikes = 0;
      for (var a in answers) {
        totalLikes += (a['likes_count'] as int? ?? 0);
      }

      // Fetch friends count
      int friends = 0;
      try {
        debugPrint('FRIEND_AUDIT: Fetching friends count for ${widget.userId}');
        friends = await friendService.getFriendsCount(widget.userId);
        debugPrint('FRIEND_AUDIT: Friends count for ${widget.userId} = $friends');
      } catch (e) {
        debugPrint("Error fetching friends count: $e");
      }

      if (mounted) {
        setState(() {
          profileData = {
            ...profileData!,
            'likes_count': totalLikes,
            'answers_count': answers.length,
            'friends_count': friends,
          };
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  List<Map<String, dynamic>> _userAnswers = [];
  bool _isLoadingAnswers = false;

  Future<void> _fetchAnswers() async {
    setState(() => _isLoadingAnswers = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('answers')
          .select('*, profiles!user_id(username, avatar_url, premium_plan, youtube_verified), questions!question_id(text, image_url, is_anonymous, from_user, asker:profiles!from_user(id, username))')
          .eq('user_id', widget.userId)
          .eq('is_hidden', false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _userAnswers = List<Map<String, dynamic>>.from(response);
          _isLoadingAnswers = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching answers: $e");
      if (mounted) setState(() => _isLoadingAnswers = false);
    }
  }

  Future<void> _checkFriendship() async {
    try {
      debugPrint('FRIEND_AUDIT: Checking friendship status for ${widget.userId}');
      final status = await friendService.getFriendshipStatus(widget.userId);
      debugPrint('CHECK_FRIENDSHIP_STATUS=$status (type: ${status.runtimeType})');
      final mutual = await friendService.getMutualFriendsCount(widget.userId);
      debugPrint('FRIEND_AUDIT: Friend status for ${widget.userId} = $status, mutual = $mutual');

      if (mounted) {
        setState(() {
          _friendshipStatus = status;
          _mutualFriendsCount = mutual;
        });
      }
    } catch (e) {
      debugPrint("Error checking friendship: $e");
    }
  }

  Future<void> _fetchStreak() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final streaksRes = await supabase
          .from('snap_streaks')
          .select('user1_id, user2_id, streak_count')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
      
      final streaks = List<dynamic>.from(streaksRes as List);
      debugPrint('Loaded streaks: ${streaks.length}');

      final streakRow = streaks.firstWhere(
        (s) =>
            (s['user1_id'] == user.id && s['user2_id'] == widget.userId) ||
            (s['user2_id'] == user.id && s['user1_id'] == widget.userId),
        orElse: () => null,
      );

      if (streakRow != null) {
        final count = streakRow['streak_count'] as int;
        debugPrint('Friend ${widget.userId} streak: $count');
        if (mounted) {
          setState(() {
            _streak = count;
          });
        }
      } else {
        debugPrint('Friend ${widget.userId} streak: 0');
      }
    } catch (e) {
      debugPrint("Error fetching streak: $e");
    }
  }

  Future<void> _handleFriendAction() async {
    try {
      if (_friendshipStatus == 'friends') {
        _showUnfriendOptions();
        return;
      }

      if (_friendshipStatus == 'none' || _friendshipStatus == 'declined') {
        await friendService.sendFriendRequest(widget.userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request sent!")));
      } else if (_friendshipStatus == 'pending_sent') {
        await friendService.cancelFriendRequest(widget.userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request cancelled")));
      } else if (_friendshipStatus == 'pending_received') {
        final res = await Supabase.instance.client
            .from('friend_requests')
            .select('id')
            .eq('sender_id', widget.userId)
            .eq('receiver_id', Supabase.instance.client.auth.currentUser!.id)
            .eq('status', 'pending')
            .maybeSingle();
        
        if (res != null) {
          await friendService.acceptFriendRequest(res['id'], widget.userId);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request accepted!")));
        }
      }
      await _checkFriendship();
      await _fetchStats();
    } catch (e) {
      debugPrint("Error handling friend action: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
      }
    }
  }

  void _showUnfriendOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: const Text("Remove Friend", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmUnfriend();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text("Block User", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_rounded),
                title: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _confirmUnfriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Friend?"),
        content: const Text("You will no longer appear in each other's friend lists."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unfriendUser();
            },
            child: const Text("REMOVE FRIEND", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _unfriendUser() async {
    try {
      debugPrint('FRIEND_AUDIT: Unfriending user ${widget.userId}');
      await friendService.unfriend(widget.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend removed")));
        
        // Immediate UI update to show button as "ADD FRIEND" while we refresh everything
        setState(() {
          _friendshipStatus = 'none';
        });
      }

      // Re-fetch everything to sync state
      await _checkFriendship();
      debugPrint('AFTER_UNFRIEND_STATUS=$_friendshipStatus');
      await _fetchStats();
    } catch (e) {
      debugPrint('Error unfriending: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to unfriend: $e")));
      }
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
                GestureDetector(
                  onTap: () => ImageUtils.showImagePreview(context, avatarUrl),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.grey,
                      backgroundImage: ImageUtils.getImageProvider(avatarUrl),
                      child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                    ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "@${profileData!['username'] ?? 'username'}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    if (profileData!['youtube_verified'] == true || (profileData!['premium_plan'] != null && profileData!['premium_plan'] != 'free'))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified_rounded, color: Colors.blue, size: 18),
                      ),
                    if (_streak > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          "🔥 $_streak",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_mutualFriendsCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "$_mutualFriendsCount mutual ${_mutualFriendsCount == 1 ? 'friend' : 'friends'}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Linkify(
                    onOpen: (link) async {
                      await LinkUtils.handleLinkClick(context, link);
                    },
                    text: profileData!['bio'] ?? "Ready to HIGH5",
                    textAlign: TextAlign.center,
                    linkifiers: const [
                      UrlLinkifier(),
                      EmailLinkifier(),
                      UserLinkifier(),
                    ],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    linkStyle: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (profileData!['show_gmail'] == true &&
                    profileData!['gmail_address'] != null && 
                    profileData!['gmail_address'].toString().isNotEmpty)
                  _buildContactEmailRow(),
                const SizedBox(height: 16),
                if (profileData!['show_social_links'] != false)
                  _buildSocialLinksRow(),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: PrimaryButton(
                    text: "ASK QUESTION",
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
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: _handleFriendAction,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.black87, width: 1.5),
                    ),
                    child: FittedBox(
                      child: Text(
                        _friendshipStatus == 'friends' 
                            ? "FRIENDS" 
                            : _friendshipStatus == 'pending_sent'
                                ? "REQUESTED"
                                : _friendshipStatus == 'pending_received'
                                    ? "ACCEPT"
                                    : "ADD FRIEND",
                        style: const TextStyle(
                          color: Colors.black87, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(
                (profileData!['friends_count'] ?? 0) == 1 ? "Friend" : "Friends", 
                "${profileData!['friends_count'] ?? 0}"
              ),
              _buildStat("Likes", "${profileData!['likes_count'] ?? 0}"),
              _buildStat("Answers", "${profileData!['answers_count'] ?? 0}"),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(height: 1),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ANSWERS",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingAnswers)
                  const Center(child: CircularProgressIndicator())
                else if (_userAnswers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        "No answers yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userAnswers.length,
                    itemBuilder: (context, index) {
                      final item = _userAnswers[index];
                      return AnswerCard(
                        answer: AnswerModel.fromMap(item),
                      );
                    },
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

  Widget _buildContactEmailRow() {
    final email = profileData!['gmail_address'] as String;
    return InkWell(
      onTap: () => launchUrl(Uri.parse('mailto:$email')),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline_rounded, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              email,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksRow() {
    final socials = [
      {'platform': 'instagram', 'icon': FontAwesomeIcons.instagram, 'handle': profileData!['instagram_handle']},
      {'platform': 'twitter', 'icon': FontAwesomeIcons.xTwitter, 'handle': profileData!['twitter_handle']},
      {'platform': 'facebook', 'icon': FontAwesomeIcons.facebook, 'handle': profileData!['facebook_handle']},
      {'platform': 'linkedin', 'icon': FontAwesomeIcons.linkedin, 'handle': profileData!['linkedin_handle']},
      {'platform': 'youtube', 'icon': FontAwesomeIcons.youtube, 'handle': profileData!['youtube_handle']},
      {'platform': 'tiktok', 'icon': FontAwesomeIcons.tiktok, 'handle': profileData!['tiktok_handle']},
      {'platform': 'snapchat', 'icon': FontAwesomeIcons.snapchat, 'handle': profileData!['snapchat_handle']},
      {'platform': 'whatsapp', 'icon': FontAwesomeIcons.whatsapp, 'handle': profileData!['whatsapp_handle']},
      {'platform': 'telegram', 'icon': FontAwesomeIcons.telegram, 'handle': profileData!['telegram_handle']},
    ];

    final activeSocials = socials.where((s) => s['handle'] != null && (s['handle'] as String).isNotEmpty).toList();

    if (activeSocials.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: activeSocials.map((s) {
          return InkWell(
            onTap: () => _launchSocial(s['platform'] as String, s['handle'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                s['icon'] as IconData,
                size: 18,
                color: Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _launchSocial(String platform, String handle) async {
    if (handle.isEmpty) return;
    
    Uri url;
    if (handle.startsWith('http')) {
      url = Uri.parse(handle);
    } else {
      switch (platform) {
        case 'instagram':
          url = Uri.parse('https://instagram.com/$handle');
          break;
        case 'twitter':
          url = Uri.parse('https://x.com/$handle');
          break;
        case 'facebook':
          url = Uri.parse('https://facebook.com/$handle');
          break;
        case 'linkedin':
          url = Uri.parse('https://linkedin.com/in/$handle');
          break;
        case 'youtube':
          url = Uri.parse(handle.startsWith('@') ? 'https://youtube.com/$handle' : 'https://youtube.com/@$handle');
          break;
        case 'tiktok':
          url = Uri.parse(handle.startsWith('@') ? 'https://tiktok.com/$handle' : 'https://tiktok.com/@$handle');
          break;
        case 'snapchat':
          final username = handle.startsWith('http') 
              ? handle.split('/').last.split('?').first 
              : handle.replaceFirst('snapchat.com/add/', '').replaceFirst('@', '');
          url = Uri.parse('snapchat://add/$username');
          // If app fails, fallback to web URL
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            url = Uri.parse('https://www.snapchat.com/add/$username');
          } else {
            return; // Successfully launched app
          }
          break;
        case 'whatsapp':
          final phone = handle.replaceAll(RegExp(r'[^0-9]'), '');
          url = Uri.parse('https://wa.me/$phone');
          break;
        case 'telegram':
          final username = handle.replaceFirst('t.me/', '').replaceFirst('@', '');
          url = Uri.parse('https://t.me/$username');
          break;
        default:
          return;
      }
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}
