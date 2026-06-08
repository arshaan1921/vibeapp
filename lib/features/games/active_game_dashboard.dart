import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'most_likely_game.dart';
import 'truth_lie_game.dart';
import 'meme_game_screen.dart';
import '../../utils/image_utils.dart';

class ActiveGameDashboard extends StatefulWidget {
  const ActiveGameDashboard({super.key});

  @override
  State<ActiveGameDashboard> createState() => _ActiveGameDashboardState();
}

class _ActiveGameDashboardState extends State<ActiveGameDashboard> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _waitingForYou = [];
  List<Map<String, dynamic>> _waitingForFriends = [];
  List<Map<String, dynamic>> _completed = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    List<Map<String, dynamic>> forYou = [];
    List<Map<String, dynamic>> forFriends = [];
    List<Map<String, dynamic>> completed = [];

    try {
      // FETCH MOST LIKELY
      final mlRes = await supabase
          .from('most_likely_games')
          .select('*, most_likely_participants(user_id, is_seen)')
          .or('creator_id.eq.$userId, most_likely_participants.user_id.eq.$userId');
      
      for (var g in mlRes) {
        final creatorId = g['creator_id'];
        final creator = await supabase.from('profiles').select().eq('id', creatorId).single();
        g['creator'] = creator;

        final isCreator = g['creator_id'] == userId;
        final participant = (g['most_likely_participants'] as List).firstWhere((p) => p['user_id'] == userId, orElse: () => null);
        final isUnseen = participant != null && participant['is_seen'] == false;
        
        final createdAt = DateTime.parse(g['created_at']);
        final isExpired = DateTime.now().difference(createdAt).inHours >= 24;

        final item = {
          'type': 'ml',
          'id': g['id'],
          'title': 'Most Likely To',
          'creator': g['creator'],
          'color': Colors.pinkAccent,
          'icon': Icons.people_alt_rounded,
        };

        if (isExpired) {
          completed.add(item);
        } else if (!isCreator && isUnseen) {
          forYou.add(item);
        } else if (isCreator) {
          forFriends.add(item);
        }
      }

      // FETCH TRUTH LIE
      final tlRes = await supabase
          .from('truth_lie_games')
          .select('*, truth_lie_participants(user_id, is_seen)')
          .or('creator_id.eq.$userId, truth_lie_participants.user_id.eq.$userId');

      for (var g in tlRes) {
        final creatorId = g['creator_id'];
        final creator = await supabase.from('profiles').select().eq('id', creatorId).single();
        g['creator'] = creator;

        final isCreator = g['creator_id'] == userId;
        final participant = (g['truth_lie_participants'] as List).firstWhere((p) => p['user_id'] == userId, orElse: () => null);
        final isUnseen = participant != null && participant['is_seen'] == false;
        
        final createdAt = DateTime.parse(g['created_at']);
        final isExpired = DateTime.now().difference(createdAt).inHours >= 24;

        final item = {
          'type': 'tl',
          'id': g['id'],
          'title': 'Truth or Lie',
          'creator': g['creator'],
          'color': Colors.blueAccent,
          'icon': Icons.fact_check_rounded,
        };

        if (isExpired) {
          completed.add(item);
        } else if (!isCreator && isUnseen) {
          forYou.add(item);
        } else if (isCreator) {
          forFriends.add(item);
        }
      }

      // FETCH MEME MANIA
      final memeRes = await supabase
          .from('meme_games')
          .select('*, meme_participants(user_id, is_seen)')
          .or('creator_id.eq.$userId, meme_participants.user_id.eq.$userId');

      for (var g in memeRes) {
        final creatorId = g['creator_id'];
        final creator = await supabase.from('profiles').select().eq('id', creatorId).single();
        g['creator'] = creator;

        final isCreator = g['creator_id'] == userId;
        final participant = (g['meme_participants'] as List).firstWhere((p) => p['user_id'] == userId, orElse: () => null);
        final isUnseen = participant != null && participant['is_seen'] == false;
        
        final expiresAt = DateTime.parse(g['expires_at']);
        final isExpired = DateTime.now().isAfter(expiresAt);

        final item = {
          'type': 'meme',
          'id': g['id'],
          'title': 'Meme Mania',
          'creator': g['creator'],
          'color': Colors.orangeAccent,
          'icon': Icons.emoji_emotions_rounded,
        };

        if (isExpired) {
          completed.add(item);
        } else if (!isCreator && isUnseen) {
          forYou.add(item);
        } else if (isCreator) {
          forFriends.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _waitingForYou = forYou;
          _waitingForFriends = forFriends;
          _completed = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
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

    Navigator.push(context, MaterialPageRoute(builder: (_) => target)).then((_) => _loadDashboard());
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
        title: const Text("GAME DASHBOARD", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_waitingForYou.isNotEmpty) ...[
                    _buildSectionHeader("Waiting For You"),
                    ..._waitingForYou.map((g) => _DashboardCard(game: g, isForYou: true, onTap: () => _openGame(g))),
                    const SizedBox(height: 24),
                  ],
                  if (_waitingForFriends.isNotEmpty) ...[
                    _buildSectionHeader("Waiting For Friends ⏳"),
                    ..._waitingForFriends.map((g) => _DashboardCard(game: g, isForYou: false, onTap: () => _openGame(g))),
                    const SizedBox(height: 24),
                  ],
                  if (_completed.isNotEmpty) ...[
                    _buildSectionHeader("Recently Completed ✅"),
                    ..._completed.map((g) => _DashboardCard(game: g, isForYou: false, isCompleted: true, onTap: () => _openGame(g))),
                  ],
                  if (_waitingForYou.isEmpty && _waitingForFriends.isEmpty && _completed.isEmpty)
                    _buildEmptyState(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.dashboard_customize_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
        const SizedBox(height: 24),
        const Text("No Game Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text("Your active and finished games will appear here.", style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final bool isForYou;
  final bool isCompleted;
  final VoidCallback onTap;

  const _DashboardCard({required this.game, required this.isForYou, this.isCompleted = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = game['color'] as Color;
    final creator = game['creator'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isForYou ? color.withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(game['icon'], color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game['title'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted ? "See Final Results" : "By @${creator['username']}",
                      style: TextStyle(color: isCompleted ? Colors.green : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (isForYou)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: const Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
