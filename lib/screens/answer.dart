import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question.dart';

class AnswerScreen extends StatefulWidget {
  final Question question;

  const AnswerScreen({super.key, required this.question});

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  final TextEditingController answerController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _fullQuestion;
  bool _isLoadingQuestion = false;

  @override
  void initState() {
    super.initState();
    if (widget.question.imageUrl == null || widget.question.imageUrl!.isEmpty) {
      _loadFullQuestion();
    } else {
      _fullQuestion = {
        'question_text': widget.question.text,
        'image_url': widget.question.imageUrl,
      };
    }
  }

  Future<void> _loadFullQuestion() async {
    setState(() => _isLoadingQuestion = true);
    try {
      final data = await fetchQuestionById(widget.question.id);
      if (mounted) {
        setState(() {
          _fullQuestion = data;
          _isLoadingQuestion = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading question: $e");
      if (mounted) setState(() => _isLoadingQuestion = false);
    }
  }

  Future<Map<String, dynamic>> fetchQuestionById(String id) async {
    final supabase = Supabase.instance.client;
    final data = await supabase
        .from('questions')
        .select('id, text, image_url')
        .eq('id', id)
        .single();
    
    // Remap 'text' to 'question_text' to match request requirements
    return {
      'id': data['id'],
      'question_text': data['text'],
      'image_url': data['image_url'],
    };
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  Future<void> _postAnswer() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not logged in")),
      );
      return;
    }

    if (answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an answer")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Insert answer into answers table
      await Supabase.instance.client.from('answers').insert({
        'question_id': widget.question.id,
        'user_id': user.id,
        'answer_text': answerController.text.trim(),
      });

      // 2. Mark question as answered
      final questionId = widget.question.id;
      
      await Supabase.instance.client
          .from('questions')
          .update({'answered': true})
          .eq('id', questionId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questionText = _fullQuestion?['question_text'] ?? widget.question.text;
    final imageUrl = _fullQuestion?['image_url'];
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("ANSWER"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "QUESTION",
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor),
              ),
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingQuestion)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    else ...[
                      Text(
                        questionText,
                        style: TextStyle(
                          fontWeight: FontWeight.w800, 
                          fontSize: 16,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
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
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "YOUR ANSWER",
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: answerController,
              maxLines: 6,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: "Type your answer...",
                hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                fillColor: theme.cardColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _postAnswer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("POST ANSWER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
