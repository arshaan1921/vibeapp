import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/block_service.dart';
import '../../utils/image_utils.dart';

class GameFriendSelectionScreen extends StatefulWidget {
  final String title;
  final Function(List<AppUser>) onContinue;
  final int minSelection;
  final int maxSelection;

  const GameFriendSelectionScreen({
    super.key,
    this.title = "SELECT FRIENDS",
    required this.onContinue,
    this.minSelection = 1,
    this.maxSelection = 20,
  });

  @override
  State<GameFriendSelectionScreen> createState() => _GameFriendSelectionScreenState();
}

class _GameFriendSelectionScreenState extends State<GameFriendSelectionScreen> {
  final supabase = Supabase.instance.client;
  List<AppUser> _friends = [];
  List<AppUser> _filteredFriends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredFriends = _friends.where((f) {
        return f.username.toLowerCase().contains(query) || 
               (f.name?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    await blockService.refreshBlockedList();
    await _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final friendsRes = await supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

      final List<String> friendIds = (friendsRes as List)
          .map((item) => item['user1_id'] == user.id ? item['user2_id'].toString() : item['user1_id'].toString())
          .toList();

      if (friendIds.isEmpty) {
        if (mounted) setState(() { _friends = []; _filteredFriends = []; _isLoading = false; });
        return;
      }

      final profilesResponse = await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', friendIds);

      if (mounted) {
        setState(() {
          _friends = (profilesResponse as List)
              .map((p) => AppUser.fromJson(p))
              .where((f) => !blockService.isBlocked(f.id))
              .toList();
          _filteredFriends = List.from(_friends);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friends: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(AppUser user) {
    setState(() {
      if (_selectedIds.contains(user.id)) {
        _selectedIds.remove(user.id);
      } else {
        if (_selectedIds.length < widget.maxSelection) {
          _selectedIds.add(user.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC);
    
    final selectedUsers = _friends.where((f) => _selectedIds.contains(f.id)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search friends...",
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF16181D) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // SELECTED USERS (AVATAR CHIPS)
          if (_selectedIds.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "PLAYING WITH",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: selectedUsers.length,
                      itemBuilder: (context, index) {
                        final u = selectedUsers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: ImageUtils.getImageProvider(u.avatarUrl),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => _toggleSelection(u),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // FRIENDS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final f = _filteredFriends[index];
                          final isSelected = _selectedIds.contains(f.id);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FriendCard(
                              user: f,
                              isSelected: isSelected,
                              isDark: isDark,
                              onTap: () => _toggleSelection(f),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedIds.length >= widget.minSelection
          ? FloatingActionButton.extended(
              onPressed: () => widget.onContinue(selectedUsers),
              backgroundColor: theme.primaryColor,
              elevation: 8,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: Text(
                "CONTINUE (${_selectedIds.length})",
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: isDark ? Colors.white10 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No friends yet.",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 8),
          const Text(
            "Send friend requests to start playing games.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final AppUser user;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FriendCard({
    required this.user,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
            ? (isDark ? theme.primaryColor.withOpacity(0.2) : theme.primaryColor.withOpacity(0.05))
            : (isDark ? const Color(0xFF16181D) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.primaryColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: ImageUtils.getImageProvider(user.avatarUrl),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ?? user.username,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    "@${user.username}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "7🔥", // Placeholder for actual streak if available
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
