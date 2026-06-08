import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'most_likely_game.dart';
import 'truth_lie_game.dart';
import 'meme_mania_lobby.dart';
import 'create_meme_screen.dart';
import 'meme_game_screen.dart';
import '../../services/game_service.dart';

import 'active_game_dashboard.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeGames = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _fetchActiveGames();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchActiveGames() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    List<Map<String, dynamic>> allActive = [];
    int mlCount = 0;
    int tlCount = 0;
    int memeCount = 0;

    try {
      // 1. Most Likely To
      final mlRes = await supabase
          .from('most_likely_participants')
          .select('game_id, is_seen')
          .eq('user_id', userId)
          .eq('is_seen', false);
      
      mlCount = (mlRes as List).length;
      for (var item in mlRes) {
        allActive.add({
          'type': 'ml',
          'id': item['game_id'],
          'title': 'Most Likely To',
          'status': 'Vote waiting',
          'icon': Icons.people_alt_rounded,
          'color': Colors.pinkAccent,
        });
      }

      // 2. Truth Lie
      final tlRes = await supabase
          .from('truth_lie_participants')
          .select('game_id, is_seen')
          .eq('user_id', userId)
          .eq('is_seen', false);
      
      tlCount = (tlRes as List).length;
      for (var item in tlRes) {
        allActive.add({
          'type': 'tl',
          'id': item['game_id'],
          'title': 'Truth or Lie',
          'status': 'Reveal lie!',
          'icon': Icons.fact_check_rounded,
          'color': Colors.blueAccent,
        });
      }

      // 3. Meme Mania
      final memeRes = await supabase
          .from('meme_participants')
          .select('meme_id, is_seen')
          .eq('user_id', userId)
          .eq('is_seen', false);

      memeCount = (memeRes as List).length;
      for (var item in memeRes) {
        allActive.add({
          'type': 'meme',
          'id': item['meme_id'],
          'title': 'Meme Mania',
          'status': 'New activity',
          'icon': Icons.emoji_emotions_rounded,
          'color': Colors.orangeAccent,
        });
      }

      if (mounted) {
        setState(() {
          _activeGames = allActive;
        });
      }
    } catch (e) {
      debugPrint("Error fetching active games: $e");
    }
  }

  void _openGame(Map<String, dynamic> game) {
    Widget target;
    if (game['type'] == 'ml') {
      target = MostLikelyPlay(gameId: game['id']);
    } else if (game['type'] == 'tl') {
      target = TruthLiePlay(gameId: game['id']);
    } else {
      target = MemeGameScreen(gameId: game['id']);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => target)).then((_) => _loadAllData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF16181D) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // REDESIGNED TOP HERO SECTION
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xFF1A1A2E), const Color(0xFF0B0B0F)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFF8F9FC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GAMES",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            "Play with friends 🎮",
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Removed Notification Icon
                    ],
                  ),
                  const SizedBox(height: 32),
                  // HERO BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA855F7).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🎮 Play With Friends",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Active games and battles will appear here.",
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ACTIVE GAMES SECTION
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              "Active Games",
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActiveGameDashboard()),
              ).then((_) => _loadAllData()),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading 
              ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
              : _activeGames.isEmpty
                ? _buildEmptyState(isDark)
                : SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _activeGames.length,
                      itemBuilder: (context, index) {
                        return _ActiveGameCard(
                          game: _activeGames[index],
                          onTap: () => _openGame(_activeGames[index]),
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // CREATE NEW GAME SECTION
          SliverToBoxAdapter(
            child: _buildSectionHeader("Play a New Game"),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _NewGameCard(
                  title: "MOST LIKELY TO",
                  description: "Vote on fun scenarios with friends",
                  icon: Icons.people_alt_rounded,
                  gradient: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MostLikelyLobby()),
                  ).then((_) => _loadAllData()),
                  isDark: isDark,
                  cardColor: cardColor,
                ),
                _NewGameCard(
                  title: "TWO TRUTHS & ONE LIE",
                  description: "Can your friends spot the lie?",
                  icon: Icons.fact_check_rounded,
                  gradient: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TruthLieLobby()),
                  ).then((_) => _loadAllData()),
                  isDark: isDark,
                  cardColor: cardColor,
                ),
                _NewGameCard(
                  title: "MEMES MANIA",
                  description: "Upload memes & battle for the funniest comments",
                  icon: Icons.emoji_emotions_rounded,
                  gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateMemeScreen()),
                  ).then((_) => _loadAllData()),
                  isDark: isDark,
                  cardColor: cardColor,
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                "See all",
                style: TextStyle(
                  color: Color(0xFFEC4899),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.videogame_asset_outlined,
            size: 56,
            color: isDark ? Colors.white10 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            "No active games",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Start a game with your friends and have some fun.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveGameCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;
  final bool isDark;

  const _ActiveGameCard({
    required this.game,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_ActiveGameCard> createState() => _ActiveGameCardState();
}

class _ActiveGameCardState extends State<_ActiveGameCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.game['color'];
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isHovered ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [accentColor.withOpacity(0.15), accentColor.withOpacity(0.05)]
                  : [accentColor.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: accentColor.withOpacity(widget.isDark ? 0.3 : 0.2),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.game['icon'], color: accentColor, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      widget.game['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.game['status'],
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewGameCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isDark;
  final Color cardColor;

  const _NewGameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.isDark,
    required this.cardColor,
  });

  @override
  State<_NewGameCard> createState() => _NewGameCardState();
}

class _NewGameCardState extends State<_NewGameCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Hero(
            tag: 'game_card_${widget.title}',
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
