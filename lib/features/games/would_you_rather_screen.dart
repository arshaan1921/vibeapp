import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/profile.dart';
import '../../utils/premium_utils.dart';

class WouldYouRatherScreen extends StatefulWidget {
  const WouldYouRatherScreen({super.key});

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _wyrPosts = [];
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchWYR();
  }

  Future<void> _fetchWYR() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('wyr_posts')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _wyrPosts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching WYR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createWYR() async {
    final opt1 = _option1Controller.text.trim();
    final opt2 = _option2Controller.text.trim();
    if (opt1.isEmpty || opt2.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('wyr_posts').insert({
        'user_id': user.id,
        'option_1': opt1,
        'option_2': opt2,
      });

      if (mounted) {
        _option1Controller.clear();
        _option2Controller.clear();
        Navigator.pop(context);
        _fetchWYR();
      }
    } catch (e) {
      debugPrint('Error creating WYR: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
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
                const Text('Create Would You Rather', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _option1Controller,
                  decoration: InputDecoration(
                    labelText: 'Option 1',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  maxLength: 50,
                  onChanged: (_) => setModalState(() {}),
                ),
                const Center(child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(height: 8),
                TextField(
                  controller: _option2Controller,
                  decoration: InputDecoration(
                    labelText: 'Option 2',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  maxLength: 50,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isCreating || _option1Controller.text.isEmpty || _option2Controller.text.isEmpty)
                        ? null
                        : () async {
                            setModalState(() => _isCreating = true);
                            await _createWYR();
                            if (mounted) setModalState(() => _isCreating = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCreating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('POST GAME'),
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
      appBar: AppBar(title: const Text('Would You Rather'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        label: const Text('New Game'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.purpleAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wyrPosts.isEmpty
              ? const Center(child: Text('No games yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _wyrPosts.length,
                  itemBuilder: (context, index) => _WYRCard(post: _wyrPosts[index]),
                ),
    );
  }
}

class _WYRCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _WYRCard({required this.post});

  @override
  State<_WYRCard> createState() => _WYRCardState();
}

class _WYRCardState extends State<_WYRCard> {
  int? _votedOption;
  bool _hasVoted = false;
  int _opt1Votes = 0;
  int _opt2Votes = 0;
  bool _loadingResults = true;

  @override
  void initState() {
    super.initState();
    _loadVoteData();
  }

  Future<void> _loadVoteData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final voteRes = await Supabase.instance.client
        .from('wyr_votes')
        .select()
        .eq('post_id', widget.post['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    final resultsRes = await Supabase.instance.client
        .from('wyr_votes')
        .select('option_index')
        .eq('post_id', widget.post['id']);

    if (mounted) {
      setState(() {
        if (voteRes != null) {
          _hasVoted = true;
          _votedOption = voteRes['option_index'];
        }
        _opt1Votes = (resultsRes as List).where((v) => v['option_index'] == 1).length;
        _opt2Votes = resultsRes.where((v) => v['option_index'] == 2).length;
        _loadingResults = false;
      });
    }
  }

  Future<void> _castVote(int index) async {
    if (_hasVoted) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('wyr_votes').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'option_index': index,
      });
      _loadVoteData();
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'];
    final username = profile?['username'] ?? 'User';
    final avatarUrl = profile?['avatar_url'];
    final plan = profile?['premium_plan'] ?? 'free';
    final total = _opt1Votes + _opt2Votes;
    final p1 = total == 0 ? 0.0 : _opt1Votes / total;
    final p2 = total == 0 ? 0.0 : _opt2Votes / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.post['user_id']))),
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
                PremiumUtils.buildBadge(plan),
                Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Would You Rather...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildOption(1, widget.post['option_1'], p1, _votedOption == 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
            ),
            _buildOption(2, widget.post['option_2'], p2, _votedOption == 2),
            if (_hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text('$total total votes', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, String text, double percent, bool isMyVote) {
    return InkWell(
      onTap: _hasVoted ? null : () => _castVote(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isMyVote ? Colors.purpleAccent : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
          color: isMyVote ? Colors.purpleAccent.withOpacity(0.05) : Colors.white,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(text, style: TextStyle(fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal))),
                if (_hasVoted) Text('${(percent * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (_hasVoted) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey[100],
                color: Colors.purpleAccent,
                minHeight: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
