import 'package:flutter/material.dart';
import '../repository/ai_companion_repository.dart';
import '../models/ai_companion.dart';
import 'create_ai_companion_screen.dart';
import 'ai_chat_screen.dart';

class AiCompanionScreen extends StatefulWidget {
  const AiCompanionScreen({super.key});

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> {
  final _repository = AiCompanionRepository();
  bool _isLoading = true;
  AiCompanion? _companion;

  @override
  void initState() {
    super.initState();
    _checkCompanion();
  }

  Future<void> _checkCompanion() async {
    try {
      final companion = await _repository.getCompanion();
      if (mounted) {
        setState(() {
          _companion = companion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_companion != null) {
      return AiChatScreen(
        companion: _companion!,
        onDeleted: () {
          setState(() {
            _companion = null;
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Companion 👋')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'Meet your new AI Friend',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a companion that understands you, supports you, and is always there for you.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute<AiCompanion>(
                      builder: (context) => const CreateAiCompanionScreen(),
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _companion = result;
                    });
                  }
                },
                child: const Text('CREATE MY COMPANION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
