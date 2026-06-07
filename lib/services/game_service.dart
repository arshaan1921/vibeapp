import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameService {
  final _supabase = Supabase.instance.client;

  Future<int> getUnvotedGamesCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    int totalCount = 0;

    // 1. Most Likely To
    try {
      final mlResponse = await _supabase
          .from('most_likely_participants')
          .select('user_id, most_likely_games!inner(status)')
          .eq('user_id', userId)
          .eq('most_likely_games.status', 'active')
          .not('is_seen', 'eq', true);
      int mlCount = (mlResponse as List).length;
      totalCount += mlCount;
    } catch (e) {
      debugPrint('BADGE_DEBUG: Most Likely Error = $e');
    }

    // 2. Two Truths & One Lie
    try {
      final tlResponse = await _supabase
          .from('truth_lie_participants')
          .select('user_id, truth_lie_games!inner(status)')
          .eq('user_id', userId)
          .eq('truth_lie_games.status', 'active')
          .not('is_seen', 'eq', true);
      int tlCount = (tlResponse as List).length;
      totalCount += tlCount;
    } catch (e) {
      debugPrint('BADGE_DEBUG: Truth Lie Error = $e');
    }

    // 3. Meme Mania
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final memeResponse = await _supabase
          .from('meme_participants')
          .select('user_id, meme_games!inner(is_active, expires_at)')
          .eq('user_id', userId)
          .eq('meme_games.is_active', true)
          .gt('meme_games.expires_at', now)
          .not('is_seen', 'eq', true);

      int memeCount = (memeResponse as List).length;
      totalCount += memeCount;
    } catch (e) {
      debugPrint('BADGE_DEBUG: Meme Mania Error = $e');
    }

    return totalCount;
  }
}
