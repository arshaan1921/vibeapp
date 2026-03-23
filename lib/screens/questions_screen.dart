import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'answer.dart';
import '../models/question.dart';
import '../services/block_service.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    blockService.blockedIdsNotifier.addListener(_onBlocksChanged);
  }

  @override
  void dispose() {
    blockService.blockedIdsNotifier.removeListener(_onBlocksChanged);
    super.dispose();
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
    await blockService.refreshBlockedList();
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      final response = await supabase
          .from('questions')
          .select('id, text, image_url, from_user, is_anonymous, created_at, profiles:from_user(username)')
          .eq('to_user', currentUser.id)
          .eq('answered', false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          // Filter out questions from blocked users
          _questions = List<Map<String, dynamic>>.from(response).where((q) {
            final fromUserId = q['from_user'];
            return fromUserId == null || !blockService.isBlocked(fromUserId);
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching questions: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteQuestion(String id) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;

      await supabase
          .from('questions')
          .delete()
          .match({
            'id': id,
            'to_user': userId,
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Question deleted"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting question: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete question")),
        );
      }
      _fetchQuestions();
    }
  }

  Future<bool> _confirmDeleteDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Delete Question"),
          content: const Text("Are you sure you want to delete this question? This cannot be undone."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("INBOX", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _questions.isEmpty
                  ? const _EmptyState(
                      icon: Icons.help_outline_rounded,
                      message: "No questions yet.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final item = _questions[index];
                        final id = item['id'].toString();
                        final isAnonymous = item['is_anonymous'] ?? false;
                        final fromUser = item['profiles']?['username'] ?? "Unknown";
                        final senderText = isAnonymous ? "Anonymous" : "From: @$fromUser";
                        final imageUrl = item['image_url'];

                        return Dismissible(
                          key: Key(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                            ),
                            child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) {
                            setState(() {
                              _questions.removeAt(index);
                            });
                            _deleteQuestion(id);
                          },
                          confirmDismiss: (direction) => _confirmDeleteDialog(),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final questionModel = Question(
                                  id: item['id'],
                                  text: item['text'] ?? "",
                                  authorName: senderText,
                                  authorAvatar: "",
                                  isAnonymous: isAnonymous,
                                  createdAt: DateTime.parse(item['created_at']),
                                  imageUrl: imageUrl,
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnswerScreen(
                                      question: questionModel,
                                    ),
                                  ),
                                ).then((_) => _loadData());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['text'] ?? "",
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                          if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                imageUrl,
                                                width: double.infinity,
                                                height: 160,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    height: 160,
                                                    color: Colors.black12,
                                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 100,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            senderText,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                          onPressed: () async {
                                            final confirmed = await _confirmDeleteDialog();
                                            if (confirmed) {
                                              setState(() {
                                                _questions.removeAt(index);
                                              });
                                              _deleteQuestion(id);
                                            }
                                          },
                                          tooltip: "Delete question",
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
