import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SnakesLaddersScreen extends StatefulWidget {
  const SnakesLaddersScreen({super.key});

  @override
  State<SnakesLaddersScreen> createState() => _SnakesLaddersScreenState();
}

class _SnakesLaddersScreenState extends State<SnakesLaddersScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  String _generateRoomCode() {
    return (Random().nextInt(90000000) + 10000000).toString();
  }

  Future<void> _createRoom(int maxPlayers) async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final roomCode = _generateRoomCode();
      
      final room = await supabase.from('game_rooms').insert({
        'host_id': user.id,
        'room_code': roomCode,
        'max_players': maxPlayers,
        'status': 'waiting',
      }).select().single();

      // Join as first player
      await supabase.from('game_players').insert({
        'room_id': room['id'],
        'user_id': user.id,
        'player_index': 0,
        'position': 1,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameLobbyScreen(roomId: room['id'], roomCode: roomCode, isHost: true),
          ),
        );
      }
    } catch (e) {
      debugPrint("Create room error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.length != 8) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      // Find room by code
      final roomRes = await supabase
          .from('game_rooms')
          .select()
          .eq('room_code', code)
          .eq('status', 'waiting')
          .maybeSingle();

      if (roomRes == null) {
        throw "Room not found or game already started";
      }

      // Check if already in room
      final playersRes = await supabase.from('game_players').select().eq('room_id', roomRes['id']);
      final List<dynamic> players = playersRes as List<dynamic>;
      
      if (players.any((p) => p['user_id'] == user.id)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameLobbyScreen(roomId: roomRes['id'], roomCode: code, isHost: roomRes['host_id'] == user.id),
          ),
        );
        return;
      }

      if (players.length >= roomRes['max_players']) {
        throw "Room is full";
      }

      await supabase.from('game_players').insert({
        'room_id': roomRes['id'],
        'user_id': user.id,
        'player_index': players.length,
        'position': 1,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameLobbyScreen(roomId: roomRes['id'], roomCode: code, isHost: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Players"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("2 Players"),
              onTap: () { Navigator.pop(context); _createRoom(2); },
            ),
            ListTile(
              title: const Text("4 Players"),
              onTap: () { Navigator.pop(context); _createRoom(4); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B0000), // Dark red
      appBar: AppBar(
        title: const Text("SNAKES & LADDERS"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_4x4_rounded, size: 80, color: Colors.amber),
                  const SizedBox(height: 40),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: "ENTER CODE",
                            hintStyle: TextStyle(color: Colors.white54, fontSize: 16),
                            counterText: "",
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _joinRoom,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: const Text("JOIN ROOM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text("OR", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _showCreateOptions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("CREATE PRIVATE ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class GameLobbyScreen extends StatefulWidget {
  final String roomId;
  final String roomCode;
  final bool isHost;
  const GameLobbyScreen({super.key, required this.roomId, required this.roomCode, required this.isHost});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _players = [];
  Map<String, dynamic>? _room;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _channel = supabase.channel('lobby_${widget.roomId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_players',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: widget.roomId),
        callback: (p) => _fetchData(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_rooms',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.roomId),
        callback: (p) => _fetchData(),
      )
      .subscribe();
  }

  Future<void> _fetchData() async {
    try {
      final room = await supabase.from('game_rooms').select().eq('id', widget.roomId).single();
      final players = await supabase.from('game_players').select('*, profiles(username, avatar_url)').eq('room_id', widget.roomId).order('player_index');
      
      if (mounted) {
        setState(() {
          _room = room;
          _players = List<Map<String, dynamic>>.from(players);
        });

        if (room['status'] == 'playing') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GameBoardScreen(roomId: widget.roomId, isHost: widget.isHost)),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _startGame() async {
    await supabase.from('game_rooms').update({'status': 'playing'}).eq('id', widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      appBar: AppBar(title: const Text("LOBBY"), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const Text("Room Code", style: TextStyle(color: Colors.white70)),
                  Text(widget.roomCode, style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 8),
                  const Text("Share this code with friends", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text("PLAYERS (${_players.length}/${_room!['max_players']})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                itemCount: _room!['max_players'],
                itemBuilder: (context, index) {
                  final bool hasPlayer = index < _players.length;
                  return Container(
                    decoration: BoxDecoration(
                      color: hasPlayer ? Colors.white10 : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hasPlayer ? Colors.amber : Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: hasPlayer && _players[index]['profiles']['avatar_url'] != null 
                            ? NetworkImage(_players[index]['profiles']['avatar_url']) 
                            : null,
                          child: !hasPlayer ? const Icon(Icons.add, color: Colors.white24) : (_players[index]['profiles']['avatar_url'] == null ? const Icon(Icons.person) : null),
                        ),
                        const SizedBox(height: 8),
                        Text(hasPlayer ? _players[index]['profiles']['username'] : "Waiting...", style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (widget.isHost)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _players.length >= 2 ? _startGame : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("START GAME"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GameBoardScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;
  const GameBoardScreen({super.key, required this.roomId, required this.isHost});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _players = [];
  bool _isRolling = false;
  int _currentDice = 1;
  RealtimeChannel? _channel;

  final Map<int, int> _boardMap = {
    2: 38, 7: 14, 8: 31, 15: 26, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 78: 98,
    98: 78, 95: 75, 92: 88, 64: 60, 62: 19, 49: 11, 46: 25, 16: 6
  };

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _initGame() {
    _fetchGameData();
    _subscribeToRealtime();
  }

  Future<void> _fetchGameData() async {
    try {
      final room = await supabase.from('game_rooms').select().eq('id', widget.roomId).single();
      final playersRes = await supabase.from('game_players').select('*, profiles(username, avatar_url)').eq('room_id', widget.roomId).order('player_index');
      
      if (mounted) {
        setState(() {
          _roomData = room;
          _players = List<Map<String, dynamic>>.from(playersRes as List<dynamic>);
          _currentDice = room['last_dice_roll'] ?? 1;
        });
      }
    } catch (_) {}
  }

  void _subscribeToRealtime() {
    _channel = supabase.channel('play_${widget.roomId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_rooms',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.roomId),
        callback: (payload) => _fetchGameData(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_players',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: widget.roomId),
        callback: (payload) => _fetchGameData(),
      )
      .subscribe();
  }

  Future<void> _rollDice() async {
    final user = supabase.auth.currentUser;
    if (user == null || _roomData == null) return;
    
    final myPlayer = _players.firstWhere((p) => p['user_id'] == user.id);
    if (_roomData!['current_turn_index'] != myPlayer['player_index']) return;
    if (_isRolling) return;

    setState(() => _isRolling = true);
    
    int roll = 1;
    for(int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if(!mounted) return;
      setState(() => _currentDice = Random().nextInt(6) + 1);
    }
    
    roll = Random().nextInt(6) + 1;
    setState(() { _currentDice = roll; _isRolling = false; });

    int newPos = myPlayer['position'] + roll;
    if (newPos > 100) newPos = myPlayer['position']; 
    if (_boardMap.containsKey(newPos)) newPos = _boardMap[newPos]!;

    await supabase.from('game_players').update({'position': newPos}).eq('id', myPlayer['id']);

    if (newPos == 100) {
      await supabase.from('game_rooms').update({'status': 'finished', 'winner_id': user.id}).eq('id', widget.roomId);
    } else {
      if (roll != 6) {
        int nextTurn = (_roomData!['current_turn_index'] + 1) % _players.length;
        await supabase.from('game_rooms').update({'current_turn_index': nextTurn, 'last_dice_roll': roll}).eq('id', widget.roomId);
      } else {
        await supabase.from('game_rooms').update({'last_dice_roll': roll}).eq('id', widget.roomId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_roomData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_roomData!['status'] == 'finished') {
      final winner = _players.firstWhere((p) => p['user_id'] == _roomData!['winner_id']);
      return _WinScreen(winnerName: winner['profiles']['username']);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      appBar: AppBar(
        title: Text("Code: ${_roomData!['room_code']}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildPlayerStats(),
          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _buildBoard()))),
          _buildDiceSection(),
        ],
      ),
    );
  }

  Widget _buildPlayerStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _players.map((p) {
          bool isTurn = _roomData!['current_turn_index'] == p['player_index'];
          return Column(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isTurn ? Colors.amber : Colors.transparent, width: 3)),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: p['profiles']['avatar_url'] != null ? NetworkImage(p['profiles']['avatar_url']) : null,
                  child: p['profiles']['avatar_url'] == null ? const Icon(Icons.person) : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(p['profiles']['username'], style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: isTurn ? FontWeight.bold : FontWeight.normal)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 4), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
            itemCount: 100,
            itemBuilder: (context, index) {
              int row = 9 - (index ~/ 10);
              int col = index % 10;
              if (row % 2 != 0) col = 9 - col;
              int val = row * 10 + col + 1;
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26, width: 0.5),
                  color: (val % 2 == 0) ? const Color(0xFFFFE4E1) : Colors.white,
                ),
                child: Center(child: Text(val.toString(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38))),
              );
            },
          ),
          // TOKENS
          ..._players.map((p) {
            int pos = p['position'];
            int index = pos - 1;
            int row = index ~/ 10;
            int col = index % 10;
            if (row % 2 != 0) col = 9 - col;
            double x = (col / 10.0) * 2 - 0.9;
            double y = (1.0 - (row / 10.0)) * 2 - 1.1;
            return AnimatedAlign(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              alignment: Alignment(x, y),
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: _getPlayerColor(p['player_index']), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(blurRadius: 2)]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDiceSection() {
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox();
    
    final myPlayer = _players.firstWhere((p) => p['user_id'] == user.id);
    bool isMyTurn = _roomData!['current_turn_index'] == myPlayer['player_index'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 40, top: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isMyTurn) const Icon(Icons.arrow_right_rounded, color: Colors.amber, size: 40),
              GestureDetector(
                onTap: isMyTurn ? _rollDice : null,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber, width: 3)),
                  child: Center(child: Text(_currentDice.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
                ),
              ),
              if (isMyTurn) const Icon(Icons.arrow_left_rounded, color: Colors.amber, size: 40),
            ],
          ),
          const SizedBox(height: 12),
          Text(isMyTurn ? "YOUR TURN!" : "WAITING FOR OTHERS...", style: TextStyle(color: isMyTurn ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getPlayerColor(int index) {
    return [Colors.red, Colors.blue, Colors.green, Colors.yellow][index % 4];
  }
}

class _WinScreen extends StatelessWidget {
  final String winnerName;
  const _WinScreen({required this.winnerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 100),
            const SizedBox(height: 20),
            const Text("CONGRATULATIONS!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("$winnerName WON!", style: const TextStyle(color: Colors.amber, fontSize: 24)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text("EXIT TO MENU"),
            ),
          ],
        ),
      ),
    );
  }
}
