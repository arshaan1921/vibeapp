import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../screens/profile.dart';
import '../../utils/premium_utils.dart';

class RoastMeScreen extends StatefulWidget {
  const RoastMeScreen({super.key});

  @override
  State<RoastMeScreen> createState() => _RoastMeScreenState();
}

class _RoastMeScreenState extends State<RoastMeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _roastPosts = [];

  @override
  void initState() {
    super.initState();
    _fetchRoasts();
  }

  Future<void> _fetchRoasts() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch roasts where user is the creator OR invited in roast_viewers
      // We join roast_viewers and use an OR filter
      final response = await supabase
          .from('roast_posts')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan), roast_replies(count), roast_viewers!left(user_id)')
          .or('user_id.eq.${user.id},roast_viewers.user_id.eq.${user.id}')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          // Filter duplicates that might arise from the join if not handled by Supabase automatically
          final List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(response);
          final Map<String, Map<String, dynamic>> uniqueRoasts = {};
          for (var item in rawList) {
            uniqueRoasts[item['id'].toString()] = item;
          }
          
          _roastPosts = uniqueRoasts.values.toList();
          // Sort again just in case unique conversion scrambled order
          _roastPosts.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching roasts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Roast Me 😈', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoastCreateScreen()),
          );
          if (result == true) _fetchRoasts();
        },
        label: const Text('Start a Roast'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRoasts,
              child: _roastPosts.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(
                          child: Text(
                            'No roasts yet. Be the first one 😈',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _roastPosts.length,
                      itemBuilder: (context, index) {
                        return _RoastCard(post: _roastPosts[index], onRefresh: _fetchRoasts);
                      },
                    ),
            ),
    );
  }
}

class _RoastCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  const _RoastCard({required this.post, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final profile = post['profiles'];
    final username = profile?['username'] ?? 'User';
    final avatarUrl = profile?['avatar_url'];
    final plan = profile?['premium_plan'] ?? 'free';
    final replyCount = (post['roast_replies'] as List?)?.first?['count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: post['user_id']))),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: PremiumUtils.buildProfileRing(plan),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? Text(username[0].toUpperCase()) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PremiumUtils.buildBadge(plan),
                          Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Text(
                        DateFormat.yMMMd().format(DateTime.parse(post['created_at'])),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post['roast_text'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('$replyCount replies', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoastRepliesScreen(post: post)),
                    );
                    onRefresh();
                  },
                  icon: const Icon(Icons.local_fire_department, size: 16),
                  label: const Text('Roast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoastCreateScreen extends StatefulWidget {
  const RoastCreateScreen({super.key});

  @override
  State<RoastCreateScreen> createState() => _RoastCreateScreenState();
}

class _RoastCreateScreenState extends State<RoastCreateScreen> {
  final _roastController = TextEditingController();
  final List<Map<String, dynamic>> _selectedViewers = [];
  bool _isPosting = false;

  Future<void> _postRoast() async {
    final text = _roastController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("What should they roast? Type something!")));
      return;
    }

    setState(() => _isPosting = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final postRes = await supabase.from('roast_posts').insert({
        'user_id': user.id,
        'roast_text': text,
      }).select().single();

      final postId = postRes['id'];

      if (_selectedViewers.isNotEmpty) {
        final viewersData = _selectedViewers.map((v) => {
          'post_id': postId,
          'user_id': v['id'],
        }).toList();
        await supabase.from('roast_viewers').insert(viewersData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error posting roast: $e');
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectFriends() async {
    final supabase = Supabase.instance.client;
    final res = await supabase.from('profiles').select().limit(50);
    final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res);
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Invite Friends to Roast You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final isSelected = _selectedViewers.any((v) => v['id'] == users[i]['id']);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: users[i]['avatar_url'] != null ? NetworkImage(users[i]['avatar_url']) : null,
                        child: users[i]['avatar_url'] == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(users[i]['username']),
                      trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.redAccent : Colors.grey),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedViewers.removeWhere((v) => v['id'] == users[i]['id']);
                          } else {
                            _selectedViewers.add(users[i]);
                          }
                        });
                        setModalState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a Roast')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Challenge your friends to roast you! 🔥",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _roastController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "e.g., Roast my sense of style...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Visible to:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                TextButton.icon(
                  onPressed: _selectFriends,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text("Select Friends"),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
            ),
            if (_selectedViewers.isEmpty)
              const Text("Everyone (Public)", style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                children: _selectedViewers.map((v) => Chip(
                  label: Text(v['username']),
                  onDeleted: () => setState(() => _selectedViewers.remove(v)),
                  deleteIconColor: Colors.redAccent,
                )).toList(),
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _postRoast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isPosting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('POST ROAST REQUEST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoastRepliesScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const RoastRepliesScreen({super.key, required this.post});

  @override
  State<RoastRepliesScreen> createState() => _RoastRepliesScreenState();
}

class _RoastRepliesScreenState extends State<RoastRepliesScreen> {
  final _replyController = TextEditingController();
  List<Map<String, dynamic>> _replies = [];
  Set<String> _myLikes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchReplies(), _fetchMyLikes()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchReplies() async {
    final res = await Supabase.instance.client
        .from('roast_replies')
        .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
        .eq('post_id', widget.post['id'])
        .order('created_at', ascending: false);
    
    if (mounted) {
      setState(() {
        _replies = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  Future<void> _fetchMyLikes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final res = await Supabase.instance.client
        .from('roast_likes')
        .select('reply_id')
        .eq('user_id', user.id);
    
    if (mounted) {
      setState(() {
        _myLikes = (res as List).map((l) => l['reply_id'].toString()).toSet();
      });
    }
  }

  Future<void> _postReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('roast_replies').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'roast_reply': text,
      });

      _replyController.clear();
      FocusScope.of(context).unfocus();
      _fetchReplies();
    } catch (e) {
      debugPrint('Error posting reply: $e');
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> reply) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final replyId = reply['id'].toString();
    final isLiked = _myLikes.contains(replyId);

    setState(() {
      if (isLiked) {
        _myLikes.remove(replyId);
        reply['likes_count'] = (reply['likes_count'] ?? 0) - 1;
      } else {
        _myLikes.add(replyId);
        reply['likes_count'] = (reply['likes_count'] ?? 0) + 1;
      }
    });

    try {
      if (isLiked) {
        await Supabase.instance.client.from('roast_likes').delete().eq('reply_id', replyId).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('roast_likes').insert({'reply_id': replyId, 'user_id': user.id});
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _fetchReplies(); // Revert/Refresh on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final creator = widget.post['profiles'];
    final creatorPlan = creator?['premium_plan'] ?? 'free';

    return Scaffold(
      appBar: AppBar(title: const Text('Roast Thread')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PremiumUtils.buildBadge(creatorPlan),
                            Text('@${creator?['username']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            const Text(' asked to be roasted:', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(widget.post['roast_text'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('REPLIES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                  else if (_replies.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("No roasts yet. Be brutal! 🔥", style: TextStyle(color: Colors.grey))))
                  else
                    ..._replies.map((reply) {
                      final profile = reply['profiles'];
                      final isLiked = _myLikes.contains(reply['id'].toString());
                      final plan = profile?['premium_plan'] ?? 'free';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: profile['id']))),
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: PremiumUtils.buildProfileRing(plan),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                  child: profile?['avatar_url'] == null ? Text(profile['username'][0].toUpperCase()) : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('@${profile['username']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(reply['roast_reply'], style: const TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => _toggleLike(reply),
                                        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: isLiked ? Colors.red : Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${reply['likes_count'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(width: 16),
                                      Text(DateFormat.jm().format(DateTime.parse(reply['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, left: 16, right: 16, top: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Enter your roast...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      counterText: "",
                    ),
                    maxLength: 200,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: IconButton(
                    onPressed: _postReply,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
