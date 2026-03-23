import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/secret_crush.dart';
import '../../../models/user.dart';
import '../../../services/secret_crush_service.dart';

class CrushGameDetailScreen extends StatefulWidget {
  final String gameId;
  const CrushGameDetailScreen({super.key, required this.gameId});

  @override
  State<CrushGameDetailScreen> createState() => _CrushGameDetailScreenState();
}

class _CrushGameDetailScreenState extends State<CrushGameDetailScreen> {
  final _service = SecretCrushService();
  bool _isLoading = true;
  bool _hasSelected = false;
  List<AppUser> _participants = [];
  String? _selectedCrushId;
  SecretCrushMatch? _match;
  bool _isSubmitting = false;
  RealtimeChannel? _matchChannel;

  @override
  void initState() {
    super.initState();
    _loadState();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_matchChannel != null) {
      Supabase.instance.client.removeChannel(_matchChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    
    _matchChannel = Supabase.instance.client
        .channel('crush_match_listener_${widget.gameId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'secret_crush_matches',
          callback: (payload) {
            final data = payload.newRecord;
            if (data['game_id'] == widget.gameId &&
                (data['user1'] == currentUserId || data['user2'] == currentUserId)) {
              // ignore: avoid_print
              print("Match detected via Realtime!");
              _loadState();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadState() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      // ignore: avoid_print
      print("Loading state for Game ID: ${widget.gameId}");

      // 1. Fetch matches and check for current user
      final matchRes = await Supabase.instance.client
          .from('secret_crush_matches')
          .select('*, user1_profile:profiles!user1(*), user2_profile:profiles!user2(*)')
          .eq('game_id', widget.gameId);

      SecretCrushMatch? myMatch;
      for (final m in (matchRes as List)) {
        if (m['user1'] == currentUserId || m['user2'] == currentUserId) {
          myMatch = SecretCrushMatch.fromJson(m);
          break;
        }
      }

      // 2. Check selection status
      final choiceResponse = await Supabase.instance.client
          .from('secret_crush_choices')
          .select()
          .match({'game_id': widget.gameId, 'chooser_id': currentUserId})
          .maybeSingle();

      // 3. Get participants
      List<AppUser> participants = [];
      if (myMatch == null) {
        participants = await _service.getParticipants(widget.gameId);
      }

      if (mounted) {
        setState(() {
          _match = myMatch;
          _hasSelected = choiceResponse != null;
          _participants = participants.where((p) => p.id != currentUserId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSelection() async {
    if (_selectedCrushId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      // ignore: avoid_print
      print("Submitting choice in Game ID: ${widget.gameId}");

      // 1. Insert choice
      await Supabase.instance.client.from('secret_crush_choices').insert({
        'game_id': widget.gameId,
        'chooser_id': currentUserId,
        'crush_id': _selectedCrushId!,
      });
      
      // 2. Immediate reverse check
      final reverseChoice = await Supabase.instance.client
          .from('secret_crush_choices')
          .select()
          .match({
            'game_id': widget.gameId,
            'chooser_id': _selectedCrushId!,
            'crush_id': currentUserId,
          })
          .maybeSingle();

      // ignore: avoid_print
      print("Reverse choice result: $reverseChoice");

      if (reverseChoice != null) {
        // Normalize user order
        final users = [currentUserId, _selectedCrushId!]..sort();
        final user1 = users[0];
        final user2 = users[1];

        // ignore: avoid_print
        print("Mutual match found! Inserting match: $user1 & $user2");

        try {
          await Supabase.instance.client.from('secret_crush_matches').insert({
            'game_id': widget.gameId,
            'user1': user1,
            'user2': user2,
          });
        } catch (e) {
          // Ignore duplicate match errors
          // ignore: avoid_print
          print("Match insertion skipped (likely already exists): $e");
        }
      }

      // 3. Refresh UI
      await _loadState();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Crush'),
        elevation: 0,
      ),
      body: _match != null 
          ? _buildMatchUI()
          : _hasSelected 
              ? _buildWaitingUI() 
              : _buildSelectionUI(),
    );
  }

  Widget _buildSelectionUI() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'Who is your secret crush?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick one person from this game. If they pick you too, it\'s a match!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final user = _participants[index];
                final isSelected = _selectedCrushId == user.id;
                
                return InkWell(
                  onTap: () => setState(() => _selectedCrushId = user.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.pink.withOpacity(0.1) : Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.pink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty 
                              ? NetworkImage(user.avatarUrl!) 
                              : null,
                          child: user.avatarUrl == null || user.avatarUrl!.isEmpty 
                              ? const Icon(Icons.person, size: 40) 
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.username,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.pink : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedCrushId == null || _isSubmitting ? null : _submitSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ) 
                : const Text('Confirm Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 64, color: Colors.pinkAccent),
          ),
          const SizedBox(height: 32),
          const Text(
            'Your choice is locked',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Waiting for them to make their choice. Everything is private until a match!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchUI() {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final otherUser = _match?.user1Id == currentUserId ? _match?.user2 : _match?.user1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.pink.withOpacity(0.2),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '💘 Yay! It\'s a Match!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMatchAvatar(currentUserId),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Icon(Icons.favorite, color: Colors.pink, size: 48),
              ),
              _buildMatchAvatar(otherUser?.id, user: otherUser),
            ],
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You and @${otherUser?.username ?? "someone"} like each other!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 64),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 8,
              shadowColor: Colors.pink.withOpacity(0.4),
            ),
            child: const Text('Great!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchAvatar(String? id, {AppUser? user}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: user == null && id != null 
          ? Supabase.instance.client.from('profiles').select().eq('id', id).single()
          : null,
      builder: (context, snapshot) {
        final avatarUrl = user?.avatarUrl ?? snapshot.data?['avatar_url'];
        final username = user?.username ?? snapshot.data?['username'];

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pink, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundImage: avatarUrl != null && avatarUrl != '' 
                    ? NetworkImage(avatarUrl) 
                    : null,
                child: avatarUrl == null || avatarUrl == '' 
                    ? const Icon(Icons.person, size: 54) 
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '@${username ?? "unknown"}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        );
      }
    );
  }
}
