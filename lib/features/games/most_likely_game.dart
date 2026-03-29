import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/block_service.dart';

// --- MAIN ENTRY (LOBBY) ---
class MostLikelyLobby extends StatefulWidget {
  const MostLikelyLobby({super.key});
  @override
  State<MostLikelyLobby> createState() => _MostLikelyLobbyState();
}

class _MostLikelyLobbyState extends State<MostLikelyLobby> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activeGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('most_likely_games')
          .select('*, most_likely_participants!inner(user_id, is_seen)')
          .eq('most_likely_participants.user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeGames = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching most likely games: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGame(String gameId) async {
    try {
      await supabase.from('most_likely_games').delete().eq('id', gameId);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("MOST LIKELY TO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.primaryColor,
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
                          Icon(Icons.videogame_asset_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text("No active games. Start one with friends!", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activeGames.length,
                      itemBuilder: (context, index) {
                        final game = _activeGames[index];
                        final createdAt = DateTime.parse(game['created_at']);
                        final isExpired = DateTime.now().difference(createdAt).inHours >= 24;
                        final isCreator = game['creator_id'] == currentUserId;
                        
                        final bool isUnseen = game['most_likely_participants'] != null && 
                                              (game['most_likely_participants'] as List).any((p) => p['user_id'] == currentUserId && p['is_seen'] == false);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: isUnseen ? 4 : 1,
                          color: theme.cardColor,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Row(
                              children: [
                                if (isUnseen) 
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
                                  ),
                                Expanded(
                                  child: Text(
                                    "Game ${index + 1}", 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.titleMedium?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              isExpired ? "Game ended - See results" : "Started on ${game['created_at'].toString().split('T')[0]}",
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            ),
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
                                Icon(isExpired ? Icons.bar_chart : Icons.chevron_right, color: isDark ? Colors.white24 : Colors.black26),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => MostLikelyPlay(gameId: game['id']))
                            ).then((_) => _fetchGames()),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MostLikelyFriendSelect())).then((_) => _fetchGames()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.primaryColor,
            ),
            child: const Text("NEW GAME", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// --- FRIEND SELECTION ---
class MostLikelyFriendSelect extends StatefulWidget {
  const MostLikelyFriendSelect({super.key});
  @override
  State<MostLikelyFriendSelect> createState() => _MostLikelyFriendSelectState();
}

class _MostLikelyFriendSelectState extends State<MostLikelyFriendSelect> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("SELECT FRIENDS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
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
                      Icon(Icons.person_search_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No saved profiles found.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _friends.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                  itemBuilder: (context, index) {
                    final f = _friends[index];
                    final isSelected = _selectedIds.contains(f.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (f.avatarUrl != null && f.avatarUrl!.isNotEmpty) ? NetworkImage(f.avatarUrl!) : null,
                        child: (f.avatarUrl == null || f.avatarUrl!.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        f.username.isNotEmpty ? f.username : (f.name ?? "User"), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? theme.primaryColor : (isDark ? Colors.white24 : Colors.grey),
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => MostLikelySetup(selectedFriends: _friends.where((f) => _selectedIds.contains(f.id)).toList())));
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.primaryColor,
              disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
            ),
            child: Text("CONTINUE (${_selectedIds.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// --- SETUP SCREEN ---
class MostLikelySetup extends StatefulWidget {
  final List<AppUser> selectedFriends;
  const MostLikelySetup({super.key, required this.selectedFriends});
  @override
  State<MostLikelySetup> createState() => _MostLikelySetupState();
}

class _MostLikelySetupState extends State<MostLikelySetup> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (var ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length < 4) {
      setState(() {
        _optionCtrls.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionCtrls.length > 2) {
      setState(() {
        _optionCtrls[index].dispose();
        _optionCtrls.removeAt(index);
      });
    }
  }

  Future<void> _launchGame() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a question")));
      return;
    }
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter at least 2 options")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      // 1. Create the game entry
      final game = await supabase.from('most_likely_games').insert({'creator_id': userId}).select().single();
      final gameId = game['id'];

      // 2. Add participants
      final participantIds = {...widget.selectedFriends.map((f) => f.id), userId};
      final participants = participantIds.map((id) => {
        'game_id': gameId, 
        'user_id': id,
        'is_seen': id == userId, // Creator has seen it
      }).toList();
      await supabase.from('most_likely_participants').insert(participants);

      // 3. Add the setup action (question + options)
      await supabase.from('most_likely_actions').insert({
        'game_id': gameId,
        'user_id': userId,
        'action_type': 'setup',
        'data': {
          'question': question,
          'options': options,
        }
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MostLikelyPlay(gameId: gameId)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint("Error launching game: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error launching game: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("SETUP GAME"),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("What is the question?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _questionCtrl,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Who is most likely to...",
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Options (2-4)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_optionCtrls.length < 4)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text("Add"),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ..._optionCtrls.asMap().entries.map((entry) {
                final idx = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: ctrl,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: "Option ${idx + 1}",
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: _optionCtrls.length > 2
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () => _removeOption(idx),
                            )
                          : null,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text("Friends who can see this: ${widget.selectedFriends.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0, top: 8.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _launchGame,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("LAUNCH GAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

// --- PLAY SCREEN ---
class MostLikelyPlay extends StatefulWidget {
  final String gameId;
  const MostLikelyPlay({super.key, required this.gameId});
  @override
  State<MostLikelyPlay> createState() => _MostLikelyPlayState();
}

class _MostLikelyPlayState extends State<MostLikelyPlay> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _game;
  Map<String, dynamic>? _creatorProfile;
  List<String> _options = [];
  bool _isLoading = true;
  String? _votedForOption;
  String? _question;
  bool _isExpired = false;
  Map<String, int> _voteCounts = {};
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
          .from('most_likely_participants')
          .update({'is_seen': true})
          .match({'game_id': widget.gameId, 'user_id': userId});
    } catch (e) {
      debugPrint("Error marking game as seen: $e");
    }
  }

  Future<void> _loadGame() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final game = await supabase.from('most_likely_games').select().eq('id', widget.gameId).single();
      
      final createdAt = DateTime.parse(game['created_at']);
      final now = DateTime.now();
      final isExpired = now.difference(createdAt).inHours >= 24;

      if (!isExpired) {
        _startCountdown(createdAt);
      }

      final creatorProfile = await supabase.from('profiles').select().eq('id', game['creator_id']).single();

      final setupAction = await supabase.from('most_likely_actions').select().eq('game_id', widget.gameId).eq('action_type', 'setup').maybeSingle();
      
      final List<String> options = setupAction != null ? List<String>.from(setupAction['data']['options']) : [];
      final String? question = setupAction != null ? setupAction['data']['question'] : null;
      
      final vote = await supabase.from('most_likely_actions').select().eq('game_id', widget.gameId).eq('user_id', userId).eq('action_type', 'vote').maybeSingle();

      if (isExpired) {
        final votesResponse = await supabase.from('most_likely_actions').select('data').eq('game_id', widget.gameId).eq('action_type', 'vote');
        final Map<String, int> counts = {};
        for (var v in (votesResponse as List)) {
          final opt = v['data']['option'] as String;
          counts[opt] = (counts[opt] ?? 0) + 1;
        }
        _voteCounts = counts;
        _totalVotes = votesResponse.length;
      }

      if (mounted) {
        setState(() {
          _game = game;
          _isExpired = isExpired;
          _creatorProfile = creatorProfile;
          _question = question;
          _options = options;
          _votedForOption = vote?['data']?['option'];
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

  Future<void> _vote(String optionText) async {
    if (_votedForOption != null || _isExpired) return;
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('most_likely_actions').insert({
        'game_id': widget.gameId,
        'user_id': userId,
        'action_type': 'vote',
        'data': {'option': optionText},
      });
      setState(() => _votedForOption = optionText);
    } catch (e) {
      debugPrint("Error voting: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vote failed: $e")));
    }
  }

  Future<void> _deleteThisGame() async {
    try {
      await supabase.from('most_likely_games').delete().eq('id', widget.gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game deleted")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error deleting game: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete game: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_game == null) return const Scaffold(body: Center(child: Text("Game not found")));

    final currentUserId = supabase.auth.currentUser?.id;
    final isCreator = _game!['creator_id'] == currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String? winner;
    if (_isExpired && _voteCounts.isNotEmpty) {
      int maxVotes = -1;
      _voteCounts.forEach((opt, count) {
        if (count > maxVotes) {
          maxVotes = count;
          winner = opt;
        }
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isExpired ? "RESULTS" : "VOTE"), 
        backgroundColor: theme.primaryColor, 
        foregroundColor: Colors.white,
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Delete Game?"),
                    content: const Text("This action will remove the game for everyone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteThisGame();
                        },
                        child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_creatorProfile != null) ...[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      backgroundImage: (_creatorProfile!['avatar_url'] != null && _creatorProfile!['avatar_url'] != '')
                          ? NetworkImage(_creatorProfile!['avatar_url'])
                          : null,
                      child: (_creatorProfile!['avatar_url'] == null || _creatorProfile!['avatar_url'] == '')
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "@${_creatorProfile!['username'] ?? 'User'}",
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _question ?? "Most Likely To...", 
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ), 
                    textAlign: TextAlign.center,
                  ),
                  
                  if (!_isExpired) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "Ends in: $_timeRemaining",
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  if (_isExpired) ...[
                     Text("The winner is:", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 14)),
                     const SizedBox(height: 4),
                     Text(winner ?? "No votes yet", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                     const SizedBox(height: 32),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: _options.length,
                      itemBuilder: (context, i) {
                        final opt = _options[i];
                        final isSelected = _votedForOption == opt;
                        final voteCount = _voteCounts[opt] ?? 0;
                        final percentage = _totalVotes > 0 ? (voteCount / _totalVotes) : 0.0;
                        final isWinner = winner == opt;

                        return Card(
                          color: isWinner ? Colors.blue.withOpacity(0.1) : (isSelected ? Colors.blue.withOpacity(0.05) : theme.cardColor),
                          shape: isWinner ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.blue, width: 2)) : null,
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  opt, 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: isWinner ? Colors.blue : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                trailing: _isExpired 
                                  ? Text("$voteCount votes", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))
                                  : (isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null),
                                onTap: () => _vote(opt),
                              ),
                              if (_isExpired)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                      color: isWinner ? Colors.blue : Colors.blue.withOpacity(0.3),
                                      minHeight: 8,
                                    ),
                                  ),
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isExpired) 
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Total Votes: $_totalVotes", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _votedForOption != null && !_isExpired
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  "Thanks for voting!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            )
          : null,
    );
  }
}
