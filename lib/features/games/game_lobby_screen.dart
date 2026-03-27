import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../services/game_service.dart';
import 'friend_selection_screen.dart';
import 'game_play_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/block_service.dart';

class GameLobbyScreen extends StatefulWidget {
  final String gameType;
  final String title;

  const GameLobbyScreen({super.key, required this.gameType, required this.title});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final _gameService = GameService();
  late Future<List<Game>> _gamesFuture;
  List<Map<String, dynamic>> _savedProfiles = [];
  bool _isLoadingSaved = true;

  @override
  void initState() {
    super.initState();
    _refreshGames();
    _fetchSavedProfiles();
  }

  Future<void> _fetchSavedProfiles() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final savedRows = await supabase
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', user.id);

      final List<String> savedUserIds = (savedRows as List)
          .map((item) => item['saved_user_id'] as String)
          .toList();

      if (savedUserIds.isEmpty) {
        if (mounted) setState(() => _isLoadingSaved = false);
        return;
      }

      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, name, avatar_url')
          .inFilter('id', savedUserIds);

      if (mounted) {
        setState(() {
          _savedProfiles = List<Map<String, dynamic>>.from(profilesResponse)
              .where((p) => !blockService.isBlocked(p['id']))
              .toList();
          _isLoadingSaved = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching saved profiles in lobby: $e");
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  void _refreshGames() {
    setState(() {
      _gamesFuture = _gameService.getActiveGames(widget.gameType);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Game>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final games = snapshot.data ?? [];

          if (games.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No active games. Start one with friends!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshGames(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text("Game with ${game.participants.length} players"),
                    subtitle: Text("Started on ${game.createdAt.toLocal().toString().split('.')[0]}"),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GamePlayScreen(game: game),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingSaved ? null : _startNewGame,
        label: _isLoadingSaved 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text("New Game"),
        icon: _isLoadingSaved ? null : const Icon(Icons.add),
      ),
    );
  }

  void _startNewGame() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendSelectionScreen(
          gameType: widget.gameType,
          savedUsers: _savedProfiles,
        ),
      ),
    );
    if (result == true) {
      _refreshGames();
      _fetchSavedProfiles(); // Refresh saved users too in case of blocks etc
    }
  }
}
