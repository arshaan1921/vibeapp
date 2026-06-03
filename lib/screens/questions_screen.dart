import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'answer.dart';
import '../models/question.dart';
import '../services/block_service.dart';
import '../services/realtime_service.dart';
import '../main.dart';
import '../utils/premium_utils.dart';
import '../utils/image_utils.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> with RouteAware {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
    
    // Listen for realtime updates to refresh inbox
    _realtimeSubscription = RealtimeService().events.listen((event) {
      if (event == 'refresh_inbox') {
        _fetchQuestions();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _onBlocksChanged() {
    if (mounted) {
      setState(() {
        _questions = _questions.where((q) {
          final fromUserId = q['from_user'];
          return fromUserId == null || !blockService.isBlocked(fromUserId);
        }).toList();
      });
    }
  }

  Future<void> _loadData() async {
    debugPrint("QUESTIONS: _loadData called");
    await blockService.refreshBlockedList();
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    print('QUESTIONS: _fetchQuestions STARTED');
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Robust query with NO CACHING logic
      final response = await supabase
          .from('questions')
          .select('*, answers!answers_question_id_fkey(id), profiles:profiles!from_user(username, avatar_url, premium_plan)')
          .eq('to_user', userId)
          .eq('answered', false)
          .eq('is_deleted', false); // Only show non-deleted/non-archived questions

      final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response as List);
      
      // FALLBACK: Filter locally just in case Supabase filter was bypassed/cached
      final unansweredQuestions = rawData.where((q) {
        final isAnsweredField = q['answered'] == true || q['is_answered'] == true;
        final isDeletedField = q['is_deleted'] == true;
        final hasAnswers = (q['answers'] is List && (q['answers'] as List).isNotEmpty);
        
        final fromUserId = q['from_user'];
        final isBlocked = fromUserId != null && blockService.isBlocked(fromUserId);
        
        return !isAnsweredField && !isDeletedField && !hasAnswers && !isBlocked;
      }).toList();

      print('INBOX DATA: Received ${rawData.length} rows, Filtered to ${unansweredQuestions.length}');

      if (mounted) {
        setState(() {
          _questions = unansweredQuestions;
          _questions.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          _isLoading = false;
        });
      }
    } catch (e, st) {
      print('ERROR: $e');
      print(st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion(String id) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('questions').delete().match({'id': id, 'to_user': supabase.auth.currentUser!.id});
    } catch (e, st) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("QUESTIONS_BUILD: items=${_questions.length}, loading=$_isLoading");
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Questions", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: _questions.isEmpty
                    ? const Center(child: Text("No new questions yet."))
                    : ListView.builder(
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final item = _questions[index];
                          final id = item['id'].toString();
                          final isAnonymous = item['is_anonymous'] ?? false;
                          
                          var profileData = item['profiles'];
                          Map<String, dynamic>? profile;
                          if (profileData is List && profileData.isNotEmpty) {
                            profile = profileData.first;
                          } else if (profileData is Map<String, dynamic>) {
                            profile = profileData;
                          }

                          final fromUser = profile?['username'] ?? "Unknown";
                          final plan = profile?['premium_plan'];
                          final senderText = isAnonymous ? "Anonymous" : "@$fromUser";
                          final imageUrl = item['image_url'];

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              color: Colors.redAccent,
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              final qId = id;
                              setState(() {
                                _questions.removeAt(index);
                              });
                              _deleteQuestion(qId);
                            },
                            child: InkWell(
                              onTap: () {
                              final questionModel = Question(
                                id: item['id'].toString(),
                                text: item['text'] ?? "",
                                authorName: senderText,
                                authorAvatar: profile?['avatar_url'] ?? "",
                                isAnonymous: isAnonymous,
                                createdAt: DateTime.parse(item['created_at']),
                                imageUrl: imageUrl,
                              );
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => AnswerScreen(question: questionModel))
                              ).then((result) {
                                if (result == true && mounted) {
                                  setState(() {
                                    // Remove the question from the local list immediately
                                    _questions.removeAt(index);
                                  });
                                }
                                _loadData(); // Re-sync with DB
                              });
                            },
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isAnonymous && profile != null)
                                          GestureDetector(
                                            onTap: () => ImageUtils.showImagePreview(context, profile!['avatar_url']),
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              padding: const EdgeInsets.all(1.5),
                                              decoration: PremiumUtils.buildProfileRing(plan, width: 1.5),
                                              child: CircleAvatar(
                                                radius: 18,
                                                backgroundImage: ImageUtils.getImageProvider(profile['avatar_url']),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            margin: const EdgeInsets.only(right: 12),
                                            child: const CircleAvatar(
                                              radius: 18,
                                              child: Icon(Icons.person, size: 20),
                                            ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      senderText,
                                                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!isAnonymous) ...[
                                                    const SizedBox(width: 4),
                                                    PremiumUtils.buildBadge(plan),
                                                    if (profile?['is_verified'] == true) 
                                                      const Icon(Icons.verified_rounded, color: Colors.blue, size: 12),
                                                    if (profile?['is_founder'] == true)
                                                      const Icon(Icons.star_rounded, color: Colors.orange, size: 12),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item['text'] ?? "",
                                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                                              ),
                                              if (imageUrl != null) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.image_rounded, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text("Image attached", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 0.5, indent: 68),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
