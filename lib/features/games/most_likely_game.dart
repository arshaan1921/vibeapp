import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/notification_service.dart';
import '../../services/block_service.dart';
import '../../utils/image_utils.dart';
import 'friend_selection_screen.dart';
import '../../services/game_notification_service.dart';

// ==================================================
// 1. MOST LIKELY LOBBY (REDESIGNED)
// ==================================================
class MostLikelyLobby extends StatefulWidget {
  const MostLikelyLobby({super.key});
  @override
  State<MostLikelyLobby> createState() => _MostLikelyLobbyState();
}

class _MostLikelyLobbyState extends State<MostLikelyLobby> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activeGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('most_likely_games')
          .select('*, most_likely_participants!inner(user_id, is_seen)')
          .eq('most_likely_participants.user_id', userId)
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
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("MOST LIKELY TO", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                        final bool isUnseen = (game['most_likely_participants'] as List).any((p) => p['user_id'] == supabase.auth.currentUser?.id && p['is_seen'] == false);

                        return _LobbyGameCard(
                          game: game,
                          creator: creator,
                          isUnseen: isUnseen,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MostLikelyPlay(gameId: game['id'])),
                          ).then((_) => _fetchGames()),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MostLikelyWizard())),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: const Color(0xFFEC4899).withOpacity(0.4),
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
          Icon(Icons.auto_awesome_motion_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 24),
          Text("No Active Games", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          const Text("Start a game and see what friends think!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LobbyGameCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final Map<String, dynamic> creator;
  final bool isUnseen;
  final VoidCallback onTap;

  const _LobbyGameCard({required this.game, required this.creator, required this.isUnseen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isUnseen ? const Color(0xFFEC4899).withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), width: 2),
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
                      isUnseen ? "Waiting for your vote!" : "Active Game",
                      style: TextStyle(color: isUnseen ? const Color(0xFFEC4899) : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
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
// 2. MOST LIKELY WIZARD (STEP-BASED SETUP)
// ==================================================
class MostLikelyWizard extends StatefulWidget {
  const MostLikelyWizard({super.key});
  @override
  State<MostLikelyWizard> createState() => _MostLikelyWizardState();
}

class _MostLikelyWizardState extends State<MostLikelyWizard> {
  int _currentStep = 0;
  List<AppUser> _selectedFriends = [];
  String _selectedQuestion = "";
  final _customQuestionCtrl = TextEditingController();
  bool _isLaunching = false;

  final List<String> _suggestedQuestions = [
    "become a millionaire?",
    "survive a zombie apocalypse?",
    "get married first?",
    "become a famous actor?",
    "forget their own birthday?",
    "win an Olympic medal?",
    "travel around the world?",
    "write a best-selling book?",
  ];

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
    final question = _customQuestionCtrl.text.isNotEmpty ? _customQuestionCtrl.text : _selectedQuestion;
    if (question.isEmpty) return;

    setState(() => _isLaunching = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      final game = await supabase.from('most_likely_games').insert({'creator_id': userId}).select().single();
      final gameId = game['id'];

      final participantIds = {..._selectedFriends.map((f) => f.id), userId};
      final participants = participantIds.map((id) => {
        'game_id': gameId, 
        'user_id': id,
        'is_seen': id == userId,
      }).toList();
      await supabase.from('most_likely_participants').insert(participants);

      await supabase.from('most_likely_actions').insert({
        'game_id': gameId,
        'user_id': userId,
        'action_type': 'setup',
        'data': {
          'question': "Who is most likely to $question",
          'options': _selectedFriends.map((f) => f.username).toList()..add("Me"),
        }
      });

      // 4. Send Notifications
      final creatorProfile = await supabase.from('profiles').select('username').eq('id', userId).single();
      final creatorUsername = creatorProfile['username'] ?? "Someone";

      for (var friend in _selectedFriends) {
        GameNotificationService.notify(
          recipientId: friend.id,
          gameId: gameId,
          gameType: 'most_likely',
          action: 'invitation',
          title: "Most Likely To 🎮",
          body: "@$creatorUsername invited you to play!",
        ).catchError((e) => debugPrint("Notification error: $e"));
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MostLikelyPlay(gameId: gameId)),
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
            color: isActive ? const Color(0xFFEC4899) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return FriendSelectionScreen(
          onContinue: (friends) {
            setState(() => _selectedFriends = friends);
            _nextStep();
          },
        );
      case 1:
        return _buildQuestionStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildQuestionStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Choose a Question", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Select a fun scenario or write your own.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          TextField(
            controller: _customQuestionCtrl,
            decoration: InputDecoration(
              hintText: "Who is most likely to...",
              filled: true,
              fillColor: isDark ? const Color(0xFF16181D) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 24),
          const Text("SUGGESTIONS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _suggestedQuestions.map((q) {
              final isSelected = _selectedQuestion == q;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedQuestion = q;
                  _customQuestionCtrl.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEC4899) : (isDark ? const Color(0xFF16181D) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                  ),
                  child: Text(
                    "... $q",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final question = _customQuestionCtrl.text.isNotEmpty ? _customQuestionCtrl.text : _selectedQuestion;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 80, color: Color(0xFFEC4899)),
            const SizedBox(height: 32),
            const Text("Ready to Launch?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.2)),
              ),
              child: Text(
                "Who is most likely to $question",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFEC4899)),
              ),
            ),
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
                  backgroundColor: const Color(0xFFEC4899),
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
// 3. MOST LIKELY PLAY (STORY STYLE)
// ==================================================
class MostLikelyPlay extends StatefulWidget {
  final String gameId;
  const MostLikelyPlay({super.key, required this.gameId});
  @override
  State<MostLikelyPlay> createState() => _MostLikelyPlayState();
}

class _MostLikelyPlayState extends State<MostLikelyPlay> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _game;
  Map<String, dynamic>? _creator;
  String? _question;
  List<String> _options = [];
  bool _isLoading = true;
  String? _votedOption;
  bool _isExpired = false;
  Map<String, int> _votes = {};
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
    await supabase.from('most_likely_participants').update({'is_seen': true}).match({'game_id': widget.gameId, 'user_id': userId});
    await GameNotificationService.markAsSeen(widget.gameId);
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final gameRes = await supabase.from('most_likely_games').select().eq('id', widget.gameId).single();
      
      final creatorId = gameRes['creator_id'];
      final creator = await supabase
          .from('profiles')
          .select()
          .eq('id', creatorId)
          .single();
      gameRes['creator'] = creator;

      final setup = await supabase.from('most_likely_actions').select().eq('game_id', widget.gameId).eq('action_type', 'setup').single();
      final myVote = await supabase.from('most_likely_actions').select().eq('game_id', widget.gameId).eq('user_id', userId).eq('action_type', 'vote').maybeSingle();

      final createdAt = DateTime.parse(gameRes['created_at']);
      final isExpired = DateTime.now().difference(createdAt).inHours >= 24;

      if (isExpired) {
        final allVotes = await supabase.from('most_likely_actions').select('data').eq('game_id', widget.gameId).eq('action_type', 'vote');
        final Map<String, int> counts = {};
        for (var v in (allVotes as List)) {
          final opt = v['data']['option'] as String;
          counts[opt] = (counts[opt] ?? 0) + 1;
        }
        _votes = counts;
        _totalVotes = allVotes.length;
      }

      if (mounted) {
        setState(() {
          _game = gameRes;
          _creator = gameRes['creator'];
          _question = setup['data']['question'];
          _options = List<String>.from(setup['data']['options']);
          _votedOption = myVote?['data']?['option'];
          _isExpired = isExpired;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(String option) async {
    if (_votedOption != null || _isExpired) return;
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('most_likely_actions').insert({
        'game_id': widget.gameId,
        'user_id': userId,
        'action_type': 'vote',
        'data': {'option': option},
      });
      setState(() => _votedOption = option);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote cast! 🎯")));

      // Notify game creator
      final creatorId = _game?['creator_id'];
      if (creatorId != null && creatorId != userId) {
        final voterProfile = await supabase.from('profiles').select('username').eq('id', userId).single();
        final voterUsername = voterProfile['username'] ?? "Someone";

        GameNotificationService.notify(
          recipientId: creatorId,
          gameId: widget.gameId,
          gameType: 'most_likely',
          action: 'vote',
          title: "Most Likely To 🎯",
          body: "@$voterUsername cast a vote in your game!",
        ).catchError((e) => debugPrint("Notification error: $e"));
      }

      // Check if everyone voted
      final participantsRes = await supabase.from('most_likely_participants').select('user_id').eq('game_id', widget.gameId);
      final votesRes = await supabase.from('most_likely_actions').select('user_id').eq('game_id', widget.gameId).eq('action_type', 'vote');
      
      if ((votesRes as List).length == (participantsRes as List).length) {
        for (var p in participantsRes) {
          GameNotificationService.notify(
            recipientId: p['user_id'],
            gameId: widget.gameId,
            gameType: 'most_likely',
            action: 'results',
            title: "Results Available! 🏆",
            body: "Everyone has voted in Most Likely To. See the results!",
          ).catchError((e) => debugPrint("Notification error: $e"));
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_isExpired) return MostLikelyResults(question: _question!, votes: _votes, total: _totalVotes, options: _options);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF1A1A2E), const Color(0xFF0B0B0F)] : [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // STORY HEADER
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: ImageUtils.getImageProvider(_creator?['avatar_url']),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _creator?['username'] ?? "Someone",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Spacer(),
              // QUESTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _question ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFFEC4899),
                    shadows: [Shadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                ),
              ),
              const Spacer(),
              // VOTING CARDS
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: _options.map((opt) {
                    final isSelected = _votedOption == opt;
                    return GestureDetector(
                      onTap: () => _vote(opt),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEC4899) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              if (_votedOption != null)
                const Text("Waiting for game to end... ⏳", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// 4. MOST LIKELY RESULTS (PODIUM STYLE)
// ==================================================
class MostLikelyResults extends StatelessWidget {
  final String question;
  final Map<String, int> votes;
  final int total;
  final List<String> options;

  const MostLikelyResults({super.key, required this.question, required this.votes, required this.total, required this.options});

  @override
  Widget build(BuildContext context) {
    final sorted = options.map((o) => MapEntry(o, votes[o] ?? 0)).toList();
    sorted.sort((a, b) => b.value.compareTo(a.value));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("THE RESULTS", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 60),
            
            // PODIUM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // SECOND
                  if (sorted.length > 1) _buildPodium(sorted[1], "🥈", 120, Colors.grey, isDark),
                  const SizedBox(width: 8),
                  // FIRST
                  if (sorted.isNotEmpty) _buildPodium(sorted[0], "🥇", 180, const Color(0xFFFFD700), isDark),
                  const SizedBox(width: 8),
                  // THIRD
                  if (sorted.length > 2) _buildPodium(sorted[2], "🥉", 100, Colors.brown, isDark),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            
            // PERCENTAGE BARS
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: sorted.map((e) {
                  final pct = total > 0 ? e.value / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text("${(pct * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEC4899))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 12,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            color: const Color(0xFFEC4899),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(MapEntry<String, int> entry, String medal, double height, Color color, bool isDark) {
    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.key,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                "${entry.value} votes",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
