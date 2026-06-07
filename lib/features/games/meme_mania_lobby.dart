import 'package:flutter/material.dart';
import '../../models/meme_mania.dart';
import '../../services/meme_mania_service.dart';
import 'create_meme_screen.dart';
import 'meme_game_screen.dart';
import '../../utils/image_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('MEMES MANIA', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refreshGames),
        ],
      ),
      body: FutureBuilder<List<MemeGame>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = snapshot.data ?? [];
          if (games.isEmpty) return _buildEmptyState(isDark);

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: games.length,
            itemBuilder: (context, index) {
              return _MemeFeedCard(
                game: games[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemeGameScreen(gameId: games[index].id)),
                ).then((_) => _refreshGames()),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMemeScreen())).then((_) => _refreshGames()),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("NEW MEME", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_retouching_natural_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 24),
          const Text("No Memes Yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Be the first to start a battle!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MemeFeedCard extends StatelessWidget {
  final MemeGame game;
  final VoidCallback onTap;

  const _MemeFeedCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeLeft = game.expiresAt.difference(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: ImageUtils.getImageProvider(game.creator?.avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.creator?.username ?? "Someone", style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text("${timeLeft.inHours}h remaining", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                ],
              ),
            ),
            // MEME IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                width: double.infinity,
                child: Image.network(game.imageUrl, fit: BoxFit.cover),
              ),
            ),
            // CAPTION & STATS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (game.caption != null && game.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(game.caption!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  Row(
                    children: [
                      _buildStatChip(Icons.chat_bubble_outline_rounded, "View Battle", const Color(0xFFF59E0B)),
                      const Spacer(),
                      const Icon(Icons.trending_up_rounded, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 4),
                      const Text("Trending", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
