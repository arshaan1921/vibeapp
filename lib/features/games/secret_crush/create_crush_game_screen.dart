import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user.dart';
import '../../../services/secret_crush_service.dart';

class CreateCrushGameScreen extends StatefulWidget {
  const CreateCrushGameScreen({super.key});

  @override
  State<CreateCrushGameScreen> createState() => _CreateCrushGameScreenState();
}

class _CreateCrushGameScreenState extends State<CreateCrushGameScreen> {
  final _service = SecretCrushService();
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,name.ilike.%$query%')
        .neq('id', userId)
        .limit(10);
    
    setState(() {
      _searchResults = (response as List).map((json) => AppUser.fromJson(json)).toList();
    });
  }

  Future<void> _createGame() async {
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 friends to play!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.createGame(_selectedUserIds.toList());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Secret Crush')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Add friends to the game...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final isSelected = _selectedUserIds.contains(user.id);
                final avatarUrl = user.avatarUrl;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null && avatarUrl != ''
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl == '') ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user.username),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _selectedUserIds.add(user.id);
                        else _selectedUserIds.remove(user.id);
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createGame,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const CircularProgressIndicator() 
                : const Text('Start Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
