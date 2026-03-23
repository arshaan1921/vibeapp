import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/rate_game.dart';
import '../../../services/rate_game_service.dart';

class GameDetailScreen extends StatefulWidget {
  final String gameId;
  const GameDetailScreen({super.key, required this.gameId});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final _service = RateGameService();
  bool _hasVoted = false;
  Map<String, dynamic>? _gameData;
  bool _isLoading = true;
  List<RateVote> _votes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchVotes();
    _setupRealtime();
  }

  void _setupRealtime() {
    _service.streamVotesRaw(widget.gameId).listen((_) {
      _fetchVotes();
    });
  }

  Future<void> _fetchVotes() async {
    try {
      // ignore: avoid_print
      print("Current gameId: ${widget.gameId}");
      final votes = await _service.getVotesWithProfiles(widget.gameId);
      if (mounted) {
        setState(() {
          _votes = votes;
        });
        // ignore: avoid_print
        print("Votes fetched: ${_votes.length}");
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching votes: $e");
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('rate_game_participants')
          .select('has_voted, rate_games(*, profiles(*))')
          .match({'game_id': widget.gameId, 'user_id': userId})
          .single();

      setState(() {
        _hasVoted = response['has_voted'];
        _gameData = response['rate_games'];
        _isLoading = false;
      });

      // Mark as seen
      await _service.markAsSeen(widget.gameId);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(String rating) async {
    try {
      await _service.vote(widget.gameId, rating);
      setState(() => _hasVoted = true);
      _fetchVotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_gameData == null) return const Scaffold(body: Center(child: Text('Game not found')));

    final creator = _gameData!['profiles'];

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Me Brutally')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildCreatorHeader(creator)),
            const SizedBox(height: 30),
            if (!_hasVoted && _gameData!['created_by'] != Supabase.instance.client.auth.currentUser!.id)
              _buildVotingSection()
            else if (_hasVoted)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('✅ Your vote has been recorded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 30),
            const Text('Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildResultsSummary(_votes),
            const SizedBox(height: 30),
            const Text('Individual Votes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildVotesList(_votes),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorHeader(Map<String, dynamic> creator) {
    final avatarUrl = creator['avatar_url'];
    final username = creator['username'];

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: avatarUrl != null && avatarUrl != ''
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl == '' ? const Icon(Icons.person, size: 50) : null,
        ),
        const SizedBox(height: 16),
        Text(
          'Rate @${username ?? "Unknown"}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Be brutally honest! 🔥🤡💀',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildVotingSection() {
    return Column(
      children: [
        const Center(child: Text('Choose a rating:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _voteButton('🔥', 'Attractive', 'attractive', Colors.orange),
            _voteButton('🤡', 'Mid', 'mid', Colors.blue),
            _voteButton('💀', 'Roast', 'roast', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _voteButton(String emoji, String label, String backendValue, Color color) {
    return Column(
      children: [
        InkWell(
          onTap: () => _vote(backendValue),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildResultsSummary(List<RateVote> votes) {
    if (votes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No votes yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final totalVotes = votes.length;
    final counts = {'attractive': 0, 'mid': 0, 'roast': 0};
    for (var v in votes) {
      if (counts.containsKey(v.rating)) counts[v.rating] = counts[v.rating]! + 1;
    }

    return Column(
      children: [
        _ResultBar(
          label: 'Attractive',
          emoji: '🔥',
          percent: counts['attractive']! / totalVotes,
          color: Colors.orange,
        ),
        _ResultBar(
          label: 'Mid',
          emoji: '🤡',
          percent: counts['mid']! / totalVotes,
          color: Colors.blue,
        ),
        _ResultBar(
          label: 'Roast',
          emoji: '💀',
          percent: counts['roast']! / totalVotes,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Total Votes: $totalVotes',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildVotesList(List<RateVote> votes) {
    if (votes.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: votes.map((v) {
        final avatarUrl = v.voter?.avatarUrl;
        final username = v.voter?.username;
        final displayRating = v.rating[0].toUpperCase() + v.rating.substring(1);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null && avatarUrl != ''
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl == '' ? const Icon(Icons.person) : null,
          ),
          title: Text(username ?? 'Unknown'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getColor(v.rating).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getColor(v.rating)),
            ),
            child: Text(displayRating, style: TextStyle(color: _getColor(v.rating), fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Color _getColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'attractive': return Colors.orange;
      case 'mid': return Colors.blue;
      case 'roast': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _ResultBar extends StatelessWidget {
  final String label;
  final String emoji;
  final double percent;
  final Color color;

  const _ResultBar({
    required this.label,
    required this.emoji,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$emoji $label', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${(percent * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percent),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
