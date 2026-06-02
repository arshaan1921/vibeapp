import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question.dart';
import '../services/block_service.dart';
import '../main.dart';
import 'answer.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with RouteAware {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint("🔄 Returning to InboxScreen, auto-refreshing...");
    _fetchInbox();
  }

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch questions where I am the recipient ('to_user') and not answered yet
      final response = await supabase
          .from('questions')
          .select('*, answers!answers_question_id_fkey(id), profiles:from_user(username, avatar_url, premium_plan)')
          .eq('to_user', userId)
          .eq('answered', false)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response as List);
      print('INBOX ROWS = ${rawData.length}');

      if (mounted) {
        setState(() {
          _questions = rawData.where((q) {
            final fromUserId = q['from_user'];
            final isAnsweredField = q['answered'] == true || q['is_answered'] == true;
            final isDeletedField = q['is_deleted'] == true;
            final hasAnswers = (q['answers'] is List && (q['answers'] as List).isNotEmpty);
            
            return (fromUserId == null || !blockService.isBlocked(fromUserId)) && 
                   !isAnsweredField && !isDeletedField && !hasAnswers;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("INBOX", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchInbox,
              child: _questions.isEmpty
                  ? const Center(child: Text("No new questions."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _questions.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _questions[index];
                        final isAnonymous = item['is_anonymous'] ?? false;
                        final fromUser = item['profiles']?['username'] ?? "Someone";
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          title: Text(
                            item['text'] ?? "",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            isAnonymous ? 'ANONYMOUS' : '@$fromUser',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () async {
                            final question = Question(
                              id: item['id'],
                              text: item['text'] ?? "",
                              authorName: isAnonymous ? "Anonymous" : fromUser,
                              authorAvatar: "",
                              isAnonymous: isAnonymous,
                              createdAt: DateTime.parse(item['created_at']),
                              imageUrl: item['image_url'],
                            );

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnswerScreen(question: question),
                              ),
                            );
                            
                            if (result == true && mounted) {
                              setState(() {
                                // Remove immediately from UI
                                _questions.removeAt(index);
                              });
                              _fetchInbox();
                            }
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
