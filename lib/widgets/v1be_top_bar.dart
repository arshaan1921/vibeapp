import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/chat_list_screen.dart';
import '../screens/likes_activity.dart';
import '../screens/replies_activity.dart';
import '../screens/questions_screen.dart';
import '../services/chat_service.dart';

class V1BETopBar extends StatefulWidget {
  const V1BETopBar({super.key});

  @override
  State<V1BETopBar> createState() => _V1BETopBarState();
}

class _V1BETopBarState extends State<V1BETopBar> with WidgetsBindingObserver {
  int likesCount = 0;
  int questionsCount = 0;
  int answersCount = 0;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchLikeNotificationsCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromNotifications();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchLikeNotificationsCount();
    }
  }

  void _unsubscribeFromNotifications() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }

  void _subscribeToNotifications() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _unsubscribeFromNotifications();

    _notificationChannel = supabase.channel('public:notifications');

    _notificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (payload.newRecord['type'] == 'answer' && payload.newRecord['source_user'] == user.id) return;
            fetchLikeNotificationsCount();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) => fetchLikeNotificationsCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'questions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user',
            value: user.id,
          ),
          callback: (payload) => fetchLikeNotificationsCount(),
        )
        .subscribe();
  }

  Future<void> fetchLikeNotificationsCount() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final likesRes = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('type', 'like')
          .eq('seen', false);

      final answersRes = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('type', 'answer')
          .eq('seen', false)
          .neq('source_user', user.id);

      final questionsRes = await supabase
          .from('questions')
          .select('id, answers(id)')
          .eq('to_user', user.id);

      final filteredQuestions = (questionsRes as List).where((q) {
        return q['answers'] == null || (q['answers'] as List).isEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          likesCount = (likesRes as List).length;
          answersCount = (answersRes as List).length;
          questionsCount = filteredQuestions.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching counts: $e");
    }
  }

  Widget badgeIcon(IconData icon, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2C4E6E),
                  Color(0xFF3F6E9A),
                ],
              ),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    "V 1 B E",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    badgeIcon(Icons.favorite_border, likesCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LikesActivityScreen(),
                        ),
                      ).then((_) {
                        fetchLikeNotificationsCount();
                      });
                    }),
                    const SizedBox(width: 36),
                    badgeIcon(Icons.help_outline, questionsCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuestionsScreen(),
                        ),
                      ).then((_) {
                        fetchLikeNotificationsCount();
                      });
                    }),
                    const SizedBox(width: 36),
                    badgeIcon(Icons.reply_rounded, answersCount, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnswersActivityScreen(),
                        ),
                      ).then((_) {
                        fetchLikeNotificationsCount();
                      });
                    }),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: StreamBuilder<int>(
                    stream: chatService.getTotalUnreadCountStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return badgeIcon(Icons.chat_bubble_outline, count, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        ).then((_) => fetchLikeNotificationsCount());
                      });
                    }
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: Colors.black26),
        ],
      ),
    );
  }
}
