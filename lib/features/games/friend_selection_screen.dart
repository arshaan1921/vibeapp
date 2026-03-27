import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/game_service.dart';
import 'game_play_screen.dart';

class FriendSelectionScreen extends StatefulWidget {
  final String gameType;
  final List<Map<String, dynamic>> savedUsers;

  const FriendSelectionScreen({
    super.key,
    required this.gameType,
    required this.savedUsers,
  });

  @override
  State<FriendSelectionScreen> createState() => _FriendSelectionScreenState();
}

class _FriendSelectionScreenState extends State<FriendSelectionScreen> {
  final _gameService = GameService();
  late List<AppUser> _friends;
  final Set<String> _selectedUserIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _friends = widget.savedUsers.map((json) => AppUser.fromJson(json)).toList();
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGame() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one friend")),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final game = await _gameService.createGame(
        widget.gameType, 
        _selectedUserIds.toList()
      );
      
      if (mounted) {
        // Replace current selection screen with the actual game
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GamePlayScreen(game: game),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating game: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SELECT FRIENDS"),
      ),
      body: _friends.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No saved profiles found",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _friends.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                final isSelected = _selectedUserIds.contains(friend.id);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    friend.username,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    friend.name ?? "",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey[300],
                  ),
                  onTap: () => _toggleSelection(friend.id),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (_isCreating || _selectedUserIds.isEmpty) ? null : _createGame,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    "START NEW GAME (${_selectedUserIds.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
