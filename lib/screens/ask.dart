import 'package:flutter/material.dart';

class AskScreen extends StatelessWidget {
  const AskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("ASK A QUESTION")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TYPE YOUR QUESTION",
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 5,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                fillColor: theme.cardColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  "ASK ANONYMOUSLY",
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: true, 
                  onChanged: (v) {}, 
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("SEND QUESTION"),
            ),
          ],
        ),
      ),
    );
  }
}
