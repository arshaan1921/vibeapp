import 'package:flutter/material.dart';
import '../models/question.dart';
import '../utils/image_utils.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback? onTap;

  const QuestionCard({
    super.key,
    required this.question,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: question.isAnonymous 
              ? null 
              : ImageUtils.getImageProvider(question.authorAvatar),
          child: (question.isAnonymous || ImageUtils.safeUrl(question.authorAvatar) == null) 
              ? Icon(question.isAnonymous ? Icons.visibility_off_outlined : Icons.person) 
              : null,
        ),
        title: Text(
          question.text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            question.isAnonymous ? 'Asked anonymously' : 'Asked by ${question.authorName}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }
}
