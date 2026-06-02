import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/answer.dart';
import '../widgets/answer_card.dart';
import '../services/block_service.dart';
import '../main.dart';
import '../screens/ask_any_user.dart';
import '../screens/likes_activity.dart';
import '../screens/replies_activity.dart';
import '../screens/questions_screen.dart';
import '../features/games/games_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with RouteAware, WidgetsBindingObserver {
  List<AnswerModel> _feedItems = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  
  int likesCount = 0;
  int questionsCount = 0;
  int answersCount = 0;
  RealtimeChannel? _notificationChannel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    if (mounted) {
      _loadFeedData();
      fetchNotificationCounts();
    }
  }

  static const String _answerSelectQuery = '''
    id,
    answer_text,
    created_at,
    likes_count,
    user_id,
    profiles:profiles!answers_user_id_fkey(id, username, avatar_url, premium_plan),
    questions:questions!answers_question_id_fkey(
      text,
      image_url,
      is_anonymous,
      from_user,
      asker:profiles!from_user(id, username)
    )
  ''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeedData();
    fetchNotificationCounts();
    _subscribeToRealtime();
    _subscribeToNotifications();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _realtimeChannel?.unsubscribe();
    _unsubscribeFromNotifications();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchNotificationCounts();
    }
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _feedItems = _feedItems.where((item) => !blockService.isBlocked(item.userId)).toList();
      });
    }
  }

  Future<void> _loadFeedData() async {
    await blockService.refreshBlockedList();
    await _fetchFeed();
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
    _notificationChannel = supabase.channel('public:notifications_feed');

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
            fetchNotificationCounts();
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
          callback: (payload) => fetchNotificationCounts(),
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
          callback: (payload) => fetchNotificationCounts(),
        )
        .subscribe();
  }

  Future<void> fetchNotificationCounts() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final likesRes = await supabase.from('notifications').select('id').eq('user_id', user.id).eq('type', 'like').eq('seen', false);
      final answersRes = await supabase.from('notifications').select('id').eq('user_id', user.id).eq('type', 'answer').eq('seen', false).neq('source_user', user.id);
      
      // Fetch unanswered questions for the badge
      final questionsRes = await supabase
          .from('questions')
          .select('answered, is_answered, from_user, answers!answers_question_id_fkey(id)')
          .eq('to_user', user.id)
          .eq('answered', false);

      final List<dynamic> questionsList = questionsRes as List;
      
      final filteredQuestions = questionsList.where((q) {
        final isAnsweredField = q['answered'] == true || q['is_answered'] == true;
        final hasAnswers = (q['answers'] is List && (q['answers'] as List).isNotEmpty);
        final fromUserId = q['from_user'];
        final isBlocked = fromUserId != null && blockService.isBlocked(fromUserId);
        
        return !isAnsweredField && !hasAnswers && !isBlocked;
      }).toList();

      if (mounted) {
        setState(() {
          likesCount = (likesRes as List).length;
          answersCount = (answersRes as List).length;
          questionsCount = filteredQuestions.length;
        });
      }
    } catch (e, st) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _subscribeToRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    _realtimeChannel = supabase.channel('feed_realtime');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'answers',
      callback: (payload) async {
        if (payload.eventType == PostgresChangeEvent.insert) {
          try {
            final data = await supabase.from('answers').select(_answerSelectQuery).eq('id', payload.newRecord['id']).single();
            if (mounted) {
              final newAnswer = AnswerModel.fromMap(data);
              if (blockService.isBlocked(newAnswer.userId)) return;

              setState(() {
                _feedItems.removeWhere((item) => item.id == newAnswer.id);
                _feedItems.insert(0, newAnswer);
              });
            }
          } catch (e, st) {
            debugPrint('ERROR: $e');
            debugPrintStack(stackTrace: st);
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          if (mounted) {
            setState(() {
              final index = _feedItems.indexWhere((item) => item.id == payload.newRecord['id'].toString());
              if (index != -1) {
                _feedItems[index] = _feedItems[index].copyWith(
                  likeCount: payload.newRecord['likes_count'],
                );
              }
            });
          }
        }
      },
    );

    if (user != null) {
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'answer_likes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final answerId = (payload.eventType == PostgresChangeEvent.delete 
              ? payload.oldRecord['answer_id'] 
              : payload.newRecord['answer_id']).toString();
          
          if (mounted) {
            setState(() {
              final index = _feedItems.indexWhere((item) => item.id == answerId);
              if (index != -1) {
                _feedItems[index] = _feedItems[index].copyWith(
                  isLiked: payload.eventType != PostgresChangeEvent.delete,
                );
              }
            });
          }
        },
      );
    }

    _realtimeChannel!.subscribe();
  }

  void _sortFeed() {
    _feedItems.sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> _fetchFeed() async {
    print('FEED_TRACE: START');
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final currentUserId = user?.id;
      
      print('FEED_TRACE: Querying Supabase...');
      final response = await supabase
          .from('answers')
          .select(_answerSelectQuery)
          .order('created_at', ascending: false);
          
      final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response as List);
      print('FEED_TRACE: ROWS = ${rawData.length}');
      
      Set<String> likedIds = {};
      if (user != null) {
        final likesRes = await supabase.from('answer_likes').select('answer_id').eq('user_id', user.id);
        likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
      }

      if (mounted) {
        setState(() {
          try {
            int ownCount = 0;
            _feedItems = rawData.map((map) {
              final model = AnswerModel.fromMap(map, isLiked: likedIds.contains(map['id'].toString()));
              if (model.userId == currentUserId) ownCount++;
              return model;
            })
            .where((item) => !blockService.isBlocked(item.userId))
            .toList();
            
            print('FEED ANSWERS = ${_feedItems.length}');
          } catch (e, st) {
            print('FEED_TRACE: PARSE ERROR: $e');
            print(st);
          }
          _sortFeed();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      print('FEED_TRACE: GLOBAL ERROR: $e');
      print(st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAnswer(String answerId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('answers').delete().eq('id', answerId);
      
      if (mounted) {
        setState(() {
          _feedItems.removeWhere((item) => item.id == answerId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answer deleted")),
        );
      }
    } catch (e, st) {
      debugPrint('ERROR deleting answer from feed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete answer")),
        );
      }
    }
  }

  Widget _buildBadgeIcon(IconData icon, int count, VoidCallback onTap, {Color? color}) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 26, color: color ?? theme.colorScheme.onSurface),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
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
    debugPrint("FEED_BUILD: items=${_feedItems.length}, isLoading=$_isLoading");
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadFeedData,
          displacement: 40,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                centerTitle: false,
                elevation: 0,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                title: RichText(
                  text: TextSpan(
                    style: theme.appBarTheme.titleTextStyle?.copyWith(
                      fontSize: 22,
                    ),
                    children: [
                      TextSpan(
                        text: "High",
                        style: TextStyle(color: isDark ? Colors.greenAccent : theme.colorScheme.primary),
                      ),
                      TextSpan(
                        text: "5", 
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                actions: [
                  _buildBadgeIcon(Icons.favorite_border_rounded, likesCount, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LikesActivityScreen())).then((_) => fetchNotificationCounts());
                  }),
                  _buildBadgeIcon(Icons.help_outline_rounded, questionsCount, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionsScreen())).then((_) => fetchNotificationCounts());
                  }),
                  _buildBadgeIcon(Icons.reply_rounded, answersCount, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnswersActivityScreen())).then((_) => fetchNotificationCounts());
                  }),
                  IconButton(
                    icon: Icon(Icons.sports_esports_rounded, size: 26, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesScreen())),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, size: 26, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskAnyUserScreen())),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_feedItems.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text("No answers yet.")),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                        final bool isMe = _feedItems[index].userId == currentUserId;
                        
                        return AnswerCard(
                          key: ValueKey(_feedItems[index].id),
                          answer: _feedItems[index],
                          onDelete: isMe ? (id) => _deleteAnswer(id) : null,
                          onLikeChanged: () {
                            if (mounted) {
                              setState(() {
                                final current = _feedItems[index];
                                _feedItems[index] = current.copyWith(
                                  isLiked: !current.isLiked,
                                  likeCount: current.isLiked 
                                      ? current.likeCount - 1 
                                      : current.likeCount + 1,
                                );
                              });
                            }
                          },
                        );
                      },
                      childCount: _feedItems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
