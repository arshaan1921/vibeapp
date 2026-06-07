import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/notification_service.dart';
import '../../services/block_service.dart';
import '../../utils/image_utils.dart';
import 'friend_selection_screen.dart';

// ==================================================
// 1. TRUTH LIE LOBBY
// ==================================================
class TruthLieLobby extends StatefulWidget {
  const TruthLieLobby({super.key});
  @override
  State<TruthLieLobby> createState() => _TruthLieLobbyState();
}

class _TruthLieLobbyState extends State<TruthLieLobby> {
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
    try {
      final response = await supabase
          .from('truth_lie_games')
          .select('*, truth_lie_participants!inner(user_id, is_seen)')
          .eq('truth_lie_participants.user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.from(response);

      for (var game in games) {
        final creatorId = game['creator_id'];
        final creator = await supabase
            .from('profiles')
            .select()
            .eq('id', creatorId)
            .single();
        game['creator'] = creator;
      }

      if (mounted) {
        setState(() {
          _activeGames = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text("TRUTH OR LIE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchGames,
              child: _activeGames.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _activeGames.length,
                      itemBuilder: (context, index) {
                        final game = _activeGames[index];
                        final creator = game['creator'];
                        final bool isUnseen = (game['truth_lie_participants'] as List).any((p) => p['user_id'] == supabase.auth.currentUser?.id && p['is_seen'] == false);

                        return _LobbyGameCard(
                          creator: creator,
                          isUnseen: isUnseen,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TruthLiePlay(gameId: game['id'])),
                          ).then((_) => _fetchGames()),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TruthLieWizard())),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
            ),
            child: const Text("CREATE NEW GAME", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_alt_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 24),
          Text("No Games to Guess", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          const Text("Wait for friends to start a game or start one!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LobbyGameCard extends StatelessWidget {
  final Map<String, dynamic> creator;
  final bool isUnseen;
  final VoidCallback onTap;

  const _LobbyGameCard({required this.creator, required this.isUnseen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isUnseen ? const Color(0xFF3B82F6).withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), width: 2),
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
              CircleAvatar(
                radius: 28,
                backgroundImage: ImageUtils.getImageProvider(creator['avatar_url']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator['name'] ?? creator['username'],
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUnseen ? "Find the lie! 🤥" : "Active Game",
                      style: TextStyle(color: isUnseen ? const Color(0xFF3B82F6) : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// 2. TRUTH LIE WIZARD (MODERN CARD BUILDER)
// ==================================================
class TruthLieWizard extends StatefulWidget {
  const TruthLieWizard({super.key});
  @override
  State<TruthLieWizard> createState() => _TruthLieWizardState();
}

class _TruthLieWizardState extends State<TruthLieWizard> {
  int _currentStep = 0;
  List<AppUser> _selectedFriends = [];
  final _truth1Ctrl = TextEditingController();
  final _truth2Ctrl = TextEditingController();
  final _lieCtrl = TextEditingController();
  bool _isLaunching = false;

  void _nextStep() {
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _currentStep--);
    }
  }

  Future<void> _launchGame() async {
    if (_truth1Ctrl.text.isEmpty || _truth2Ctrl.text.isEmpty || _lieCtrl.text.isEmpty) return;

    setState(() => _isLaunching = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      final game = await supabase.from('truth_lie_games').insert({'creator_id': userId}).select().single();
      final gameId = game['id'];

      final participantIds = {..._selectedFriends.map((f) => f.id), userId};
      final participants = participantIds.map((id) => {
        'game_id': gameId, 
        'user_id': id,
        'is_seen': id == userId,
      }).toList();
      await supabase.from('truth_lie_participants').insert(participants);

      await supabase.from('truth_lie_actions').insert({
        'game_id': gameId,
        'user_id': userId,
        'action_type': 'setup',
        'data': {
          'truths': [_truth1Ctrl.text, _truth2Ctrl.text],
          'lie': _lieCtrl.text,
        }
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TruthLiePlay(gameId: gameId)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildProgressIndicator(),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCurrentStep(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3B82F6) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return GameFriendSelectionScreen(
          onContinue: (friends) {
            setState(() => _selectedFriends = friends);
            _nextStep();
          },
        );
      case 1:
        return _buildBuilderStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBuilderStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create Your Statements", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Write two things that are true and one lie.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          
          _buildStatementInput(_truth1Ctrl, "Truth #1", Colors.green, isDark),
          const SizedBox(height: 16),
          _buildStatementInput(_truth2Ctrl, "Truth #2", Colors.green, isDark),
          const SizedBox(height: 16),
          _buildStatementInput(_lieCtrl, "The Lie", Colors.red, isDark),
        ],
      ),
    );
  }

  Widget _buildStatementInput(TextEditingController ctrl, String label, Color accent, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "Write here...",
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 80, color: Color(0xFF3B82F6)),
            const SizedBox(height: 32),
            const Text("Ready to Challenge?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Text("Playing with ${_selectedFriends.length} friends", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_currentStep == 0) return const SizedBox();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _prevStep,
                child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
              ),
            ),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLaunching ? null : (_currentStep == 2 ? _launchGame : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLaunching 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentStep == 2 ? "LAUNCH" : "CONTINUE", style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// 3. TRUTH LIE PLAY (GAME SHOW EXPERIENCE)
// ==================================================
class TruthLiePlay extends StatefulWidget {
  final String gameId;
  const TruthLiePlay({super.key, required this.gameId});
  @override
  State<TruthLiePlay> createState() => _TruthLiePlayState();
}

class _TruthLiePlayState extends State<TruthLiePlay> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _game;
  Map<String, dynamic>? _creator;
  List<String> _shuffled = [];
  int? _lieIdx;
  bool _isLoading = true;
  String? _voted;
  bool _isExpired = false;
  Map<int, int> _votes = {0: 0, 1: 0, 2: 0};
  int _totalVotes = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _markSeen();
  }

  Future<void> _markSeen() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('truth_lie_participants').update({'is_seen': true}).match({'game_id': widget.gameId, 'user_id': userId});
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final gameRes = await supabase.from('truth_lie_games').select().eq('id', widget.gameId).single();
      
      final creatorId = gameRes['creator_id'];
      final creator = await supabase
          .from('profiles')
          .select()
          .eq('id', creatorId)
          .single();
      gameRes['creator'] = creator;

      final setup = await supabase.from('truth_lie_actions').select().eq('game_id', widget.gameId).eq('action_type', 'setup').single();
      final myVote = await supabase.from('truth_lie_actions').select().eq('game_id', widget.gameId).eq('user_id', userId).eq('action_type', 'vote').maybeSingle();

      final truths = List<String>.from(setup['data']['truths']);
      final lie = setup['data']['lie'];
      final all = List<String>.from([...truths, lie]);
      
      // Deterministic shuffle
      final seed = widget.gameId.hashCode;
      all.sort();
      if (seed % 3 == 0) {
        final t = all[0]; all[0] = all[1]; all[1] = t;
      } else if (seed % 3 == 1) {
        final t = all[1]; all[1] = all[2]; all[2] = t;
      } else {
        final t = all[0]; all[0] = all[2]; all[2] = t;
      }
      
      _shuffled = all;
      _lieIdx = all.indexOf(lie);

      final createdAt = DateTime.parse(gameRes['created_at']);
      final isExpired = DateTime.now().difference(createdAt).inHours >= 24;

      if (isExpired) {
        final allVotes = await supabase.from('truth_lie_actions').select('data').eq('game_id', widget.gameId).eq('action_type', 'vote');
        final Map<int, int> counts = {0: 0, 1: 0, 2: 0};
        for (var v in (allVotes as List)) {
          final idx = v['data']['index'] as int;
          counts[idx] = (counts[idx] ?? 0) + 1;
        }
        _votes = counts;
        _totalVotes = allVotes.length;
      }

      if (mounted) {
        setState(() {
          _game = gameRes;
          _creator = gameRes['creator'];
          _voted = myVote?['data']?['statement'];
          _isExpired = isExpired;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(int index, String statement) async {
    if (_voted != null || _isExpired) return;
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('truth_lie_actions').insert({
        'game_id': widget.gameId,
        'user_id': userId,
        'action_type': 'vote',
        'data': {'index': index, 'statement': statement},
      });
      setState(() => _voted = statement);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_isExpired) return _buildResults();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("FIND THE LIE", style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(radius: 40, backgroundImage: ImageUtils.getImageProvider(_creator?['avatar_url'])),
            const SizedBox(height: 12),
            Text("@${_creator?['username']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            const Text("Claims two are true and one is a lie...", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),
            ...List.generate(_shuffled.length, (i) {
              final statement = _shuffled[i];
              final isVoted = _voted == statement;
              return GestureDetector(
                onTap: () => _vote(i, statement),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isVoted ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF16181D) : Colors.white),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isVoted ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), width: 2),
                    boxShadow: isVoted ? [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4))] : [],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          statement, 
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.w800,
                            color: isVoted ? Colors.white : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                      if (isVoted) const Icon(Icons.check_circle_rounded, color: Colors.white),
                    ],
                  ),
                ),
              );
            }),
            if (_voted != null) ...[
              const SizedBox(height: 32),
              const Icon(Icons.lock_clock_rounded, color: Colors.grey),
              const SizedBox(height: 8),
              const Text("Vote Locked! Results in 24h.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("RESULTS", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("The lie was...", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 2),
              ),
              child: Text(
                _shuffled[_lieIdx!],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 48),
            const Text("VOTING STATS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
            const SizedBox(height: 24),
            ...List.generate(_shuffled.length, (i) {
              final isLie = i == _lieIdx;
              final count = _votes[i] ?? 0;
              final pct = _totalVotes > 0 ? count / _totalVotes : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(_shuffled[i], style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (isLie) const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Text("$count votes", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3B82F6))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                        color: isLie ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
