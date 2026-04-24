import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/answer.dart';
import '../widgets/primary_button.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../utils/premium_utils.dart';
import 'ask_any_user.dart';
import 'premium.dart';
import '../widgets/answer_card.dart';
import '../services/notification_service.dart';
import 'blocked_users_screen.dart';
import '../services/block_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

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
  int _v1beCount = 0;
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
      _fetchV1besCount(),
    ]);
  }

  Future<void> _fetchV1besCount() async {
    try {
      final supabase = Supabase.instance.client;
      final targetId = widget.userId ?? supabase.auth.currentUser?.id;
      if (targetId == null) return;

      final response = await supabase.rpc('get_profile_v1bes', params: {'uid': targetId});
      if (mounted) {
        setState(() {
          _v1beCount = response as int;
        });
      }
    } catch (e) {
      debugPrint("Error fetching V1BEs count: $e");
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
                "body": "@${saverProfile['username']} saved your profile to their V1BEs!",
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
      _fetchV1besCount();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.userId == null || widget.userId == currentUserId;
    final avatarUrl = profileData!['avatar_url'];
    final plan = profileData!['premium_plan'] ?? 'free';
    
    final joinedDate = profileData?['created_at'];
    String joinedText = "Joined";
    if (joinedDate != null) {
      final date = DateTime.parse(joinedDate).toLocal();
      final formatted = DateFormat('MMMM yyyy').format(date);
      joinedText = "Joined $formatted";
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      IconButton(
                        icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                        color: theme.iconTheme.color,
                        onPressed: _toggleSave,
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        color: theme.iconTheme.color,
                        onPressed: _showEllipsisMenu,
                      ),
                    ],
                    if (isMe) ...[
                      IconButton(
                        icon: const Icon(Icons.search, size: 24),
                        color: theme.iconTheme.color,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 24),
                        color: theme.iconTheme.color,
                        onPressed: () {
                          final username = profileData?['username'] ?? 'user';

                          final message =
                              "Check out @$username on V1BE 👀\n"
                              "Username: $username\n"
                              "Download app: https://shorturl.at/1tf4k";

                          Share.share(message);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 24),
                        color: theme.iconTheme.color,
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                          _loadData();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: PremiumUtils.buildProfileRing(plan, width: 3),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: theme.cardColor,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.grey,
                          backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty) 
                              ? NetworkImage(avatarUrl) 
                              : null,
                          child: (avatarUrl == null || avatarUrl.toString().isEmpty) 
                              ? const Icon(Icons.person, size: 45, color: Colors.white) 
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PremiumUtils.buildBadge(plan),
                              Flexible(
                                child: Text(
                                  profileData!['name'] ?? "No Name",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "@${profileData!['username'] ?? 'username'}",
                            style: TextStyle(fontSize: 15, color: theme.textTheme.bodySmall?.color),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            joinedText,
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  profileData!['bio'] ?? "Ready to V 1 B E",
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                ),
              ),

              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 12),
                  child: Text(
                    (plan == 'blue' || plan == 'gold') 
                      ? "Today's questions: Unlimited" 
                      : "Today's remaining questions: $_remainingQuestions",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.primaryColor),
                  ),
                ),

              const SizedBox(height: 24),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: "QUESTION",
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: "MESSAGE",
                          onPressed: () async {
                            try {
                              final convId = await chatService.getOrCreateConversation(widget.userId!);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      conversationId: convId,
                                      otherUserId: widget.userId!,
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
                        ),
                      ),
                    ],
                  ),
                ),
              if (isMe && plan == 'free')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PrimaryButton(
                    text: "GO PREMIUM",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      ).then((_) => _loadData());
                    },
                  ),
                ),

              const SizedBox(height: 24),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildStat("Likes", _likesCount.toString())),
                  Expanded(child: _buildStat("Answers", _answers.length.toString())),
                  Expanded(child: _buildStat("V1BEs", _v1beCount.toString())),
                ],
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: theme.dividerColor),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text("MY ANSWERS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color)),
                    ),
                    const SizedBox(height: 16),
                    _loadingAnswers
                        ? const Center(child: CircularProgressIndicator())
                        : _answers.isEmpty
                            ? Center(child: Padding(padding: const EdgeInsets.only(top: 24.0), child: Text("No answers yet.", style: TextStyle(color: theme.textTheme.bodySmall?.color))))
                            : ListView.builder(
                                shrinkWrap: true,
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
                                          likeCount: current.isLiked 
                                              ? current.likeCount - 1 
                                              : current.likeCount + 1,
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
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
      ],
    );
  }
}
