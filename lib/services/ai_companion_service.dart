import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/ai_companion/models/ai_companion.dart';
import '../features/ai_companion/models/ai_memory.dart';

class AiCompanionService {
  final String _functionUrl = 'https://litammrxzsndissedizt.supabase.co/functions/v1/gemini-ai-companion';
  final _supabase = Supabase.instance.client;

  Future<String> getAiResponse({
    required AiCompanion companion,
    required List<AiMemory> memories,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'message': userMessage,
          'companion': {
            'name': companion.name,
            'purpose': companion.purpose,
            'personalities': companion.personalities,
            'communication_style': companion.communicationStyle,
            'relationship_tone': companion.relationshipTone,
          },
          'memories': memories.map((m) => {
            'memory_key': m.memoryKey,
            'memory_value': m.memoryValue
          }).toList(),
          'history': history,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get AI response: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final reply = data['reply'] as String?;
      
      if (reply == null || reply.isEmpty) {
        throw Exception('Empty reply from AI');
      }

      return reply;
    } catch (e) {
      print('Error calling Gemini Edge Function: $e');
      return "Sorry 😅 My brain glitched for a second. Can you try again?";
    }
  }
}
