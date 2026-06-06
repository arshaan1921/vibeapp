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
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _refreshGames();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final friendsRes = await supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

      final List<String> friendIds = (friendsRes as List)
          .map((item) => item['user1_id'] == user.id ? item['user2_id'].toString() : item['user1_id'].toString())
          .toList();

      if (friendIds.isEmpty) {
        if (mounted) setState(() => _isLoadingFriends = false);
        return;
      }

      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, name, avatar_url')
          .inFilter('id', friendIds);

      if (mounted) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(profilesResponse)
              .where((p) => !blockService.isBlocked(p['id']))
              .toList();
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friends in lobby: $e");
      if (mounted) setState(() => _isLoadingFriends = false);
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
        onPressed: _isLoadingFriends ? null : _startNewGame,
        label: _isLoadingFriends 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text("New Game"),
        icon: _isLoadingFriends ? null : const Icon(Icons.add),
      ),
    );
  }

  void _startNewGame() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendSelectionScreen(
          gameType: widget.gameType,
          savedUsers: _friends,
        ),
      ),
    );
    if (result == true) {
      _refreshGames();
      _fetchFriends(); // Refresh friends list too
    }
  }
}
