import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnswerQuestionScreen extends StatefulWidget {
  final String questionId;
  final String toUserId;

  const AnswerQuestionScreen({
    super.key,
    required this.questionId,
    required this.toUserId,
  });

  @override
  State<AnswerQuestionScreen> createState() => _AnswerQuestionScreenState();
}

class _AnswerQuestionScreenState extends State<AnswerQuestionScreen> {
  final TextEditingController answerController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  Future<void> _sendAnswer() async {
    final text = answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an answer")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Step 3: Insert answer into "answers" table
      await supabase.from('answers').insert({
        'question_id': widget.questionId,
        'user_id': currentUser.id,
        'answer_text': text,
      });

      // Step: Fetch the question owner (receiver) from "questions" table
      final questionData = await supabase
          .from('questions')
          .select('to_user')
          .eq('id', widget.questionId)
          .single();
      final questionOwnerId = questionData['to_user'];

      // Step 4: Fetch current user's username from "profiles"
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', currentUser.id)
          .single();
      final username = profile['username'] ?? "Someone";

      // Step 5: Send push notification using same method as question push
      try {
        final session = supabase.auth.currentSession;
        final accessToken = session?.accessToken;

        if (accessToken != null && questionOwnerId != null) {
          await supabase.functions.invoke(
            'supabase-functions-new-send-push-notification',
            body: {
              "user_id": questionOwnerId,
              "title": "New Answer 💬",
              "body": "@$username answered your question",
              "data": {
                "type": "answer",
                "question_id": widget.questionId
              }
            },
            headers: {
              "Authorization": "Bearer $accessToken",
            },
          );
        }
      } catch (e) {
        debugPrint("Push failed: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answer sent")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("ANSWER QUESTION"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your Answer",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                maxLines: 5,
                style: TextStyle(color: textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Type your answer here...",
                  hintStyle: TextStyle(color: textTheme.bodySmall?.color),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendAnswer,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "SEND ANSWER",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
