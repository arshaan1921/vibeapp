import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/block_service.dart';
import '../../screens/profile.dart';

// --- MAIN ENTRY (LOBBY) ---
class WouldYouRatherLobby extends StatefulWidget {
  const WouldYouRatherLobby({super.key});
  @override
  State<WouldYouRatherLobby> createState() => _WouldYouRatherLobbyState();
}

class _WouldYouRatherLobbyState extends State<WouldYouRatherLobby> {
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
    if (userId == null) return;

    try {
      final response = await supabase
          .from('would_you_rather_games')
          .select('*, would_you_rather_participants!inner(user_id, is_seen)')
          .eq('would_you_rather_participants.user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeGames = List<Map<String, dynamic>>.from(response)
              .where((g) => !blockService.isBlocked(g['creator_id']))
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
      await supabase.from('would_you_rather_games').delete().eq('id', gameId);
      _fetchGames();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game deleted")));
    } catch (e) {
      debugPrint("Error deleting game: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("WOULD YOU RATHER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
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
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C4E6E),
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.compare_arrows_rounded, size: 48, color: Colors.white),
                          const SizedBox(height: 16),
                          const Text(
                            "The Ultimate Dilemma",
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Choose your side and see what your friends picked!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (_activeGames.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text("No active games. Start one with friends!", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final game = _activeGames[index];
                            final isCreator = game['creator_id'] == currentUserId;
                            final bool isUnseen = game['would_you_rather_participants'] != null && 
                                                  (game['would_you_rather_participants'] as List).any((p) => p['user_id'] == currentUserId && p['is_seen'] == false);

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
                                        onPressed: () => _deleteGame(game['id']),
                                      ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WouldYouRatherPlay(gameId: game['id']))).then((_) => _fetchGames()),
                              ),
                            );
                          },
                          childCount: _activeGames.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WouldYouRatherFriendSelect())).then((_) => _fetchGames()),
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
class WouldYouRatherFriendSelect extends StatefulWidget {
  const WouldYouRatherFriendSelect({super.key});
  @override
  State<WouldYouRatherFriendSelect> createState() => _WouldYouRatherFriendSelectState();
}

class _WouldYouRatherFriendSelectState extends State<WouldYouRatherFriendSelect> {
  final supabase = Supabase.instance.client;
  List<AppUser> _friends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      List<AppUser> initialList = [];
      if (savedUserIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('*')
            .inFilter('id', savedUserIds);
        initialList = (profilesResponse as List).map((p) => AppUser.fromJson(p)).toList();
      }

      // Also discover some general profiles if list is empty or short
      final discoverRes = await supabase.from('profiles').select('*').neq('id', user.id).limit(20);
      final List<AppUser> discovered = (discoverRes as List).map((p) => AppUser.fromJson(p)).toList();

      if (mounted) {
        setState(() {
          final all = {...initialList, ...discovered}.toList();
          _friends = all.where((f) => !blockService.isBlocked(f.id)).toList();
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
    final filtered = _friends.where((f) => f.username.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("No users found."))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final f = filtered[index];
                          final isSelected = _selectedIds.contains(f.id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (f.avatarUrl != null && f.avatarUrl!.isNotEmpty) ? NetworkImage(f.avatarUrl!) : null,
                              child: (f.avatarUrl == null || f.avatarUrl!.isEmpty) ? const Icon(Icons.person) : null,
                            ),
                            title: Text(f.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? const Color(0xFF2C4E6E) : Colors.grey,
                            ),
                            onTap: () => setState(() => isSelected ? _selectedIds.remove(f.id) : _selectedIds.add(f.id)),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => WouldYouRatherSetup(selectedFriends: _friends.where((f) => _selectedIds.contains(f.id)).toList())));
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
class WouldYouRatherSetup extends StatefulWidget {
  final List<AppUser> selectedFriends;
  const WouldYouRatherSetup({super.key, required this.selectedFriends});

  @override
  State<WouldYouRatherSetup> createState() => _WouldYouRatherSetupState();
}

class _WouldYouRatherSetupState extends State<WouldYouRatherSetup> {
  final supabase = Supabase.instance.client;
  final _opt1Ctrl = TextEditingController();
  final _opt2Ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _opt1Ctrl.dispose();
    _opt2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _launchGame() async {
    final opt1 = _opt1Ctrl.text.trim();
    final opt2 = _opt2Ctrl.text.trim();
    if (opt1.isEmpty || opt2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill both options")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final expiry = DateTime.now().add(const Duration(hours: 24));
      
      final game = await supabase.from('would_you_rather_games').insert({
        'creator_id': userId,
        'ends_at': expiry.toIso8601String()
      }).select().single();
      final gameId = game['id'];

      final participantIds = {...widget.selectedFriends.map((f) => f.id), userId};
      final participants = participantIds.map((id) => {
        'game_id': gameId, 
        'user_id': id,
        'is_seen': id == userId,
      }).toList();
      await supabase.from('would_you_rather_participants').insert(participants);

      await supabase.from('would_you_rather_actions').insert({
        'game_id': gameId,
        'user_id': userId,
        'action_type': 'setup',
        'data': {
          'question': "Would you rather...",
          'option_a': opt1,
          'option_b': opt2,
        }
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => WouldYouRatherPlay(gameId: gameId)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint('Error starting game: $e');
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
        title: const Text("WOULD YOU RATHER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
            const SizedBox(height: 40),
            const Text(
              "WOULD YOU RATHER",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2C4E6E), letterSpacing: 1.5),
            ),
            const SizedBox(height: 60),
            _buildOptionInput(_opt1Ctrl, "Type something..."),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text("OR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey)),
            ),
            _buildOptionInput(_opt2Ctrl, "Type something..."),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: _isLoading ? null : _launchGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C4E6E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("LAUNCH GAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionInput(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[300]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(24),
        ),
      ),
    );
  }
}

// --- PLAY SCREEN ---
class WouldYouRatherPlay extends StatefulWidget {
  final String gameId;
  const WouldYouRatherPlay({super.key, required this.gameId});
  @override
  State<WouldYouRatherPlay> createState() => _WouldYouRatherPlayState();
}

class _WouldYouRatherPlayState extends State<WouldYouRatherPlay> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _setupData;
  List<Map<String, dynamic>> _votes = [];
  String? _myVote;
  bool _isLoading = true;
  bool _isExpired = false;
  Timer? _countdownTimer;
  String _timeRemaining = "";
  StreamSubscription? _votesSubscription;

  @override
  void initState() {
    super.initState();
    _loadGame();
    _markAsSeen();
    _subscribeToVotes();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _votesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToVotes() {
    _votesSubscription = supabase
        .from('would_you_rather_actions')
        .stream(primaryKey: ['id'])
        .eq('game_id', widget.gameId)
        .listen((data) {
          _fetchVotesOnly();
        });
  }

  Future<void> _fetchVotesOnly() async {
    final votesRes = await supabase.from('would_you_rather_actions')
        .select('*, profiles:user_id(username)')
        .eq('game_id', widget.gameId)
        .eq('action_type', 'vote');
    if (mounted) {
      setState(() {
        _votes = List<Map<String, dynamic>>.from(votesRes);
      });
    }
  }

  Future<void> _markAsSeen() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('would_you_rather_participants')
          .update({'is_seen': true})
          .match({'game_id': widget.gameId, 'user_id': userId});
    } catch (e) {
      debugPrint("Error marking as seen: $e");
    }
  }

  Future<void> _loadGame() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final game = await supabase.from('would_you_rather_games').select().eq('id', widget.gameId).single();
      
      final setupAction = await supabase.from('would_you_rather_actions')
          .select()
          .eq('game_id', widget.gameId)
          .eq('action_type', 'setup')
          .maybeSingle();

      final voteAction = await supabase.from('would_you_rather_actions')
          .select()
          .eq('game_id', widget.gameId)
          .eq('user_id', userId)
          .eq('action_type', 'vote')
          .maybeSingle();

      if (game['ends_at'] != null) {
        final expiry = DateTime.parse(game['ends_at']);
        _isExpired = DateTime.now().isAfter(expiry);
        if (!_isExpired) _startCountdown(expiry);
      }

      await _fetchVotesOnly();

      if (mounted) {
        setState(() {
          _setupData = setupAction?['data'];
          _myVote = voteAction?['data']?['choice'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading game: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown(DateTime expiry) {
    _countdownTimer?.cancel();
    _updateTime(expiry);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime(expiry);
    });
  }

  void _updateTime(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now);
    if (diff.isNegative) {
      _countdownTimer?.cancel();
      _loadGame();
      return;
    }
    if (mounted) {
      setState(() {
        final h = diff.inHours;
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        _timeRemaining = "$h:$m:$s";
      });
    }
  }

  Future<void> _vote(String choice) async {
    if (_myVote != null || _isExpired) return;
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('would_you_rather_actions').insert({
        'game_id': widget.gameId,
        'user_id': userId,
        'action_type': 'vote',
        'data': {'choice': choice}
      });
      _loadGame();
    } catch (e) {
      debugPrint("Vote error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_setupData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("WAITING")),
        body: const Center(child: Text("Waiting for creator to setup...")),
      );
    }

    final showRes = _myVote != null || _isExpired;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("WOULD YOU RATHER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C4E6E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_isExpired && _timeRemaining.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text("Ends in: $_timeRemaining", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              ),
            Text(_setupData!['question'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _buildPlayOption('a', _setupData!['option_a'], showRes),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("OR", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2C4E6E))),
            ),
            _buildPlayOption('b', _setupData!['option_b'], showRes),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            const Text("CHOICES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            ..._votes.map((v) {
              final username = v['profiles']['username'] ?? 'User';
              final choice = v['data']['choice'] == 'a' ? _setupData!['option_a'] : _setupData!['option_b'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    "@$username rather $choice",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayOption(String key, String text, bool showRes) {
    final isSel = _myVote == key;
    return InkWell(
      onTap: showRes ? null : () => _vote(key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2C4E6E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSel ? const Color(0xFF2C4E6E) : Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
