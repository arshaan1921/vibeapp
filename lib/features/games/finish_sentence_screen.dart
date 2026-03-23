import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../screens/profile.dart';
import '../../utils/premium_utils.dart';

class FinishSentenceScreen extends StatefulWidget {
  const FinishSentenceScreen({super.key});

  @override
  State<FinishSentenceScreen> createState() => _FinishSentenceScreenState();
}

class _FinishSentenceScreenState extends State<FinishSentenceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sentencePosts = [];
  final _sentenceController = TextEditingController();
  final List<Map<String, dynamic>> _selectedAudience = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchSentences();
  }

  Future<void> _fetchSentences() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Filter: Show sentences created by me OR shared with me
      final response = await supabase
          .from('sentence_posts')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan), sentence_replies(count)')
          .or('user_id.eq.${user.id},shared_with.cs.{"${user.id}"}')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _sentencePosts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sentences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createSentence() async {
    final text = _sentenceController.text.trim();
    if (text.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String finalSentence = text;
      if (!finalSentence.endsWith('...')) {
        finalSentence += '...';
      }

      final List<String> audienceIds = {
        user.id,
        ..._selectedAudience.map((f) => f['id'] as String)
      }.toList();

      await supabase.from('sentence_posts').insert({
        'user_id': user.id,
        'sentence_start': finalSentence,
        'shared_with': audienceIds,
      });

      if (mounted) {
        _sentenceController.clear();
        _selectedAudience.clear();
        Navigator.pop(context);
        _fetchSentences();
      }
    } catch (e) {
      debugPrint('Error creating sentence: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _pickUsers(BuildContext context, Function(VoidCallback) setModalState) async {
    final res = await Supabase.instance.client.from('profiles').select().limit(20);
    final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final bool isSelected = _selectedAudience.any((f) => f['id'] == users[i]['id']);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: users[i]['avatar_url'] != null ? NetworkImage(users[i]['avatar_url']) : null,
                    child: users[i]['avatar_url'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(users[i]['username']),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                  onTap: () {
                    if (!isSelected) {
                      setModalState(() => _selectedAudience.add(users[i]));
                    } else {
                      setModalState(() => _selectedAudience.removeWhere((f) => f['id'] == users[i]['id']));
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start a Sentence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _sentenceController,
                  decoration: InputDecoration(
                    hintText: 'e.g., School would be better if...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  maxLength: 100,
                  autofocus: true,
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('SHARE WITH FRIENDS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                TextButton.icon(
                  onPressed: () => _pickUsers(context, setModalState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Friends'),
                ),
                Wrap(
                  spacing: 8,
                  children: _selectedAudience.map((f) => Chip(
                    label: Text(f['username']),
                    onDeleted: () => setModalState(() => _selectedAudience.remove(f)),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isCreating || _sentenceController.text.trim().isEmpty)
                        ? null
                        : () async {
                            setModalState(() => _isCreating = true);
                            await _createSentence();
                            if (mounted) {
                              setModalState(() => _isCreating = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C4E6E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('POST SENTENCE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Finish the Sentence'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        label: const Text('New Sentence'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2C4E6E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sentencePosts.isEmpty
              ? const Center(child: Text('No sentences yet. Start one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sentencePosts.length,
                  itemBuilder: (context, index) {
                    final post = _sentencePosts[index];
                    return _SentenceCard(post: post);
                  },
                ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _SentenceCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final profile = post['profiles'];
    final username = profile?['username'] ?? 'User';
    final avatarUrl = profile?['avatar_url'];
    final plan = profile?['premium_plan'] ?? 'free';
    final replyCount = (post['sentence_replies'] as List?)?.first?['count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => _SentenceDetailScreen(post: post)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: post['user_id']))),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: PremiumUtils.buildProfileRing(plan),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(username[0].toUpperCase()) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: post['user_id']))),
                    child: Row(
                      children: [
                        PremiumUtils.buildBadge(plan),
                        Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat.yMMMd().format(DateTime.parse(post['created_at'])),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post['sentence_start'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text('$replyCount replies', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const Spacer(),
                  Text(
                    'Tap to complete...',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const _SentenceDetailScreen({required this.post});

  @override
  State<_SentenceDetailScreen> createState() => _SentenceDetailScreenState();
}

class _SentenceDetailScreenState extends State<_SentenceDetailScreen> {
  final _replyController = TextEditingController();
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;
  String _sortBy = 'likes'; // 'likes' or 'newest'
  Set<String> _myLikes = {};

  @override
  void initState() {
    super.initState();
    _fetchReplies();
    _fetchMyLikes();
  }

  Future<void> _fetchMyLikes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final res = await Supabase.instance.client
        .from('sentence_reply_likes')
        .select('reply_id')
        .eq('user_id', user.id);
    
    if (mounted) {
      setState(() {
        _myLikes = (res as List).map((l) => l['reply_id'].toString()).toSet();
      });
    }
  }

  Future<void> _fetchReplies() async {
    try {
      final query = Supabase.instance.client
          .from('sentence_replies')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
          .eq('post_id', widget.post['id']);
      
      final response = await query;

      if (mounted) {
        setState(() {
          _replies = List<Map<String, dynamic>>.from(response);
          _sortReplies();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching replies: $e');
    }
  }

  void _sortReplies() {
    if (_sortBy == 'likes') {
      _replies.sort((a, b) => (b['likes_count'] ?? 0).compareTo(a['likes_count'] ?? 0));
    } else {
      _replies.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    }
  }

  Future<void> _postReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('sentence_replies').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'reply_text': text,
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
        await Supabase.instance.client
            .from('sentence_reply_likes')
            .delete()
            .eq('reply_id', replyId)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('sentence_reply_likes').insert({
          'reply_id': replyId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _fetchReplies(); // Revert on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete the Sentence')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post['sentence_start'],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C4E6E)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Started by @${widget.post['profiles']?['username']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Replies (${_replies.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, size: 20),
                  items: const [
                    DropdownMenuItem(value: 'likes', child: Text('Most Liked', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'newest', child: Text('Newest', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        _sortReplies();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _replies.isEmpty
                    ? const Center(child: Text('No completions yet. Be the first!'))
                    : ListView.builder(
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          final reply = _replies[index];
                          final profile = reply['profiles'];
                          final isLiked = _myLikes.contains(reply['id'].toString());

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: profile['id']))),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                child: profile?['avatar_url'] == null ? Text(profile['username'][0].toUpperCase()) : null,
                              ),
                            ),
                            title: Text(
                              reply['reply_text'],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text('@${profile['username']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _toggleLike(reply),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.red : Colors.grey,
                                    size: 22,
                                  ),
                                ),
                                Text('${reply['likes_count'] ?? 0}', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 10,
              left: 16,
              right: 16,
              top: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Finish the sentence...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      counterText: "",
                    ),
                    maxLength: 150,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _postReply,
                  icon: const Icon(Icons.send, color: Color(0xFF2C4E6E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
