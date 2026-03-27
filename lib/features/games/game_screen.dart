import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../models/user.dart';
import '../../services/game_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _gameService = GameService();
  final _supabase = Supabase.instance.client;
  final _questionController = TextEditingController();
  
  // State for setup: Text options (Minimum 2, Maximum 4)
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  Game? _game;
  List<GameAction> _actions = [];
  bool _isLoading = true;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGameData() async {
    setState(() => _isLoading = true);
    try {
      final game = await _gameService.getGameById(widget.gameId);
      final actions = await _supabase
          .from('game_actions')
          .select()
          .eq('game_id', widget.gameId)
          .order('created_at');
      
      if (mounted) {
        setState(() {
          _game = game;
          _actions = (actions as List).map((a) => GameAction.fromJson(a)).toList();
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint("Error loading game: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    if (_game?.endsAt == null) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(_game!.endsAt!)) {
        timer.cancel();
        if (mounted) setState(() => _timeLeft = Duration.zero);
      } else {
        if (mounted) {
          setState(() {
            _timeLeft = _game!.endsAt!.difference(now);
          });
        }
      }
    });
  }

  void _addOption() {
    if (_optionControllers.length < 4) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitSetup() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a question")));
      return;
    }

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide at least 2 options")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Set ends_at to 24h from now
      final endsAt = DateTime.now().add(const Duration(hours: 24));
      await _supabase.from('games').update({
        'ends_at': endsAt.toIso8601String(),
      }).eq('id', widget.gameId);

      await _gameService.submitAction(widget.gameId, 'question', {
        'question': question,
        'options': options,
      });
      _loadGameData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitVote(int optionIndex) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _gameService.submitAction(widget.gameId, 'vote', {
      'option_index': optionIndex,
    });
    _loadGameData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_game == null) {
      return const Scaffold(body: Center(child: Text("Game not found")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(_game!.gameType == 'most_likely' ? "MOST LIKELY TO" : "GAME", 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        elevation: 0,
        backgroundColor: const Color(0xFF2C4E6E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildTimerBadge(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildTimerBadge() {
    bool isEnded = _game!.isExpired;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 14, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              _formatDuration(_timeLeft),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.redAccent, 
                fontSize: 12
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final questionAction = _actions.isEmpty ? null : _actions.firstWhere(
      (a) => a.actionType == 'question',
      orElse: () => GameAction(id: '', gameId: '', userId: '', actionType: '', data: {}, createdAt: DateTime.now()),
    );

    if (questionAction == null || questionAction.id.isEmpty) {
      return _buildState1Setup();
    }

    if (_game!.isExpired) {
      return _buildState4Results(questionAction);
    }

    final myId = _supabase.auth.currentUser?.id;
    final myVote = _actions.firstWhere(
      (a) => a.actionType == 'vote' && a.userId == myId,
      orElse: () => GameAction(id: '', gameId: '', userId: '', actionType: '', data: {}, createdAt: DateTime.now()),
    );

    if (myVote.id.isNotEmpty) {
      return _buildState3AlreadyVoted(questionAction, myVote);
    }

    return _buildState2Voting(questionAction);
  }

  // STATE 1: SETUP
  Widget _buildState1Setup() {
    final myId = _supabase.auth.currentUser?.id;
    if (_game!.createdBy != myId) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.blue[100]),
            const SizedBox(height: 24),
            const Text("Waiting for the creator", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("The game will start once a question is set.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          "1. Enter your question",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Who is most likely to...",
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "2. Options",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (_optionControllers.length < 4)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Option", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_optionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: TextField(
                controller: _optionControllers[index],
                decoration: InputDecoration(
                  hintText: "Option ${index + 1}",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _optionControllers.length > 2
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                          onPressed: () => _removeOption(index),
                        )
                      : null,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _submitSetup,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C4E6E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  // STATE 2: VOTING
  Widget _buildState2Voting(GameAction questionAction) {
    final question = questionAction.data['question'];
    final options = List<String>.from(questionAction.data['options'] ?? []);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("WHO IS MOST LIKELY TO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => _submitVote(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(options[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // STATE 3: ALREADY VOTED
  Widget _buildState3AlreadyVoted(GameAction questionAction, GameAction myVote) {
    final question = questionAction.data['question'];
    final options = List<String>.from(questionAction.data['options'] ?? []);
    final selectedIndex = myVote.data['option_index'] as int;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final isMyVote = index == selectedIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isMyVote ? Colors.blue.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isMyVote ? Colors.blue : Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(options[index], style: TextStyle(fontWeight: FontWeight.bold, color: isMyVote ? Colors.blue : Colors.black)),
                      ),
                      if (isMyVote) const Icon(Icons.check, color: Colors.blue, size: 20),
                    ],
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("You've cast your vote!", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // STATE 4: RESULTS
  Widget _buildState4Results(GameAction questionAction) {
    final question = questionAction.data['question'];
    final options = List<String>.from(questionAction.data['options'] ?? []);
    
    final votes = _actions.where((a) => a.actionType == 'vote').toList();
    final totalVotes = votes.length;
    final Map<int, int> voteCounts = {};
    for (var v in votes) {
      final index = v.data['option_index'] as int;
      voteCounts[index] = (voteCounts[index] ?? 0) + 1;
    }

    final sortedIndices = List.generate(options.length, (i) => i);
    sortedIndices.sort((a, b) => (voteCounts[b] ?? 0).compareTo(voteCounts[a] ?? 0));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("FINAL RESULTS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: sortedIndices.length,
              itemBuilder: (context, index) {
                final optIdx = sortedIndices[index];
                final count = voteCounts[optIdx] ?? 0;
                final percentage = totalVotes == 0 ? 0.0 : count / totalVotes;
                final isWinner = index == 0 && count > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(options[optIdx], style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Text("$count", style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (isWinner) const Padding(padding: EdgeInsets.only(left: 8), child: Text("🏆")),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(height: 10, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(5))),
                          AnimatedContainer(
                            duration: const Duration(seconds: 1),
                            height: 10,
                            width: (MediaQuery.of(context).size.width - 48) * percentage,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: isWinner ? [Colors.orange, Colors.orangeAccent] : [Colors.blue, Colors.blueAccent]),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "Ended";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
