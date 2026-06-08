import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart';
import '../models/answer.dart';
import 'settings_screen.dart';
import 'edit_profile.dart';
import 'search_screen.dart';
import '../utils/premium_utils.dart';
import '../utils/image_utils.dart';
import 'ask_any_user.dart';
import 'premium.dart';
import '../widgets/answer_card.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';
import '../services/safety_service.dart';
import 'saved_screen.dart';
import '../services/friend_service.dart';
import '../utils/link_utils.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? errorMessage;
  List<AnswerModel> _answers = [];
  bool _loadingAnswers = true;
  int _likesCount = 0;
  bool isSaved = false;
  int _remainingQuestions = 0;
  int _friendsCount = 0;
  String? _friendshipStatus;
  int _mutualFriendsCount = 0;
  int _streak = 0;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
    tabIndexNotifier.addListener(_onTabChanged);
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    tabIndexNotifier.removeListener(_onTabChanged);
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _onTabChanged() {
    if (tabIndexNotifier.value == 4 && widget.userId == null) {
      debugPrint('FRIEND_AUDIT: Profile tab selected, refreshing data');
      _loadData();
    }
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _onBlocksChanged() {
    if (widget.userId != null && blockService.isBlocked(widget.userId!)) {
      if (mounted) {
        setState(() {
          errorMessage = "This user is blocked or has blocked you.";
        });
      }
    }
  }

  void _subscribeToRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final targetId = widget.userId ?? user?.id;
    if (targetId == null) return;

    _realtimeChannel = supabase.channel('profile_realtime_$targetId');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'answers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: targetId,
      ),
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.insert || 
            payload.eventType == PostgresChangeEvent.delete) {
          _fetchAnswers();
        } else if (payload.eventType == PostgresChangeEvent.update) {
          if (mounted) {
            setState(() {
              final index = _answers.indexWhere((a) => a.id == payload.newRecord['id'].toString());
              if (index != -1) {
                _answers[index] = _answers[index].copyWith(
                  likeCount: payload.newRecord['likes_count'],
                  isPinned: payload.newRecord['is_pinned'],
                );
                _sortAnswers();
              }
            });
          }
        }
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friends',
      callback: (payload) {
        debugPrint('FRIEND_AUDIT: Friends table changed, refreshing count');
        _fetchFriendsCount();
        _checkFriendship();
      },
    ).subscribe();
  }

  void _sortAnswers() {
    _answers.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> _loadData() async {
    if (widget.userId != null && blockService.isBlocked(widget.userId!)) {
       setState(() {
          errorMessage = "This user is blocked or has blocked you.";
          isLoading = false;
       });
       return;
    }

    await Future.wait<dynamic>([
      _fetchProfile(),
      _fetchAnswers(),
      _checkFriendship(),
      _fetchRemainingQuestions(),
      _fetchFriendsCount(),
      _fetchStreak(),
    ]);
  }

  Future<void> _fetchFriendsCount() async {
    try {
      final targetId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
      if (targetId == null) return;

      debugPrint('FRIEND_AUDIT: Fetching friends count for $targetId');
      final count = await friendService.getFriendsCount(targetId);
      debugPrint('FRIEND_AUDIT: Friends count for $targetId = $count');
      
      if (mounted) {
        setState(() {
          _friendsCount = count;
        });
      }
    } catch (e) {
      debugPrint('ERROR fetching friends count: $e');
    }
  }

  Future<void> _checkFriendship() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final targetId = widget.userId;
    if (targetId == null || targetId == currentUser.id) return;

    try {
      debugPrint('FRIEND_AUDIT: Checking friendship status for $targetId');
      final status = await friendService.getFriendshipStatus(targetId);
      final mutual = await friendService.getMutualFriendsCount(targetId);
      debugPrint('FRIEND_AUDIT: Friend status for $targetId = $status, mutual = $mutual');

      if (mounted) {
        setState(() {
          _friendshipStatus = status;
          _mutualFriendsCount = mutual;
        });
      }
    } catch (e) {
      debugPrint('ERROR checking friendship: $e');
    }
  }

  Future<void> _fetchStreak() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final targetId = widget.userId;
    if (targetId == null || targetId == currentUser.id) return;

    try {
      final supabase = Supabase.instance.client;
      final streaksRes = await supabase
          .from('snap_streaks')
          .select('user1_id, user2_id, streak_count')
          .or('user1_id.eq.${currentUser.id},user2_id.eq.${currentUser.id}');
      
      final streaks = List<dynamic>.from(streaksRes as List);
      debugPrint('Loaded streaks: ${streaks.length}');

      final streakRow = streaks.firstWhere(
        (s) =>
            (s['user1_id'] == currentUser.id && s['user2_id'] == targetId) ||
            (s['user2_id'] == currentUser.id && s['user1_id'] == targetId),
        orElse: () => null,
      );

      if (streakRow != null) {
        final count = streakRow['streak_count'] as int;
        debugPrint('Friend $targetId streak: $count');
        if (mounted) {
          setState(() {
            _streak = count;
          });
        }
      } else {
        debugPrint('Friend $targetId streak: 0');
      }
    } catch (e) {
      debugPrint("Error fetching streak: $e");
    }
  }

  Future<void> _handleFriendAction() async {
    if (widget.userId == null) return;
    
    try {
      if (_friendshipStatus == 'friends') {
        _showUnfriendOptions();
        return;
      }

      if (_friendshipStatus == 'none' || _friendshipStatus == 'declined') {
        await friendService.sendFriendRequest(widget.userId!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request sent!")));
      } else if (_friendshipStatus == 'pending_received') {
        // Find the request ID and accept it. 
        // For simplicity in this UI, we can navigate to the requests screen or handle it here.
        // Let's just fetch the request ID.
        final res = await Supabase.instance.client
            .from('friend_requests')
            .select('id')
            .eq('sender_id', widget.userId!)
            .eq('receiver_id', Supabase.instance.client.auth.currentUser!.id)
            .eq('status', 'pending')
            .maybeSingle();
        
        if (res != null) {
          await friendService.acceptFriendRequest(res['id'], widget.userId!);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request accepted!")));
        }
      }
      
      await _checkFriendship();
      await _fetchFriendsCount();
    } catch (e) {
      debugPrint('Error handling friend action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
      }
    }
  }

  void _showUnfriendOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
    if (widget.userId == null) return;
    try {
      debugPrint('FRIEND_AUDIT: Unfriending user ${widget.userId}');
      await friendService.unfriend(widget.userId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend removed")));
        
        // Immediate UI update
        setState(() {
          _friendshipStatus = 'none';
        });
      }

      await _checkFriendship();
      await _fetchFriendsCount();
    } catch (e) {
      debugPrint('Error unfriending: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final targetId = widget.userId ?? supabase.auth.currentUser?.id;

      if (targetId == null) {
        if (mounted) setState(() { isLoading = false; errorMessage = "Not logged in"; });
        return;
      }

      final data = await supabase.from('profiles').select().eq('id', targetId).maybeSingle();

      if (mounted) {
        setState(() {
          profileData = data;
          isLoading = false;
          if (data == null) errorMessage = "Profile not found";
        });
      }
    } catch (e, st) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _fetchAnswers() async {
    print('PROFILE_TRACE: START');
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final targetId = widget.userId ?? user?.id;

      debugPrint('PROFILE TARGET ID = $targetId');
      debugPrint('CURRENT USER ID = ${Supabase.instance.client.auth.currentUser?.id}');

      if (targetId == null) {
        print('PROFILE_TRACE: NO TARGET ID');
        return;
      }

      print('PROFILE_TRACE: USER ID = $targetId');
      print('PROFILE_TRACE: Querying Supabase...');
      // Reverted to more reliable table-only join syntax
      final response = await supabase
          .from('answers')
          .select('*, profiles!user_id(username, avatar_url, premium_plan), questions!question_id(text, image_url, is_anonymous, from_user)')
          .eq('user_id', targetId)
          .order('created_at', ascending: false);

      final responseList = response as List;
      print('PROFILE_TRACE: ROWS = ${responseList.length}');
      if (mounted) {
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(responseList);
        
        Set<String> likedIds = {};
        if (user != null) {
          final likesRes = await supabase.from('answer_likes').select('answer_id').eq('user_id', user.id);
          likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
        }

        try {
          final answers = rawData.map((map) => AnswerModel.fromMap(map, isLiked: likedIds.contains(map['id'].toString()))).toList();

          int totalLikes = 0;
          for (var a in answers) {
            totalLikes += a.likeCount;
          }

          setState(() {
            _answers = answers;
            _likesCount = totalLikes;
            _loadingAnswers = false;
            print('PROFILE ANSWERS = ${answers.length}');
          });
        } catch (e, st) {
          print('PROFILE_TRACE: PARSE ERROR: $e');
          print(st);
          setState(() => _loadingAnswers = false);
        }
      }
    } catch (e, st) {
      print('PROFILE_TRACE: GLOBAL ERROR: $e');
      print(st);
      if (mounted) setState(() => _loadingAnswers = false);
    }
  }

  Future<void> _deleteAnswer(String answerId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('answers').delete().eq('id', answerId);
      
      // Update UI immediately
      if (mounted) {
        setState(() {
          _answers.removeWhere((a) => a.id == answerId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answer deleted")),
        );
      }
      
      // Refresh to sync counts and logic
      _fetchAnswers();
      _fetchFriendsCount();
    } catch (e, st) {
      debugPrint('ERROR deleting answer: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete answer")),
        );
      }
    }
  }

  Future<void> _fetchRemainingQuestions() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase.rpc('get_total_remaining_questions', params: {'uid': user.id});
      if (mounted) {
        setState(() {
          _remainingQuestions = response as int;
        });
      }
    } catch (e, st) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _showEllipsisMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                title: const Text("Block User", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined),
                title: const Text("Report User", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  // _showReportModal();
                },
              ),
              const SizedBox(height: 12),
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
    if (widget.userId == null) return;
    await blockService.blockUser(widget.userId!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleLinkClick(LinkableElement link) async {
    await LinkUtils.handleLinkClick(context, link);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("PROFILE_BUILD: answers=${_answers.length}, loading=$_loadingAnswers");
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) return const Scaffold(body: Center(child: Text("Error loading profile")));

    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final isMe = widget.userId == null || widget.userId == Supabase.instance.client.auth.currentUser?.id;
    final plan = profileData!['premium_plan'] ?? 'free';
    final joinedAt = profileData!['created_at'] != null 
        ? DateFormat('MMMM yyyy').format(DateTime.parse(profileData!['created_at']))
        : 'Unknown';
    
    return Scaffold(
      appBar: AppBar(
        title: Text("@${profileData!['username'] ?? 'user'}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: theme.colorScheme.onSurface),
            onPressed: () {
              final username = profileData?['username'] ?? 'user';
              Share.share("Check out @$username on High5! https://v1beapp.page.link/profile");
            },
          ),
          if (isMe) ...[
            IconButton(icon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurface), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
            IconButton(icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadData())),
          ] else ...[
            IconButton(icon: Icon(Icons.more_horiz_rounded, color: theme.colorScheme.onSurface), onPressed: _showEllipsisMenu),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => ImageUtils.showImagePreview(context, profileData!['avatar_url']),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: PremiumUtils.getRingColor(plan), width: 2.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21.5),
                                child: Image.network(
                                  profileData!['avatar_url'] ?? '',
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 78,
                                    height: 78,
                                    color: isDarkMode ? Colors.white10 : Colors.grey[200],
                                    child: Icon(Icons.person, size: 40, color: isDarkMode ? Colors.white38 : Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profileData!['name'] ?? "No Name", 
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: theme.colorScheme.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "@${profileData!['username']}", 
                                        style: theme.textTheme.bodyMedium?.copyWith(color: isDarkMode ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PremiumUtils.buildBadge(plan),
                                    if (profileData!['is_verified'] == true) 
                                      const Icon(Icons.verified_rounded, color: Colors.blue, size: 18),
                                    if (profileData!['is_founder'] == true)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                                      ),
                                    if (_streak > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          "🔥 $_streak",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!isMe && _mutualFriendsCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "$_mutualFriendsCount mutual ${_mutualFriendsCount == 1 ? 'friend' : 'friends'}",
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text("Joined $joinedAt", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Linkify(
                        text: profileData!['bio'] ?? "No bio yet",
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, fontSize: 15, color: theme.colorScheme.onSurface),
                        linkifiers: const [
                          UrlLinkifier(),
                          EmailLinkifier(),
                          UserLinkifier(),
                        ],
                        onOpen: _handleLinkClick,
                        linkStyle: TextStyle(
                          color: isDarkMode ? Colors.lightBlueAccent : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
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
                      const SizedBox(height: 16),
                      if (isMe)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(isDarkMode ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 20, color: isDarkMode ? Colors.greenAccent : theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Text(
                                plan == 'free' ? "$_remainingQuestions questions left today" : "Unlimited questions",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.greenAccent : theme.colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  final targetId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
                                  if (targetId == null) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => FriendsListScreen(userId: targetId)),
                                  ).then((_) => _loadData());
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: _buildStatItem(_friendsCount == 1 ? "Friend" : "Friends", _friendsCount.toString()),
                              ),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
                            Expanded(child: _buildStatItem("Likes", _likesCount.toString())),
                            Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
                            Expanded(child: _buildStatItem("Answers", _answers.length.toString())),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isMe)
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AskAnyUserScreen(userId: widget.userId))).then((_) => _loadData()),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const FittedBox(
                                  child: Text("ASK QUESTION", style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: OutlinedButton(
                                onPressed: _handleFriendAction,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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
                                    style: TextStyle(
                                      color: theme.colorScheme.primary, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 14,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadData()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                ),
                                child: Text("EDIT PROFILE", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (plan == 'free') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _loadData()),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: const Text("UPGRADE", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1, thickness: 0.5)),
              if (_loadingAnswers)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_answers.isEmpty)
                const SliverFillRemaining(child: Center(child: Text("No answers yet.")))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => AnswerCard(
                      key: ValueKey(_answers[index].id),
                      answer: _answers[index],
                      onDelete: isMe ? (id) => _deleteAnswer(id) : null,
                      onPin: isMe ? (id, pin) => _fetchAnswers() : null,
                    ),
                    childCount: _answers.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
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
            Icon(Icons.mail_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
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

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: activeSocials.map((s) {
        return InkWell(
          onTap: () => _launchSocial(s['platform'] as String, s['handle'] as String),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              s['icon'] as IconData,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
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
          // Clean phone number (remove +, spaces, dashes)
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
