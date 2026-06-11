import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart';
import '../utils/image_utils.dart';

class StreakAchievementScreen extends StatefulWidget {
  final String streakId;
  final String friendName;
  final int currentStreak;

  const StreakAchievementScreen({
    super.key,
    required this.streakId,
    required this.friendName,
    required this.currentStreak,
  });

  @override
  State<StreakAchievementScreen> createState() => _StreakAchievementScreenState();
}

class _StreakAchievementScreenState extends State<StreakAchievementScreen> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late AnimationController _glowController;
  
  bool _isLoadingStats = true;
  int _totalSnaps = 0;
  int _totalMessages = 0;
  int _totalReactions = 0;
  int _bestStreak = 0;
  String _myUsername = "";

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get my username
      final myProfile = await supabase.from('profiles').select('username').eq('id', user.id).single();
      _myUsername = myProfile['username'] ?? "Me";

      // 2. Get Streak Info (Best streak)
      final streakRes = await supabase
          .from('snap_streaks')
          .select('user1_id, user2_id, streak_count')
          .eq('id', widget.streakId)
          .single();
      
      final String u1 = streakRes['user1_id'];
      final String u2 = streakRes['user2_id'];
      _bestStreak = streakRes['streak_count']; // For now using current as best if not found

      // 3. Total Messages
      final messagesRes = await supabase
          .from('messages')
          .select('id')
          .or('and(sender_id.eq.$u1,receiver_id.eq.$u2),and(sender_id.eq.$u2,receiver_id.eq.$u1)');
      _totalMessages = (messagesRes as List).length;

      // 4. Total Snaps
      final snapsRes = await supabase
          .from('snap_recipients')
          .select('id')
          .or('and(recipient_id.eq.$u1,snaps.sender_id.eq.$u2),and(recipient_id.eq.$u2,snaps.sender_id.eq.$u1)');
      _totalSnaps = (snapsRes as List).length;

      // 5. Total Reactions
      final reactionsRes = await supabase
          .from('message_reactions')
          .select('id')
          .or('user_id.eq.$u1,user_id.eq.$u2'); 
      // Simplified reaction count for reliability: count all reactions from both users
      _totalReactions = (reactionsRes as List).length;

      if (mounted) setState(() => _isLoadingStats = false);
    } catch (e) {
      debugPrint("Error loading achievement stats: $e");
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _saveImage() async {
    // Check permission
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final request = await Gal.requestAccess();
      if (!request) return;
    }

    final image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/high5_century_club_${DateTime.now().millisecondsSinceEpoch}.png').create();
    await imagePath.writeAsBytes(image);

    try {
      await Gal.putImage(imagePath.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Achievement saved to gallery!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving to gallery: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save image"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareImage() async {
    final image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/high5_century_club.png').create();
    await imagePath.writeAsBytes(image);

    await Share.shareXFiles([XFile(imagePath.path)], text: "We reached the Century Club on HIGH5!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("ACHIEVEMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Screenshot(
                        controller: _screenshotController,
                        child: _buildAchievementCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard() {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "HIGH5",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "🏆 CENTURY CLUB",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                widget.friendName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.favorite, color: Colors.red, size: 18),
              ),
              Text(
                _myUsername,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2 * _glowController.value),
                      blurRadius: 15 * _glowController.value,
                      spreadRadius: 2 * _glowController.value,
                    )
                  ],
                ),
                child: Text(
                  "${widget.currentStreak} DAYS 🔥",
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 36),
          _buildStatRow("📸 Total snaps exchanged", _totalSnaps.toString()),
          _buildStatRow("💬 Total chat messages", _totalMessages.toString()),
          _buildStatRow("😂 Total reactions", _totalReactions.toString()),
          _buildStatRow("🔥 Current streak", widget.currentStreak.toString()),
          _buildStatRow("🏆 Best streak", _bestStreak.toString()),
          const SizedBox(height: 20),
          const Icon(Icons.local_fire_department, size: 70, color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveImage,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text("Save Image", style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: const Text("Share", style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
