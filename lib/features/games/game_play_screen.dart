import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../models/user.dart';
import '../../services/game_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamePlayScreen extends StatefulWidget {
  final Game game;

  const GamePlayScreen({super.key, required this.game});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final _gameService = GameService();
  final _supabase = Supabase.instance.client;
  final _questionController = TextEditingController();
  
  List<GameAction> _actions = [];
  bool _isLoading = true;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  final Set<String> _selectedOptionIds = {}; // For State 1: Creator picking options

  @override
  void initState() {
    super.initState();
    _selectedOptionIds.addAll(widget.game.participants.map((p) => p.id)); // Default all
    _startTimer();
    _loadActions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (widget.game.endsAt == null) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(widget.game.endsAt!)) {
        timer.cancel();
        if (mounted) setState(() => _timeLeft = Duration.zero);
      } else {
        if (mounted) {
          setState(() {
            _timeLeft = widget.game.endsAt!.difference(now);
          });
        }
      }
    });
  }

  Future<void> _loadActions() async {
    setState(() => _isLoading = true);
    try {
      final actions = await _supabase
          .from('game_actions')
          .select()
          .eq('game_id', widget.game.id)
          .order('created_at');
      
      if (mounted) {
        setState(() {
          _actions = (actions as List).map((a) => GameAction.fromJson(a)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading actions: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitQuestion() async {
    final text = _questionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a question")));
      return;
    }

    if (_selectedOptionIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 2 participants as options")));
      return;
    }

    await _gameService.submitAction(widget.game.id, 'question', {
      'question': text,
      'options': _selectedOptionIds.toList(),
    });
    _questionController.clear();
    _loadActions();
  }

  Future<void> _submitVote(String selectedUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    final alreadyVoted = _actions.any((a) => a.actionType == 'vote' && a.userId == myId);
    if (alreadyVoted) return;

    await _gameService.submitAction(widget.game.id, 'vote', {
      'selected_user': selectedUserId,
    });
    _loadActions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.game.gameType == 'most_likely' ? "MOST LIKELY TO" : "GAME"),
        actions: [
          if (widget.game.endsAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_timeLeft),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildGameContent(),
    );
  }

  Widget _buildGameContent() {
    final questionAction = _actions.isEmpty ? null : _actions.firstWhere(
      (a) => a.actionType == 'question',
      orElse: () => GameAction(id: '', gameId: '', userId: '', actionType: '', data: {}, createdAt: DateTime.now()),
    );

    if (questionAction == null || questionAction.id.isEmpty) {
      return _buildQuestionInput();
    }

    if (widget.game.isExpired) {
      return _buildResults(questionAction);
    }

    return _buildVotingUI(questionAction);
  }

  // STATE 1: NO QUESTION (CREATOR ONLY)
  Widget _buildQuestionInput() {
    final myId = _supabase.auth.currentUser?.id;
    if (widget.game.createdBy != myId) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("Waiting for creator to set a question...", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("1. Enter your question", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              hintText: "Who is most likely to...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          const Text("2. Select participants to include", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.game.participants.length,
            itemBuilder: (context, index) {
              final user = widget.game.participants[index];
              final isSelected = _selectedOptionIds.contains(user.id);
              return CheckboxListTile(
                title: Text(user.username),
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedOptionIds.add(user.id);
                    } else {
                      if (_selectedOptionIds.length > 2) {
                        _selectedOptionIds.remove(user.id);
                      }
                    }
                  });
                },
                secondary: CircleAvatar(
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitQuestion,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("START VOTING", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // STATE 2: VOTING (ACTIVE GAME) & STATE 3: USER ALREADY VOTED
  Widget _buildVotingUI(GameAction questionAction) {
    final myId = _supabase.auth.currentUser?.id;
    final myVote = _actions.firstWhere(
      (a) => a.actionType == 'vote' && a.userId == myId,
      orElse: () => GameAction(id: '', gameId: '', userId: '', actionType: '', data: {}, createdAt: DateTime.now()),
    );

    final question = questionAction.data['question'];
    final optionIds = List<String>.from(questionAction.data['options'] ?? []);
    final options = widget.game.participants.where((p) => optionIds.contains(p.id)).toList();

    bool hasVoted = myVote.id.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text("Most likely to...", style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final user = options[index];
                final isMyVote = hasVoted && myVote.data['selected_user'] == user.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: !hasVoted ? () => _submitVote(user.id) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMyVote ? Colors.blue.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMyVote ? Colors.blue : Colors.black12,
                          width: isMyVote ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isMyVote) BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                            child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 16),
                          Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          if (hasVoted)
                            Icon(
                              isMyVote ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isMyVote ? Colors.blue : Colors.grey[300],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (hasVoted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Text("You already voted! Results in 24h.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // STATE 4: RESULTS (AFTER 24H)
  Widget _buildResults(GameAction questionAction) {
    final question = questionAction.data['question'];
    final optionIds = List<String>.from(questionAction.data['options'] ?? []);
    final options = widget.game.participants.where((p) => optionIds.contains(p.id)).toList();
    
    final votes = _actions.where((a) => a.actionType == 'vote').toList();
    final totalVotes = votes.length;
    
    // Count votes
    final Map<String, int> voteCounts = {};
    for (var v in votes) {
      final selectedId = v.data['selected_user'] as String;
      voteCounts[selectedId] = (voteCounts[selectedId] ?? 0) + 1;
    }

    final sortedOptions = [...options];
    sortedOptions.sort((a, b) => (voteCounts[b.id] ?? 0).compareTo(voteCounts[a.id] ?? 0));

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text("FINAL RESULTS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: sortedOptions.length,
              itemBuilder: (context, index) {
                final user = sortedOptions[index];
                final count = voteCounts[user.id] ?? 0;
                final percentage = totalVotes == 0 ? 0.0 : count / totalVotes;
                final isWinner = index == 0 && count > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                            child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(user.username, style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                                    if (isWinner) ...[
                                      const SizedBox(width: 6),
                                      const Text("🏆", style: TextStyle(fontSize: 16)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.black12,
                                    color: isWinner ? Colors.orange : Colors.blue,
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (totalVotes > 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Total Votes: $totalVotes", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "Ended";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
