import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/answer.dart';
import '../widgets/v1be_top_bar.dart';
import '../widgets/answer_card.dart';
import '../services/block_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<AnswerModel> _feedItems = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

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
    _loadFeedData();
    _subscribeToRealtime();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
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
              // Filter out if blocked
              if (blockService.isBlocked(newAnswer.userId)) return;

              setState(() {
                _feedItems.removeWhere((item) => item.id == newAnswer.id);
                _feedItems.insert(0, newAnswer);
              });
            }
          } catch (_) {}
        } else if (payload.eventType == PostgresChangeEvent.update) {
          if (mounted) {
            setState(() {
              final index = _feedItems.indexWhere((item) => item.id == payload.newRecord['id'].toString());
              if (index != -1) {
                // Keep the current isLiked state from the model to avoid overwriting optimistic state
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

      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'blocked_users',
        callback: (payload) {
          blockService.refreshBlockedList();
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
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      final response = await supabase
          .from('answers')
          .select(_answerSelectQuery)
          .order('created_at', ascending: false);
          
      List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
      
      Set<String> likedIds = {};
      if (user != null) {
        final likesRes = await supabase.from('answer_likes').select('answer_id').eq('user_id', user.id);
        likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
      }

      if (mounted) {
        setState(() {
          _feedItems = rawData
              .map((map) => AnswerModel.fromMap(map, isLiked: likedIds.contains(map['id'].toString())))
              .where((item) => !blockService.isBlocked(item.userId))
              .toList();
          _sortFeed();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const V1BETopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFeedData,
                    child: _feedItems.isEmpty
                        ? const Center(child: Text("No answers yet."))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _feedItems.length,
                            itemBuilder: (context, index) {
                              return AnswerCard(
                                key: ValueKey(_feedItems[index].id),
                                answer: _feedItems[index],
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
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
