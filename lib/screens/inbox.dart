import 'package:flutter/material.dart';
import '../models/question.dart';
import 'answer.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("INBOX")),
      body: ListView.separated(
        itemCount: mockInboxQuestions.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final question = mockInboxQuestions[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage: question.isAnonymous ? null : NetworkImage(question.authorAvatar),
              child: question.isAnonymous ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
            ),
            title: Text(question.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(question.isAnonymous ? 'ANONYMOUS' : question.authorName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AnswerScreen(question: question)));
            },
          );
        },
      ),
    );
  }
}
