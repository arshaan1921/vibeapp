import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';

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

    final response = await supabase
        .from('would_you_rather_games')
        .select('*, would_you_rather_participants!inner(user_id)')
        .eq('would_you_rather_participants.user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _activeGames = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("WOULD YOU RATHER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeGames.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.compare_arrows_rounded, size: 64, color: Colors.grey[300]),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text("Game ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Started on ${game['created_at'].toString().split('T')[0]}"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WouldYouRatherPlay(gameId: game['id']))),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WouldYouRatherFriendSelect())),
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

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('saved_profiles')
        .select('*, profiles:saved_user_id(*)')
        .eq('user_id', user.id);

    if (mounted) {
      setState(() {
        _friends = (response as List).map((i) => AppUser.fromJson(i['profiles'])).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _startGame() async {
    if (_selectedIds.isEmpty) return;
    final userId = supabase.auth.currentUser!.id;
    final game = await supabase.from('would_you_rather_games').insert({'creator_id': userId}).select().single();
    final gameId = game['id'];
    final participants = [..._selectedIds, userId].map((id) => {'game_id': gameId, 'user_id': id}).toList();
    await supabase.from('would_you_rather_participants').insert(participants);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WouldYouRatherPlay(gameId: gameId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SELECT FRIENDS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _friends.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = _friends[index];
                final isSelected = _selectedIds.contains(f.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: f.avatarUrl != null ? NetworkImage(f.avatarUrl!) : null,
                    child: f.avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(f.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  onTap: () => setState(() => isSelected ? _selectedIds.remove(f.id) : _selectedIds.add(f.id)),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : _startGame,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("NEW GAME (${_selectedIds.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

// --- SETUP & PLAY ---
class WouldYouRatherPlay extends StatefulWidget {
  final String gameId;
  const WouldYouRatherPlay({super.key, required this.gameId});
  @override
  State<WouldYouRatherPlay> createState() => _WouldYouRatherPlayState();
}

class _WouldYouRatherPlayState extends State<WouldYouRatherPlay> {
  final supabase = Supabase.instance.client;
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optCtrls = [
    TextEditingController(), // Option A
    TextEditingController(), // Option B
  ];
  bool _isCreator = false;
  bool _hasSetup = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (var c in _optCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final userId = supabase.auth.currentUser!.id;
    final game = await supabase.from('would_you_rather_games').select().eq('id', widget.gameId).single();
    final actions = await supabase.from('would_you_rather_actions').select().eq('game_id', widget.gameId).eq('action_type', 'setup').maybeSingle();
    
    if (mounted) {
      setState(() {
        _isCreator = game['creator_id'] == userId;
        _hasSetup = actions != null;
        _isLoading = false;
      });
    }
  }

  Future<void> _done() async {
    final opts = [_optCtrls[0].text.trim(), _optCtrls[1].text.trim()];
    
    if (_questionCtrl.text.isEmpty || opts.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter the question and both options")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.from('would_you_rather_games').update({
        'ends_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String()
      }).eq('id', widget.gameId);

      await supabase.from('would_you_rather_actions').insert({
        'game_id': widget.gameId,
        'user_id': supabase.auth.currentUser!.id,
        'action_type': 'setup',
        'data': {
          'question': _questionCtrl.text,
          'option_a': opts[0],
          'option_b': opts[1],
        }
      });
      _checkStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (!_hasSetup && _isCreator) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: const Text("WOULD YOU RATHER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF2C4E6E),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text("1. Enter your question", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: TextField(
                controller: _questionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: "Would you rather...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text("2. Options", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _buildOptionInput(_optCtrls[0], "Option A"),
            const SizedBox(height: 12),
            const Center(child: Text("OR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 12),
            _buildOptionInput(_optCtrls[1], "Option B"),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _done,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C4E6E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("GAME")), 
      body: Center(
        child: Text(_hasSetup ? "Game is live / Make your choice!" : "Waiting for the creator to set up the game...")
      )
    );
  }

  Widget _buildOptionInput(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
