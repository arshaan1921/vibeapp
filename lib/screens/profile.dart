import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/answer.dart';
import '../widgets/primary_button.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../utils/premium_utils.dart';
import '../utils/image_utils.dart';
import 'ask_any_user.dart';
import 'premium.dart';
import '../widgets/answer_card.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? errorMessage;
  List<AnswerModel> _answers = [];
  bool _loadingAnswers = true;
  int _likesCount = 0;
  bool isSaved = false;
  int _remainingQuestions = 0;
  int _high5Count = 0;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
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
                
                if (payload.oldRecord != null && payload.oldRecord['is_pinned'] != payload.newRecord['is_pinned']) {
                   _sortAnswers();
                }

                int total = 0;
                for (var ans in _answers) {
                  total += ans.likeCount;
                }
                _likesCount = total;
              }
            });
          }
        }
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

    await Future.wait([
      _fetchProfile(),
      _fetchAnswers(),
      _checkIfSaved(),
      _fetchRemainingQuestions(),
      _fetchHigh5sCount(),
    ]);
  }

  Future<void> _fetchHigh5sCount() async {
    try {
      final supabase = Supabase.instance.client;
      final targetId = widget.userId ?? supabase.auth.currentUser?.id;
      if (targetId == null) return;

      final response = await supabase.rpc('get_profile_v1bes', params: {'uid': targetId});
      if (mounted) {
        setState(() {
          _high5Count = response as int;
        });
      }
    } catch (e) {
      debugPrint("Error fetching High5s count: $e");
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
    } catch (e) {
      debugPrint("Error fetching remaining questions: $e");
    }
  }

  Future<void> _checkIfSaved() async {
    if (widget.userId == null) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final res = await Supabase.instance.client
          .from('saved_profiles')
          .select()
          .eq('user_id', currentUser.id)
          .eq('saved_user_id', widget.userId!)
          .maybeSingle();

      if (mounted) setState(() => isSaved = res != null);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null || widget.userId == null) return;

    try {
      if (isSaved) {
        await supabase
            .from('saved_profiles')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('saved_user_id', widget.userId!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile removed from saved")),
          );
        }
      } else {
        await supabase.from('saved_profiles').insert({
          'user_id': currentUser.id,
          'saved_user_id': widget.userId!,
        });

        final saverProfile = await supabase.from('profiles').select('username').eq('id', currentUser.id).single();
        
        // PUSH ONLY (Edge Function)
        try {
          final session = supabase.auth.currentSession;
          final accessToken = session?.accessToken;

          if (accessToken != null) {
            await supabase.functions.invoke(
              'supabase-functions-new-send-push-notification',
              body: {
                "user_id": widget.userId!,
                "title": "Profile Saved!",
                "body": "@${saverProfile['username']} saved your profile to their High5s!",
                "data": {"type": "profile_save"}
              },
              headers: {
                "Authorization": "Bearer $accessToken",
              },
            );
          }
        } catch (e) {
          debugPrint("Push failed: $e");
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile saved")),
          );
        }
      }
      if (mounted) setState(() => isSaved = !isSaved);
      _fetchHigh5sCount();
    } catch (e) {
      debugPrint("Toggle save error: $e");
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
        if (data != null && (widget.userId == null || widget.userId == supabase.auth.currentUser?.id)) {
          final expiresAtStr = data['premium_expires_at'];
          if (expiresAtStr != null) {
            final expiresAt = DateTime.parse(expiresAtStr);
            if (expiresAt.isBefore(DateTime.now())) {
              await supabase.from('profiles').update({'premium_plan': 'free'}).eq('id', targetId);
              _loadData();
              return;
            }
          }
        }

        setState(() {
          profileData = data;
          isLoading = false;
          if (data == null) errorMessage = "Profile not found";
        });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; errorMessage = "Error: $e"; });
    }
  }

  Future<void> _fetchAnswers() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final targetId = widget.userId ?? user?.id;
      if (targetId == null) return;

      final response = await supabase
          .from('answers')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan), questions(*, profiles:from_user(id, username))')
          .eq('user_id', targetId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
        
        Set<String> likedIds = {};
        if (user != null) {
          final likesRes = await supabase
              .from('answer_likes')
              .select('answer_id')
              .eq('user_id', user.id);
          likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
        }

        final answers = rawData.map((map) {
          final id = map['id'].toString();
          return AnswerModel.fromMap(map, isLiked: likedIds.contains(id));
        }).toList();

        int totalLikes = 0;
        for (var answer in answers) {
          totalLikes += answer.likeCount;
        }

        setState(() {
          _answers = answers;
          _likesCount = totalLikes;
          _loadingAnswers = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching answers: $e");
      if (mounted) setState(() => _loadingAnswers = false);
    }
  }

  Future<void> _deleteAnswer(String answerId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('answers').delete().eq('id', answerId);
      
      if (mounted) {
        setState(() {
          _answers.removeWhere((a) => a.id == answerId);
          int total = 0;
          for (var ans in _answers) {
            total += ans.likeCount;
          }
          _likesCount = total;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answer deleted"), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint("Error deleting answer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete answer")),
        );
      }
    }
  }

  Future<void> _togglePin(String answerId, bool shouldPin) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (shouldPin) {
        await supabase
            .from('answers')
            .update({'is_pinned': false})
            .match({'user_id': userId, 'is_pinned': true});
      }

      await supabase
          .from('answers')
          .update({'is_pinned': shouldPin})
          .eq('id', answerId);

      if (mounted) {
        setState(() {
          for (int i = 0; i < _answers.length; i++) {
            if (shouldPin && _answers[i].isPinned) {
              _answers[i] = _answers[i].copyWith(isPinned: false);
            }
            if (_answers[i].id == answerId) {
              _answers[i] = _answers[i].copyWith(isPinned: shouldPin);
            }
          }
          _sortAnswers();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shouldPin ? "Answer pinned to top" : "Answer unpinned"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error toggling pin: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update pin")),
        );
      }
    }
  }

  void _showEllipsisMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  _showReportModal();
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
      if (widget.userId == null) return;
      await blockService.blockUser(widget.userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User blocked")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
      }
    } catch (e) {
      debugPrint("Error blocking user: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to block user")));
    }
  }

  void _showReportModal() {
    final reasons = ["Spam", "Abuse or Harassment", "Inappropriate Content", "Fake Account", "Other"];
    String selectedReason = reasons[0];
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Report User", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setModalState(() => selectedReason = val!),
                    decoration: const InputDecoration(labelText: "Reason"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Description (Optional)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: "SUBMIT REPORT",
                    onPressed: () async {
                      final success = await _submitReport(selectedReason, descriptionController.text);
                      if (success && mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitReport(String reason, String description) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || widget.userId == null) return false;

      await supabase.from('reports').insert({
        'reporter_id': currentUser.id,
        'reported_user_id': widget.userId!,
        'reason': reason,
        'description': description,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted successfully")));
      return true;
    } catch (e) {
      debugPrint("Error reporting user: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit report")));
      return false;
    }
  }

  Future<void> _handleLinkClick(LinkableElement link) async {
    if (link.url.startsWith('@')) {
      // Resolve username to profile
      final username = link.url.substring(1).toLowerCase();
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', username)
            .maybeSingle();

        if (data != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen(userId: data['id'])),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("User @$username not found")),
          );
        }
      } catch (e) {
        debugPrint("Error navigating to user: $e");
      }
    } else {
      // Standard URL
      final Uri url = Uri.parse(link.url);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            ElevatedButton(onPressed: _loadData, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (profileData == null) return const Center(child: Text("Profile data missing"));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.userId == null || widget.userId == currentUserId;
    final avatarUrl = profileData!['avatar_url'];
    final plan = profileData!['premium_plan'] ?? 'free';
    
    final nameText = profileData!['name'] ?? "No Name";
    double nameFontSize = isLandscape ? 18 : 24; // Baseline adjusted for landscape
    if (!isLandscape) {
      if (nameText.length > 18) {
        nameFontSize = 18;
      } else if (nameText.length > 14) {
        nameFontSize = 20;
      } else if (nameText.length > 10) {
        nameFontSize = 22;
      }
    } else {
       if (nameText.length > 18) {
        nameFontSize = 14;
      } else if (nameText.length > 14) {
        nameFontSize = 16;
      }
    }

    final joinedDate = profileData?['created_at'];
    String joinedText = "Joined";
    if (joinedDate != null) {
      final date = DateTime.parse(joinedDate).toLocal();
      final formatted = DateFormat('MMMM yyyy').format(date);
      joinedText = "Joined $formatted";
    }

    // Custom Ring Color logic to avoid circular-only shapes from PremiumUtils
    final ringColor = PremiumUtils.getRingColor(plan);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 2. OVERLAPPING PREMIUM PROFILE CARD
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. PREMIUM HEADER WITH GRADIENT
                Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF003E2E), // Premium Top Left
                        Color(0xFF0B5B42), // Premium Bottom Right
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.pop(context);
                              } else {
                                tabIndexNotifier.value = 0; // Go to Home tab
                              }
                            },
                          ),
                          const Spacer(),
                          if (!isMe) ...[
                            IconButton(
                              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 22),
                              onPressed: _toggleSave,
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                              onPressed: _showEllipsisMenu,
                            ),
                          ],
                          if (isMe) ...[
                            IconButton(
                              icon: const Icon(Icons.search, size: 24, color: Colors.white),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 24, color: Colors.white),
                              onPressed: () {
                                final username = profileData?['username'] ?? 'user';
                                final message = "Check out @$username on High5 👀\n"
                                    "Username: $username\n"
                                    "Download app: https://shorturl.at/1tf4k";
                                Share.share(message);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, size: 24, color: Colors.white),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                                _loadData();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. OVERLAPPING PREMIUM PROFILE CARD
                Padding(
                  padding: const EdgeInsets.only(top: 110), // Overlap calculation (160 - 50)
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 20, 8, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar + Name Section
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center, // Perfectly center text against avatar height
                                children: [
                                  // Squircle Avatar (Premium Rounded Square)
                                  GestureDetector(
                                      onTap: () => ImageUtils.showImagePreview(context, avatarUrl),
                                    child: Container(
                                      width: 92, 
                                      height: 92,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        border: ringColor != Colors.transparent 
                                            ? Border.all(color: ringColor, width: 2.2) 
                                            : Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                        boxShadow: [
                                          if (ringColor != Colors.transparent)
                                            BoxShadow(
                                              color: ringColor.withOpacity(0.2),
                                              blurRadius: 12,
                                              spreadRadius: 0.2,
                                            ),
                                        ],
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.all(2.2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(19),
                                          border: Border.all(color: isDark ? const Color(0xFF1A1A1A) : Colors.white, width: 2.2),
                                          color: Colors.grey[200],
                                          image: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                                            ? Icon(Icons.person, size: 48, color: isDark ? Colors.white24 : Colors.grey[400])
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14), // Balanced spacing
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min, // Wrap content for centering
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: nameText,
                                                style: TextStyle(
                                                  fontSize: nameFontSize, 
                                                  fontWeight: FontWeight.w900,
                                                  color: theme.textTheme.bodyLarge?.color,
                                                  letterSpacing: -0.6,
                                                ),
                                              ),
                                              const TextSpan(text: " "),
                                              WidgetSpan(
                                                alignment: PlaceholderAlignment.middle,
                                                child: PremiumUtils.buildBadge(plan),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4), // Tighter vertical spacing
                                        Text(
                                          "@${profileData!['username'] ?? 'username'}",
                                          style: TextStyle(
                                            fontSize: isLandscape ? 12 : 14, 
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 2), 
                                        Text(
                                          joinedText,
                                          style: TextStyle(
                                            fontSize: isLandscape ? 10 : 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white30 : Colors.black26,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 14), // Profile Info -> Bio
                          // Bio with clickable @usernames and links
                          Linkify(
                            onOpen: _handleLinkClick,
                            text: profileData!['bio'] ?? "Ready to HIGH5",
                            linkifiers: const [
                              UrlLinkifier(),
                              EmailLinkifier(),
                              UserLinkifier(),
                            ],
                            style: TextStyle(
                              fontSize: isLandscape ? 13 : 14.5, 
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            linkStyle: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),

                          const SizedBox(height: 18), // Bio -> Chip
                              // Today's Questions Highlight Chip
                              if (isMe)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B5E20).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.12)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 8),
                                      Text(
                                        (plan == 'blue' || plan == 'gold') 
                                          ? "Today's questions: Unlimited" 
                                          : "Questions: $_remainingQuestions left",
                                        style: const TextStyle(
                                          fontSize: 12.5, 
                                          fontWeight: FontWeight.w800, 
                                          color: Color(0xFF2E7D32),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),
                              if (!isMe)
                                PrimaryButton(
                                  text: "ASK ME A QUESTION",
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => AskAnyUserScreen(userId: widget.userId)),
                                    ).then((_) => _loadData());
                                  },
                                ),
                              if (isMe && plan == 'free')
                                PrimaryButton(
                                  text: "GO PREMIUM",
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                                    ).then((_) => _loadData());
                                  },
                                ),

                              const SizedBox(height: 20), // Chip -> Stats
                              // Premium Stats Section
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.withOpacity(0.035),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: _buildStat("Likes", _likesCount.toString(), isLandscape)),
                                    Container(width: 1, height: 24, color: theme.dividerColor.withOpacity(0.1)),
                                    Expanded(child: _buildStat("Answers", _answers.length.toString(), isLandscape)),
                                    Container(width: 1, height: 24, color: theme.dividerColor.withOpacity(0.1)),
                                    Expanded(child: _buildStat("High5s", _high5Count.toString(), isLandscape)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 28), // Stats -> My Answers

                      // Answers Section Title
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_motion_rounded, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              "MY ANSWERS", 
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 1.5,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_loadingAnswers)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                      else if (_answers.isEmpty)
                        Center(child: Padding(padding: const EdgeInsets.only(top: 40.0), child: Text("No answers yet.", style: TextStyle(color: theme.textTheme.bodySmall?.color))))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _answers.length,
                          itemBuilder: (context, index) {
                            return AnswerCard(
                              key: ValueKey(_answers[index].id),
                              answer: _answers[index],
                              onDelete: (id) => _deleteAnswer(id),
                              onPin: (id, pin) => _togglePin(id, pin),
                              onLikeChanged: () {
                                setState(() {
                                  final current = _answers[index];
                                  _answers[index] = current.copyWith(
                                    isLiked: !current.isLiked,
                                    likeCount: current.isLiked ? current.likeCount - 1 : current.likeCount + 1,
                                  );
                                  int total = 0;
                                  for (var ans in _answers) {
                                    total += ans.likeCount;
                                  }
                                  _likesCount = total;
                                });
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, bool isLandscape) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value, 
          style: TextStyle(
            fontSize: isLandscape ? 18 : 22, 
            fontWeight: FontWeight.w900, 
            color: theme.textTheme.bodyLarge?.color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(), 
          style: TextStyle(
            fontSize: isLandscape ? 9 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

class UserLinkifier extends Linkifier {
  const UserLinkifier();

  @override
  List<LinkifyElement> parse(List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    final regex = RegExp(r"@[a-zA-Z0-9_]+", multiLine: true);

    for (var element in elements) {
      if (element is TextElement) {
        final matches = regex.allMatches(element.text);
        if (matches.isEmpty) {
          list.add(element);
        } else {
          int lastIndex = 0;
          for (var match in matches) {
            if (match.start > lastIndex) {
              list.add(TextElement(element.text.substring(lastIndex, match.start)));
            }
            list.add(LinkableElement(match.group(0)!, match.group(0)!));
            lastIndex = match.end;
          }
          if (lastIndex < element.text.length) {
            list.add(TextElement(element.text.substring(lastIndex)));
          }
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}
