import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/profile.dart';
import '../../utils/premium_utils.dart';

class TruthLieScreen extends StatefulWidget {
  const TruthLieScreen({super.key});

  @override
  State<TruthLieScreen> createState() => _TruthLieScreenState();
}

class _TruthLieScreenState extends State<TruthLieScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeGames = [];
  final _s1Controller = TextEditingController();
  final _s2Controller = TextEditingController();
  final _s3Controller = TextEditingController();
  int _lieIndex = 1;
  final List<Map<String, dynamic>> _selectedAudience = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('truth_lie_games')
          .select('*, profiles:user_id(id, username, avatar_url, premium_plan)')
          .or('user_id.eq.${user.id},shared_with.cs.{"${user.id}"}')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeGames = List<Map<String, dynamic>>.from(response);
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
      await Supabase.instance.client.from('truth_lie_games').delete().eq('id', gameId);
      _fetchGames();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  Future<void> _createGame(Function(VoidCallback) setModalState) async {
    final s1 = _s1Controller.text.trim();
    final s2 = _s2Controller.text.trim();
    final s3 = _s3Controller.text.trim();

    if (s1.isEmpty || s2.isEmpty || s3.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all statements')));
      return;
    }

    setModalState(() => _isCreating = true);
    setState(() => _isCreating = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final List<String> audienceIds = {
        user.id,
        ..._selectedAudience.map((f) => f['id'] as String)
      }.toList();

      await supabase.from('truth_lie_games').insert({
        'user_id': user.id,
        'statement1': s1,
        'statement2': s2,
        'statement3': s3,
        'lie_index': _lieIndex,
        'shared_with': audienceIds,
      });

      if (mounted) {
        _s1Controller.clear();
        _s2Controller.clear();
        _s3Controller.clear();
        _selectedAudience.clear();
        _lieIndex = 1;
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game posted successfully!')),
        );
        _fetchGames();
      }
    } catch (e) {
      debugPrint('Create error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setModalState(() => _isCreating = false);
        setState(() => _isCreating = false);
      }
    }
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
                  const Text('Create 2 Truths & 1 Lie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildStatementInput('Statement 1', _s1Controller),
                  _buildStatementInput('Statement 2', _s2Controller),
                  _buildStatementInput('Statement 3', _s3Controller),
                  const SizedBox(height: 20),
                  const Text('SELECT THE LIE:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 12)),
                  Row(
                    children: [1, 2, 3].map((i) => Expanded(
                      child: RadioListTile<int>(
                        title: Text('#$i'),
                        value: i,
                        groupValue: _lieIndex,
                        onChanged: (val) {
                          setModalState(() {
                            _lieIndex = val!;
                          });
                        },
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('SHARE WITH FRIENDS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  TextButton.icon(
                    onPressed: () async {
                      final res = await Supabase.instance.client.from('profiles').select().limit(20);
                      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res);
                      if (!mounted) return;
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(users[i]['username']),
                            onTap: () {
                              if (!_selectedAudience.any((f) => f['id'] == users[i]['id'])) {
                                setModalState(() => _selectedAudience.add(users[i]));
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
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
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : () => _createGame(setModalState),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                      child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('POST GAME'),
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

  Widget _buildStatementInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter a statement...',
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two Truths & One Lie'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        label: const Text('New Game'),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeGames.isEmpty
              ? const Center(child: Text('No games yet. Start one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activeGames.length,
                  itemBuilder: (context, index) => _TruthLieCard(
                    game: _activeGames[index],
                    onDelete: () => _deleteGame(_activeGames[index]['id']),
                  ),
                ),
    );
  }
}

class _TruthLieCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final VoidCallback onDelete;
  const _TruthLieCard({required this.game, required this.onDelete});

  @override
  State<_TruthLieCard> createState() => _TruthLieCardState();
}

class _TruthLieCardState extends State<_TruthLieCard> {
  int? _myVote;
  bool _hasVoted = false;
  Map<int, int> _voteCounts = {1: 0, 2: 0, 3: 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoteData();
  }

  Future<void> _loadVoteData() async {
    await Future.wait([_checkMyVote(), _fetchResults()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkMyVote() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client
        .from('truth_lie_votes')
        .select()
        .eq('game_id', widget.game['id'])
        .eq('voter_id', user.id)
        .maybeSingle();
    if (res != null) {
      setState(() {
        _hasVoted = true;
        _myVote = res['selected_statement'];
      });
    }
  }

  Future<void> _fetchResults() async {
    final res = await Supabase.instance.client
        .from('truth_lie_votes')
        .select('selected_statement')
        .eq('game_id', widget.game['id']);
    
    final counts = {1: 0, 2: 0, 3: 0};
    for (var row in (res as List)) {
      int val = row['selected_statement'];
      counts[val] = (counts[val] ?? 0) + 1;
    }
    if (mounted) setState(() => _voteCounts = counts);
  }

  Future<void> _castVote(int index) async {
    if (_hasVoted) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('truth_lie_votes').insert({
        'game_id': widget.game['id'],
        'voter_id': user.id,
        'selected_statement': index,
      });
      setState(() {
        _hasVoted = true;
        _myVote = index;
      });
      _fetchResults();
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()));

    final totalVotes = _voteCounts.values.fold(0, (sum, v) => sum + v);
    final user = Supabase.instance.client.auth.currentUser;
    final isMe = widget.game['user_id'] == user?.id;
    final showResult = _hasVoted || isMe;

    final profile = widget.game['profiles'];
    final username = profile?['username'] ?? "User";
    final avatarUrl = profile?['avatar_url'];
    final plan = profile?['premium_plan'] ?? 'free';
    final userId = widget.game['user_id'];
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
                GestureDetector(
                  onTap: () {
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: PremiumUtils.buildProfileRing(plan),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null 
                            ? Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 12)) 
                            : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          PremiumUtils.buildBadge(plan),
                          Text(
                            '@$username', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMe)
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: widget.onDelete),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Guess the lie! 🤥', 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            _buildOption(1, widget.game['statement1'], totalVotes, showResult),
            _buildOption(2, widget.game['statement2'], totalVotes, showResult),
            _buildOption(3, widget.game['statement3'], totalVotes, showResult),
            if (!showResult)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Tap a statement to guess!', 
                    style: TextStyle(
                      fontSize: 12, 
                      color: theme.textTheme.bodySmall?.color, 
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, String text, int total, bool showResult) {
    final votes = _voteCounts[index] ?? 0;
    final percent = total == 0 ? 0.0 : votes / total;
    final isLie = widget.game['lie_index'] == index;
    final isMyVote = _myVote == index;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: showResult ? null : () => _castVote(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: showResult && isLie ? Colors.red : theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
              color: showResult && isLie ? Colors.red.withOpacity(0.05) : theme.cardColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        text, 
                        style: TextStyle(
                          fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    if (showResult && isLie)
                      const Icon(Icons.error_outline, color: Colors.red, size: 16)
                    else if (isMyVote)
                      const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                  ],
                ),
                if (showResult) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: theme.dividerColor.withOpacity(0.1),
                            color: isLie ? Colors.red : Colors.blue,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(percent * 100).toInt()}%', 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
