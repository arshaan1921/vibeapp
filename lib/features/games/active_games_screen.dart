import 'package:flutter/material.dart';
import '../../services/rate_game_service.dart';
import '../../models/rate_game.dart';
import 'rate_me_brutally/game_detail_screen.dart';
import 'rate_me_brutally/create_game_screen.dart';
import '../../services/block_service.dart';

class ActiveGamesScreen extends StatefulWidget {
  const ActiveGamesScreen({super.key});

  @override
  State<ActiveGamesScreen> createState() => _ActiveGamesScreenState();
}

class _ActiveGamesScreenState extends State<ActiveGamesScreen> {
  final _service = RateGameService();
  late Future<List<RateGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _loadInitialGames();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  Future<List<RateGame>> _loadInitialGames() async {
    await blockService.refreshBlockedList();
    final games = await _service.getGames();
    return games.where((g) => !blockService.isBlocked(g.createdBy)).toList();
  }

  @override
  void dispose() {
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  void _onBlocksChanged() {
    if (mounted) {
      _refreshGames();
    }
  }

  void _refreshGames() {
    setState(() {
      _gamesFuture = _service.getGames().then((games) {
        return games.where((g) => !blockService.isBlocked(g.createdBy)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOUR GAMES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<RateGame>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final games = snapshot.data ?? [];
          
          return Column(
            children: [
              Expanded(
                child: games.isEmpty 
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _refreshGames();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final game = games[index];
                          return _GameListItem(
                            game: game,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: game.id)),
                              );
                              _refreshGames();
                            },
                          );
                        },
                      ),
                    ),
              ),
              _buildNewGameButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNewGameButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRateGameScreen()),
            );
            _refreshGames();
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('+ New Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No active games', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Start a new game below!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _GameListItem extends StatelessWidget {
  final RateGame game;
  final VoidCallback onTap;

  const _GameListItem({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = game.creator?.avatarUrl;
    final username = game.creator?.username;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundImage: (avatarUrl != null && avatarUrl != '')
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person) : null,
        ),
        title: Text(
          'Rate Me Brutally',
          style: TextStyle(fontWeight: game.isSeen ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text('By @${username ?? "unknown"}'),
        trailing: !game.isSeen 
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
