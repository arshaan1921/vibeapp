import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_companion.dart';
import '../models/ai_message.dart';
import '../models/ai_memory.dart';

class GeminiAiService {
  final _supabase = Supabase.instance.client;

  Future<String> getAiResponse({
    required AiCompanion companion,
    required List<AiMessage> history,
    required List<AiMemory> memories,
    required String userMessage,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await _supabase.functions.invoke(
        'gemini-ai-companion',
        body: {
          'companion': {
            'name': companion.name,
            'purpose': companion.purpose,
            'personalities': companion.personalities,
            'communication_style': companion.communicationStyle,
            'relationship_tone': companion.relationshipTone,
          },
          'memories': memories.map((m) => {'key': m.memoryKey, 'value': m.memoryValue}).toList(),
          'history': history.map((m) => {'sender': m.sender, 'message': m.message}).toList(),
          'userMessage': userMessage,
        },
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status != 200) {
        throw Exception('Failed to get AI response: ${response.data}');
      }

      final data = response.data;
      return data['reply'] ?? 'Something went wrong. Please try again.';
    } catch (e) {
      print('Error calling Gemini Edge Function: $e');
      return 'I am having trouble connecting right now. Let\'s talk in a bit! ❤️';
    }
  }
}
