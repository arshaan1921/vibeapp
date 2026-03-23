import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/secret_crush.dart';
import '../../../services/secret_crush_service.dart';
import 'create_crush_game_screen.dart';
import 'crush_game_detail_screen.dart';

class ActiveCrushGamesScreen extends StatefulWidget {
  const ActiveCrushGamesScreen({super.key});

  @override
  State<ActiveCrushGamesScreen> createState() => _ActiveCrushGamesScreenState();
}

class _ActiveCrushGamesScreenState extends State<ActiveCrushGamesScreen> {
  final _service = SecretCrushService();
  late Future<List<SecretCrushGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _service.getGames();
  }

  void _refreshGames() {
    setState(() {
      _gamesFuture = _service.getGames();
    });
  }

  Future<void> _confirmDelete(SecretCrushGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this game?'),
        content: const Text('This will remove all data permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteGame(game.id);
        _refreshGames();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting game: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SECRET CRUSH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<SecretCrushGame>>(
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
                          final userId = Supabase.instance.client.auth.currentUser!.id;
                          final isCreator = game.createdBy == userId;

                          return _GameListItem(
                            game: game,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CrushGameDetailScreen(gameId: game.id)),
                              );
                              _refreshGames();
                            },
                            onDelete: isCreator ? () => _confirmDelete(game) : null,
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
              MaterialPageRoute(builder: (_) => const CreateCrushGameScreen()),
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
          Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No active games', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Find out who has a crush on you!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _GameListItem extends StatelessWidget {
  final SecretCrushGame game;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _GameListItem({
    required this.game, 
    required this.onTap,
    this.onDelete,
  });

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
          backgroundImage: avatarUrl != null && avatarUrl != ''
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person) : null,
        ),
        title: const Text('Secret Crush', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('By @${username ?? "unknown"}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (game.hasSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
