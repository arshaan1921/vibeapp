import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/profile.dart';
import '../../services/block_service.dart';

class MostLikelyScreen extends StatefulWidget {
  const MostLikelyScreen({super.key});

  @override
  State<MostLikelyScreen> createState() => _MostLikelyScreenState();
}

class _MostLikelyScreenState extends State<MostLikelyScreen> {
  final _questionController = TextEditingController();
  final List<Map<String, dynamic>> _selectedOptions = [];
  final List<Map<String, dynamic>> _selectedAudience = [];
  bool _isCreating = false;
  List<Map<String, dynamic>> _activeGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    _questionController.dispose();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _activeGames = _activeGames.where((g) => !blockService.isBlocked(g['created_by'])).toList();
      });
    }
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchActiveGames();
  }

  Future<void> _fetchActiveGames() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch games where the user is either the creator OR listed in the shared_with array
      final response = await supabase
          .from('most_likely_questions')
          .select('*, profiles:created_by(username, avatar_url)')
          .or('created_by.eq.${user.id},shared_with.cs.{"${user.id}"}')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeGames = List<Map<String, dynamic>>.from(response)
              .where((g) => !blockService.isBlocked(g['created_by']))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching games: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGame(String gameId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('most_likely_questions').delete().eq('id', gameId);
      
      if (mounted) {
        setState(() {
          _activeGames.removeWhere((g) => g['id'] == gameId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game deleted')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting game: $e');
    }
  }

  Future<void> _createGame() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question and select at least one option')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Options: The users you can vote FOR
      final optionIds = _selectedOptions.map((f) => f['id'] as String).toList();
      
      // shared_with: All users who can SEE and VOTE in this game
      // This includes the creator, the options, and additional invited users
      final Set<String> audienceIds = {
        user!.id,
        ...optionIds,
        ..._selectedAudience.map((f) => f['id'] as String)
      };

      await supabase.from('most_likely_questions').insert({
        'question': question,
        'created_by': user.id,
        'options': optionIds,
        'shared_with': audienceIds.toList(),
      });

      _questionController.clear();
      _selectedOptions.clear();
      _selectedAudience.clear();
      _fetchActiveGames();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating game: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch game: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _pickUsers(BuildContext context, List<Map<String, dynamic>> targetList, Function(VoidCallback) setModalState, {int max = 5, String title = "Select Users"}) async {
    final res = await Supabase.instance.client.from('profiles').select().limit(20);
    final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res)
        .where((u) => !blockService.isBlocked(u['id']))
        .toList();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final bool isSelected = targetList.any((f) => f['id'] == users[i]['id']);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(users[i]['username']),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                  onTap: () {
                    if (!isSelected) {
                      if (targetList.length < max) {
                        setModalState(() => targetList.add(users[i]));
                      }
                    } else {
                      setModalState(() => targetList.removeWhere((f) => f['id'] == users[i]['id']));
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
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.all(Radius.circular(2))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Who Is Most Likely To...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Become a billionaire?',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Section 1: Options (Who to vote for)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(child: Text('VOTE OPTIONS (MAX 5)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      TextButton.icon(
                        onPressed: () => _pickUsers(context, _selectedOptions, setModalState, max: 5, title: "Who can be voted for?"),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: _selectedOptions.map((f) => Chip(
                      label: Text(f['username']),
                      onDeleted: () => setModalState(() => _selectedOptions.remove(f)),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                    )).toList(),
                  ),
                  
                  const Divider(height: 32),

                  // Section 2: Audience (Who can see/vote)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(child: Text('ADDITIONAL VIEWERS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      TextButton.icon(
                        onPressed: () => _pickUsers(context, _selectedAudience, setModalState, max: 20, title: "Who else can see this?"),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const Text('The creator and options are included automatically.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Wrap(
                    spacing: 8,
                    children: _selectedAudience.map((f) => Chip(
                      label: Text(f['username']),
                      onDeleted: () => setModalState(() => _selectedAudience.remove(f)),
                      backgroundColor: Colors.grey.withOpacity(0.1),
                    )).toList(),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('LAUNCH GAME', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Most Likely To'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        label: const Text('New Game'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeGames.isEmpty
              ? const Center(child: Text('No active games. Start one with friends!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activeGames.length,
                  itemBuilder: (context, index) => _GameVotingCard(
                    game: _activeGames[index],
                    onDelete: () => _deleteGame(_activeGames[index]['id']),
                  ),
                ),
    );
  }
}

class _GameVotingCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final VoidCallback onDelete;
  const _GameVotingCard({required this.game, required this.onDelete});

  @override
  State<_GameVotingCard> createState() => _GameVotingCardState();
}

class _GameVotingCardState extends State<_GameVotingCard> {
  String? _votedFor;
  bool _hasVoted = false;
  Map<String, int> _results = {};
  List<Map<String, dynamic>> _participants = [];
  bool _loadingResults = true;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    await Future.wait([
      _checkVoteStatus(),
      _fetchResults(),
      _fetchParticipantProfiles(),
    ]);
    if (mounted) setState(() => _loadingResults = false);
  }

  Future<void> _checkVoteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client
        .from('most_likely_votes')
        .select()
        .eq('question_id', widget.game['id'])
        .eq('voter_id', user.id)
        .maybeSingle();
    
    if (mounted && res != null) {
      setState(() {
        _hasVoted = true;
        _votedFor = res['voted_for_user'];
      });
    }
  }

  Future<void> _fetchResults() async {
    final res = await Supabase.instance.client
        .from('most_likely_votes')
        .select('voted_for_user')
        .eq('question_id', widget.game['id']);
    
    final counts = <String, int>{};
    for (var row in (res as List)) {
      final id = row['voted_for_user'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    if (mounted) setState(() => _results = counts);
  }

  Future<void> _fetchParticipantProfiles() async {
    final List<dynamic> optionIds = widget.game['options'] ?? [];
    if (optionIds.isEmpty) return;

    final res = await Supabase.instance.client
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', optionIds);
    
    if (mounted) setState(() => _participants = List<Map<String, dynamic>>.from(res));
  }

  Future<void> _castVote(String targetUserId) async {
    if (_hasVoted) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('most_likely_votes').insert({
        'question_id': widget.game['id'],
        'voter_id': user!.id,
        'voted_for_user': targetUserId,
      });

      setState(() {
        _hasVoted = true;
        _votedFor = targetUserId;
      });
      _fetchResults();
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  void _navigateToProfile(String? userId) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingResults) return const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()));

    final totalVotes = _results.values.fold(0, (sum, v) => sum + v);
    final user = Supabase.instance.client.auth.currentUser;
    final isCreator = widget.game['created_by'] == user?.id;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.psychology, color: Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Who is most likely to...', 
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color, 
                                fontSize: 12, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.game['question'], 
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: GestureDetector(
                                onTap: () => _navigateToProfile(widget.game['created_by']),
                                child: Text(
                                  'Started by @${widget.game['profiles']['username']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCreator)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Game?'),
                          content: const Text('This will permanently remove the game and all votes.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onDelete();
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ..._participants.map((p) {
              final votes = _results[p['id']] ?? 0;
              final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
              final isMyVote = p['id'] == _votedFor;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: _hasVoted ? null : () => _castVote(p['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '@${p['username']}', 
                                style: TextStyle(
                                  fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal, 
                                  color: isMyVote ? Colors.blue : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              if (isMyVote) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: Colors.blue)),
                            ],
                          ),
                          if (_hasVoted) Text(
                            '${(percent * 100).toInt()}%', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _hasVoted ? percent : 0,
                          backgroundColor: theme.dividerColor.withOpacity(0.1),
                          color: isMyVote ? Colors.blue : Colors.blue.withOpacity(0.3),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_hasVoted)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Tap a friend to vote!', 
                    style: TextStyle(
                      fontSize: 12, 
                      color: theme.textTheme.bodySmall?.color, 
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '$totalVotes total votes cast', 
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
