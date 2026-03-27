import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/block_service.dart';

// --- MAIN ENTRY (LOBBY) ---
class TruthLieLobby extends StatefulWidget {
  const TruthLieLobby({super.key});
  @override
  State<TruthLieLobby> createState() => _TruthLieLobbyState();
}

class _TruthLieLobbyState extends State<TruthLieLobby> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activeGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('truth_lie_games')
          .select('*, truth_lie_participants!inner(user_id, is_seen)')
          .eq('truth_lie_participants.user_id', userId)
          .eq('status', 'active')
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
      await supabase.from('truth_lie_games').delete().eq('id', gameId);
      if (mounted) {
        setState(() {
          _activeGames.removeWhere((g) => g['id'] == gameId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game deleted")));
      }
    } catch (e) {
      debugPrint("Error deleting game: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete game: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("TWO TRUTHS & ONE LIE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF2C4E6E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchGames,
              child: _activeGames.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text("No active games. Start one with friends!", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activeGames.length,
                      itemBuilder: (context, index) {
                        final game = _activeGames[index];
                        final isCreator = game['creator_id'] == currentUserId;
                        final bool isUnseen = game['truth_lie_participants'] != null && 
                                              (game['truth_lie_participants'] as List).any((p) => p['user_id'] == currentUserId && p['is_seen'] == false);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: isUnseen ? 4 : 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Row(
                              children: [
                                if (isUnseen) 
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
                                  ),
                                Expanded(child: Text("Game ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            subtitle: Text("Started on ${game['created_at'].toString().split('T')[0]}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCreator)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Delete Game?"),
                                          content: const Text("Are you sure you want to delete this game? This action cannot be undone."),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteGame(game['id']);
                                              },
                                              child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TruthLiePlay(gameId: game['id']))).then((_) => _fetchGames()),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TruthLieFriendSelect())).then((_) => _fetchGames()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF2C4E6E),
            ),
            child: const Text("NEW GAME", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// --- FRIEND SELECTION ---
class TruthLieFriendSelect extends StatefulWidget {
  const TruthLieFriendSelect({super.key});
  @override
  State<TruthLieFriendSelect> createState() => _TruthLieFriendSelectState();
}

class _TruthLieFriendSelectState extends State<TruthLieFriendSelect> {
  final supabase = Supabase.instance.client;
  List<AppUser> _friends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final savedRows = await supabase
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', user.id);

      final List<String> savedUserIds = (savedRows as List)
          .map((item) => item['saved_user_id'] as String)
          .toList();

      if (savedUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            _friends = [];
            _isLoading = false;
          });
        }
        return;
      }

      final profilesResponse = await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', savedUserIds);

      if (mounted) {
        setState(() {
          _friends = (profilesResponse as List)
              .map((p) => AppUser.fromJson(p))
              .where((f) => !blockService.isBlocked(f.id))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friends: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SELECT FRIENDS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C4E6E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text("No saved profiles found.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _friends.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = _friends[index];
                    final isSelected = _selectedIds.contains(f.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (f.avatarUrl != null && f.avatarUrl!.isNotEmpty) ? NetworkImage(f.avatarUrl!) : null,
                        child: (f.avatarUrl == null || f.avatarUrl!.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(f.username.isNotEmpty ? f.username : (f.name ?? "User"), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF2C4E6E) : Colors.grey,
                      ),
                      onTap: () => setState(() => isSelected ? _selectedIds.remove(f.id) : _selectedIds.add(f.id)),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TruthLieSetup(selectedFriends: _friends.where((f) => _selectedIds.contains(f.id)).toList())));
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF2C4E6E),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text("NEW GAME (${_selectedIds.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// --- SETUP SCREEN ---
class TruthLieSetup extends StatefulWidget {
  final List<AppUser> selectedFriends;
  const TruthLieSetup({super.key, required this.selectedFriends});
  @override
  State<TruthLieSetup> createState() => _TruthLieSetupState();
}

class _TruthLieSetupState extends State<TruthLieSetup> {
  final supabase = Supabase.instance.client;
  final List<TextEditingController> _optCtrls = [
    TextEditingController(), // Truth 1
    TextEditingController(), // Truth 2
    TextEditingController(), // Lie
  ];
  bool _isLoading = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).single();
      if (mounted) setState(() => _userProfile = profile);
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  @override
  void dispose() {
    for (var c in _optCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _launchGame() async {
    final truths = [_optCtrls[0].text.trim(), _optCtrls[1].text.trim()];
    final lie = _optCtrls[2].text.trim();
    
    if (truths.any((t) => t.isEmpty) || lie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // 1. Create game using 'creator_id'
      final game = await supabase.from('truth_lie_games').insert({
        'creator_id': userId,
      }).select().single();
      final gameId = game['id'];

      // 2. Add participants
      final participantIds = {...widget.selectedFriends.map((f) => f.id), userId};
      final participants = participantIds.map((id) => {
        'game_id': gameId, 
        'user_id': id,
        'is_seen': id == userId,
      }).toList();
      await supabase.from('truth_lie_participants').insert(participants);

      // 3. Add setup action
      await supabase.from('truth_lie_actions').insert({
        'game_id': gameId,
        'user_id': userId,
        'action_type': 'setup',
        'data': {
          'truths': truths,
          'lie': lie,
        }
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TruthLiePlay(gameId: gameId)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint("Error launching game: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("SETUP GAME", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C4E6E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_userProfile != null) ...[
              CircleAvatar(
                radius: 40,
                backgroundImage: (_userProfile!['avatar_url'] != null && _userProfile!['avatar_url'] != '')
                    ? NetworkImage(_userProfile!['avatar_url'])
                    : null,
                child: (_userProfile!['avatar_url'] == null || _userProfile!['avatar_url'] == '')
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 12),
              Text("@${_userProfile!['username'] ?? 'User'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Add two truths about yourself", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 12),
            _buildInput(_optCtrls[0], "Truth 1"),
            const SizedBox(height: 12),
            _buildInput(_optCtrls[1], "Truth 2"),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Add one lie", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 12),
            _buildInput(_optCtrls[2], "The Lie", isLie: true),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _launchGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C4E6E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("LAUNCH GAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {bool isLie = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLie ? Colors.redAccent.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// --- PLAY SCREEN ---
class TruthLiePlay extends StatefulWidget {
  final String gameId;
  const TruthLiePlay({super.key, required this.gameId});
  @override
  State<TruthLiePlay> createState() => _TruthLiePlayState();
}

class _TruthLiePlayState extends State<TruthLiePlay> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _game;
  Map<String, dynamic>? _creatorProfile;
  List<String> _shuffledStatements = [];
  int? _lieIndexInShuffled; 
  bool _isLoading = true;
  String? _votedForStatement;
  bool _isExpired = false;
  Map<int, int> _voteCounts = {0: 0, 1: 0, 2: 0};
  int _totalVotes = 0;
  Timer? _countdownTimer;
  String _timeRemaining = "";

  @override
  void initState() {
    super.initState();
    _loadGame();
    _markAsSeen();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _markAsSeen() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('truth_lie_participants')
          .update({'is_seen': true})
          .match({'game_id': widget.gameId, 'user_id': userId});
    } catch (e) {
      debugPrint("Error marking as seen: $e");
    }
  }

  Future<void> _loadGame() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final game = await supabase.from('truth_lie_games').select().eq('id', widget.gameId).single();
      
      final createdAt = DateTime.parse(game['created_at']);
      final now = DateTime.now();
      final isExpired = now.difference(createdAt).inHours >= 24;

      if (!isExpired) {
        _startCountdown(createdAt);
      }

      final creatorProfile = await supabase.from('profiles').select().eq('id', game['creator_id']).single();

      final setupAction = await supabase.from('truth_lie_actions').select().eq('game_id', widget.gameId).eq('action_type', 'setup').single();
      
      final List<String> truths = List<String>.from(setupAction['data']['truths']);
      final String lie = setupAction['data']['lie'];

      final all = [...truths, lie];
      final seed = widget.gameId.hashCode;
      all.sort(); // Stable initial order
      
      // Deterministic shuffle
      if (seed % 3 == 0) {
        final t = all[0]; all[0] = all[1]; all[1] = t;
      } else if (seed % 3 == 1) {
        final t = all[1]; all[1] = all[2]; all[2] = t;
      } else {
        final t = all[0]; all[0] = all[2]; all[2] = t;
      }
      
      _lieIndexInShuffled = all.indexOf(lie);
      _shuffledStatements = all;
      
      final vote = await supabase.from('truth_lie_actions').select().eq('game_id', widget.gameId).eq('user_id', userId).eq('action_type', 'vote').maybeSingle();

      if (isExpired) {
        final votesResponse = await supabase.from('truth_lie_actions').select('data').eq('game_id', widget.gameId).eq('action_type', 'vote');
        final Map<int, int> counts = {0: 0, 1: 0, 2: 0};
        for (var v in (votesResponse as List)) {
          final idx = v['data']['index'] as int;
          counts[idx] = (counts[idx] ?? 0) + 1;
        }
        _voteCounts = counts;
        _totalVotes = votesResponse.length;
      }

      if (mounted) {
        setState(() {
          _game = game;
          _isExpired = isExpired;
          _creatorProfile = creatorProfile;
          _votedForStatement = vote?['data']?['statement'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading game: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown(DateTime createdAt) {
    _countdownTimer?.cancel();
    final expiryTime = createdAt.add(const Duration(hours: 24));
    _updateTime(expiryTime);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime(expiryTime);
    });
  }

  void _updateTime(DateTime expiryTime) {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _isExpired = true;
          _timeRemaining = "Ended";
        });
        _loadGame(); 
      }
      return;
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    if (mounted) {
      setState(() {
        _timeRemaining = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _vote(int index, String statement) async {
    if (_votedForStatement != null || _isExpired) return;
    final userId = supabase.auth.currentUser!.id;
    if (userId == _game!['creator_id']) return;

    try {
      await supabase.from('truth_lie_actions').insert({
        'game_id': widget.gameId,
        'user_id': userId,
        'action_type': 'vote',
        'data': {'index': index, 'statement': statement},
      });
      setState(() => _votedForStatement = statement);
    } catch (e) {
      debugPrint("Error voting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_game == null) return const Scaffold(body: Center(child: Text("Game not found")));

    final currentUserId = supabase.auth.currentUser?.id;
    final isCreator = _game!['creator_id'] == currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(_isExpired ? "RESULTS" : "GUESS THE LIE"), 
        backgroundColor: const Color(0xFF2C4E6E), 
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_creatorProfile != null) ...[
              CircleAvatar(
                radius: 35,
                backgroundImage: (_creatorProfile!['avatar_url'] != null && _creatorProfile!['avatar_url'] != '')
                    ? NetworkImage(_creatorProfile!['avatar_url'])
                    : null,
                child: (_creatorProfile!['avatar_url'] == null || _creatorProfile!['avatar_url'] == '')
                    ? const Icon(Icons.person, size: 35)
                    : null,
              ),
              const SizedBox(height: 8),
              Text("@${_creatorProfile!['username'] ?? 'User'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ],
            
            if (!_isExpired) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text("Ends in: $_timeRemaining", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text("Which one is the lie? 🤥", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),

            ...List.generate(_shuffledStatements.length, (i) {
              final statement = _shuffledStatements[i];
              final isLie = i == _lieIndexInShuffled;
              final isVoted = _votedForStatement == statement;
              final voteCount = _voteCounts[i] ?? 0;
              final percentage = _totalVotes > 0 ? (voteCount / _totalVotes) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: (isCreator || _isExpired || _votedForStatement != null) ? null : () => _vote(i, statement),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isExpired 
                          ? (isLie ? Colors.green : (isVoted ? Colors.red : Colors.grey.shade200))
                          : (isVoted ? Colors.blue : Colors.grey.shade200),
                        width: 2,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(statement, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                            if (_isExpired && isLie) const Icon(Icons.check_circle, color: Colors.green),
                            if (_isExpired && !isLie && isVoted) const Icon(Icons.cancel, color: Colors.red),
                            if (!_isExpired && isVoted) const Icon(Icons.check_circle, color: Colors.blue),
                          ],
                        ),
                        if (_isExpired) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: Colors.grey[100],
                              color: isLie ? Colors.green : Colors.blue.withOpacity(0.5),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text("$voteCount votes (${(percentage * 100).toInt()}%)", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            if (isCreator && !_isExpired) 
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text("You created this game. Wait for friends to vote!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            
            if (_votedForStatement != null && !_isExpired)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text("Vote cast! Results will be visible when the game ends.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
