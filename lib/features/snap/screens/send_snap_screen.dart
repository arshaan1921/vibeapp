import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../utils/image_utils.dart';
import '../../../services/notification_service.dart';
import '../../../services/image_optimizer_service.dart';
import '../models/streak.dart';

class SendSnapScreen extends StatefulWidget {
  final String imagePath;
  final bool isVideo;
  const SendSnapScreen({super.key, required this.imagePath, this.isVideo = false});

  @override
  State<SendSnapScreen> createState() => _SendSnapScreenState();
}

class _SendSnapScreenState extends State<SendSnapScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  List<Map<String, dynamic>> _quickSend = [];
  Map<String, SnapStreak> _userStreaks = {};
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint("SEND_SNAP: Loading data for user ${user.id}");

      // 1. Fetch Friends
      final friendsRes = await supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
      
      // 2. Fetch recent message participants
      final messagesRes = await supabase
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .limit(50);

      // Combine all unique IDs
      final Set<String> allConnectedIds = {};
      
      if (friendsRes is List) {
        for (var item in friendsRes) {
          final u1 = item['user1_id']?.toString();
          final u2 = item['user2_id']?.toString();
          if (u1 != user.id && u1 != null) allConnectedIds.add(u1);
          if (u2 != user.id && u2 != null) allConnectedIds.add(u2);
        }
      }

      if (messagesRes is List) {
        for (var m in messagesRes) {
          final sId = m['sender_id']?.toString();
          final rId = m['receiver_id']?.toString();
          if (sId != null && sId != user.id) allConnectedIds.add(sId);
          if (rId != null && rId != user.id) allConnectedIds.add(rId);
        }
      }

      allConnectedIds.remove(user.id);
      debugPrint("SEND_SNAP: Found ${allConnectedIds.length} connected user IDs");

      List<Map<String, dynamic>> friendsData = [];
      if (allConnectedIds.isNotEmpty) {
        try {
          final profilesRes = await supabase
              .from('profiles')
              .select('id, username, name, avatar_url, premium_plan')
              .inFilter('id', allConnectedIds.toList());
          
          friendsData = List<Map<String, dynamic>>.from(profilesRes as List);
          debugPrint("SEND_SNAP: Fetched ${friendsData.length} profiles from connections");
        } catch (e) {
          debugPrint("SEND_SNAP: Profiles query error: $e");
        }
      }

      // 3. Fetch recent snap recipients for "Quick Send"
      List<Map<String, dynamic>> quickSendData = [];
      try {
        final recentSnapsRes = await supabase
            .from('snap_recipients')
            .select('recipient_id, snaps!inner(sender_id, created_at)')
            .eq('snaps.sender_id', user.id)
            .order('snaps(created_at)', ascending: false)
            .limit(20);

        final List<dynamic> recentSnaps = recentSnapsRes as List;
        final Set<String> recentIds = {};
        for (var s in recentSnaps) {
          final rid = s['recipient_id']?.toString();
          if (rid != null) recentIds.add(rid);
        }

        if (recentIds.isNotEmpty) {
          final recentProfilesRes = await supabase
              .from('profiles')
              .select('id, username, name, avatar_url, premium_plan')
              .inFilter('id', recentIds.toList());
          
          final List<Map<String, dynamic>> fetchedRecent = List<Map<String, dynamic>>.from(recentProfilesRes as List);
          
          // Sort by the order in recentIds to maintain recency
          for (var id in recentIds) {
            final profile = fetchedRecent.firstWhere((p) => p['id'] == id, orElse: () => {});
            if (profile.isNotEmpty) quickSendData.add(profile);
            if (quickSendData.length >= 10) break;
          }
        }
      } catch (e) {
        debugPrint("SEND_SNAP: Quick send fetch error: $e");
      }

      // 4. Fallback: If still no connections, fetch suggested users
      if (friendsData.isEmpty) {
        debugPrint("SEND_SNAP: No connections found, fetching suggested users...");
        try {
          final suggestedRes = await supabase
              .from('profiles')
              .select('id, username, name, avatar_url, premium_plan')
              .neq('id', user.id)
              .limit(20);
          friendsData = List<Map<String, dynamic>>.from(suggestedRes as List);
          debugPrint("SEND_SNAP: Fetched ${friendsData.length} suggested profiles");
        } catch (e) {
          debugPrint("SEND_SNAP: Suggested profiles error: $e");
        }
      }

      // If quick send is empty (no snaps sent yet), use top friends
      if (quickSendData.isEmpty) {
        quickSendData = friendsData.take(10).toList();
      }

      // 5. Fetch Streaks
      Map<String, SnapStreak> streaksMap = {};
      try {
        final streaksResponse = await supabase
            .from('snap_streaks')
            .select('*, id, user1_id, user2_id, streak_count, broken_streak_count, is_restoreable, restore_deadline')
            .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
        
        final List<dynamic> streaksData = List<dynamic>.from(streaksResponse as List);
        debugPrint('Loaded streaks: ${ streaksData.length}');

        for (var row in streaksData) {
          final u1 = row['user1_id'] as String;
          final u2 = row['user2_id'] as String;
          final friendId = (u1 == user.id) ? u2 : u1;
          final streak = SnapStreak.fromMap(row);
          streaksMap[friendId] = streak;
          debugPrint('STREAK_DEBUG: friendId=$friendId, streakId=${streak.id}, streakCount=${streak.streakCount}, brokenStreakCount=${streak.brokenStreakCount}, isRestoreable=${streak.isRestoreable}, canBeRestored=${streak.canBeRestored}');
        }
      } catch (e) {
        debugPrint("SEND_SNAP: Streaks fetch error: $e");
      }

      if (mounted) {
        setState(() {
          _friends = friendsData;
          _filteredFriends = _friends;
          _quickSend = quickSendData;
          _userStreaks = streaksMap;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint("SEND_SNAP: Global Error: $e");
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFriends = _friends.where((u) {
        final username = (u['username'] ?? '').toLowerCase();
        final name = (u['name'] ?? '').toLowerCase();
        return username.contains(query) || name.contains(query);
      }).toList();
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _sendSnap() async {
    if (_selectedUserIds.isEmpty) return;
    
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Upload File to Storage
      final bool isVideo = widget.isVideo || widget.imagePath.endsWith('.mp4') || widget.imagePath.endsWith('.mov');
      
      String fileName;
      String contentType;
      Uint8List bytes;

      if (isVideo) {
        fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        contentType = 'video/mp4';
        bytes = await File(widget.imagePath).readAsBytes();
      } else {
        final compressedFile = await ImageOptimizerService.compressSnapImage(File(widget.imagePath));
        bytes = await compressedFile.readAsBytes();
        fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        contentType = 'image/jpeg';
      }

      await supabase.storage.from('snaps').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType),
      );

      final imageUrl = supabase.storage.from('snaps').getPublicUrl(fileName);

      // 2. Create Snap Entry
      final snapResponse = await supabase
          .from('snaps')
          .insert({
            'sender_id': user.id,
            'image_url': imageUrl,
            'caption': '', 
            'is_story': false,
          })
          .select()
          .single();

      final snapId = snapResponse['id'];
      print('SNAP CREATED: $snapId');
      print('CURRENT USER: ${user.id}');
      print('SELECTED RECIPIENTS: $_selectedUserIds');

      // 3. Create Snap Recipients
      if (_selectedUserIds.isNotEmpty) {
        final recipients = _selectedUserIds.map((rid) {
          return {
            'snap_id': snapId,
            'recipient_id': rid,
            'status': 'sent',
          };
        }).toList();

        debugPrint('SNAP_RECIPIENT_AUDIT: Attempting to insert ${recipients.length} recipients for snap $snapId');
        debugPrint('SNAP_RECIPIENT_AUDIT: Recipients: $_selectedUserIds');

        try {
          final res = await supabase.from('snap_recipients').insert(recipients).select();
          debugPrint('SNAP_RECIPIENT_SUCCESS: $res');

          // 4. Send Push Notifications
          try {
            // Fetch sender username
            final profileRes = await supabase
                .from('profiles')
                .select('username')
                .eq('id', user.id)
                .maybeSingle();
            
            final username = profileRes?['username'] ?? "Someone";

            // Send notifications in parallel
            await Future.wait(_selectedUserIds.map((recipientId) {
              return NotificationService.sendNotification(
                userId: recipientId,
                title: "New Snap 👻",
                body: "$username sent you a snap",
                data: {
                  "type": "snap",
                  "snap_id": snapId,
                  "sender_id": user.id,
                },
              );
            }));
            debugPrint("✅ Snap notifications sent to ${_selectedUserIds.length} recipients");
          } catch (e) {
            debugPrint("⚠️ Snap notification sending failed: $e");
            // Notification failure shouldn't stop the snap success flow
          }
        } catch (e, st) {
          debugPrint('SNAP_RECIPIENT_ERROR: Failed to insert recipients');
          debugPrint('SNAP_RECIPIENT_ERROR_DETAILS: $e');
          debugPrintStack(stackTrace: st);
          rethrow; // Ensure failure is not silent
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Snap sent!")),
        );
        
        // Return to Chats screen
        tabIndexNotifier.value = 3;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Error sending snap: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send snap: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSelected = _selectedUserIds.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Send To", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search friends...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _friends.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      // Horizontal Selected Users row (if any)
                      if (_selectedUserIds.isNotEmpty) _buildSelectedUsersRow(),

                      // QUICK SEND
                      if (_quickSend.isNotEmpty) ...[
                        _buildSectionHeader("QUICK SEND"),
                        _buildQuickSendList(),
                      ],

                      // FRIENDS
                      _buildSectionHeader("FRIENDS"),
                      ..._filteredFriends.map((u) => _buildUserTile(u)),
                    ],
                  ),
          ),
        ],
      ),
      bottomSheet: totalSelected > 0
        ? _buildBottomActionBar(totalSelected)
        : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "No Friends Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add friends to start sharing snaps.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to trending/discover people tab (Index 1 in MainScaffold)
              Navigator.pop(context);
              tabIndexNotifier.value = 1;
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Find Friends"),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUsersRow() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _selectedUserIds.map((id) {
          final user = _friends.firstWhere((u) => u['id'] == id, orElse: () => _quickSend.firstWhere((u) => u['id'] == id));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: ImageUtils.getImageProvider(user['avatar_url']),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: Text(
                    user['username'] ?? "User",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildStoryTile({required String title, required String subtitle, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blue, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.withOpacity(0.5), width: 2),
          color: isSelected ? Colors.green : Colors.transparent,
        ),
        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }

  Widget _buildQuickSendList() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickSend.length,
        itemBuilder: (context, index) {
          final user = _quickSend[index];
          final isSelected = _selectedUserIds.contains(user['id']);
          return GestureDetector(
            onTap: () => _toggleUserSelection(user['id']),
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: ImageUtils.getImageProvider(user['avatar_url']),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      user['name']?.split(' ').first ?? user['username'] ?? "",
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.green : null,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'];
    final isSelected = _selectedUserIds.contains(userId);
    final streakData = _userStreaks[userId];
    final streak = streakData?.streakCount ?? 0;
    final brokenStreak = streakData?.brokenStreakCount ?? 0;
    final canBeRestored = streakData?.canBeRestored ?? false;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[200],
        backgroundImage: ImageUtils.getImageProvider(user['avatar_url']),
      ),
      title: Text(
        user['name'] ?? user['username'] ?? "User", 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          if (streak > 0 || (brokenStreak > 0 && canBeRestored)) ...[
            Text(
              streak > 0 ? "${streak}🔥" : "${brokenStreak}💔", 
              style: TextStyle(
                color: streak > 0 ? Colors.orange : Colors.redAccent, 
                fontWeight: FontWeight.bold, 
                fontSize: 13
              )
            ),
            const SizedBox(width: 8),
          ],
          Text("@${user['username'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
      trailing: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
          color: isSelected ? Colors.green : Colors.transparent,
        ),
        child: isSelected 
          ? const Icon(Icons.check, size: 16, color: Colors.white) 
          : null,
      ),
      onTap: () => _toggleUserSelection(userId),
    );
  }

  Widget _buildBottomActionBar(int totalSelected) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$totalSelected ${totalSelected == 1 ? 'Recipient' : 'Recipients'} Selected",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _sendSnap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              "SEND SNAP",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}
