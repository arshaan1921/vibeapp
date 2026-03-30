import 'package:flutter/material.dart';
import '../../models/meme_mania.dart';
import '../../services/meme_mania_service.dart';
import 'create_meme_screen.dart';
import 'meme_game_screen.dart';

class MemeManiaLobby extends StatefulWidget {
  const MemeManiaLobby({super.key});

  @override
  State<MemeManiaLobby> createState() => _MemeManiaLobbyState();
}

class _MemeManiaLobbyState extends State<MemeManiaLobby> {
  final _service = MemeManiaService();
  late Future<List<MemeGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _refreshGames();
  }

  void _refreshGames() {
    setState(() {
      _gamesFuture = _service.getActiveGames();
    });
  }

  Future<void> _deleteMeme(String memeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meme'),
        content: const Text('Are you sure you want to delete this meme?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteMemeGame(memeId);
        _refreshGames();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meme deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting meme: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MEMES MANIA', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGames,
          ),
        ],
      ),
      body: FutureBuilder<List<MemeGame>>(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_emotions_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No active memes. Start one!', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 100), // Space to not overlap with FAB
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final isCreator = game.creatorId == _service.currentUserId;

              return _MemeCard(
                game: game,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemeGameScreen(gameId: game.id)),
                ).then((_) => _refreshGames()),
                onDelete: isCreator ? () => _deleteMeme(game.id) : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context),
        label: const Text('New Meme'),
        icon: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateMemeScreen()),
    ).then((_) => _refreshGames());
  }
}

class _MemeCard extends StatelessWidget {
  final MemeGame game;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _MemeCard({required this.game, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final timeLeft = game.expiresAt.difference(DateTime.now());
    final hoursLeft = timeLeft.inHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    game.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error)),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: onDelete,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (game.caption != null && game.caption!.isNotEmpty) ...[
                    Text(
                      game.caption!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'By ${game.creator?.username ?? "Someone"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$hoursLeft hours left',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
