import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/story.dart';

class StoryService {
  final _supabase = Supabase.instance.client;

  Future<List<UserStories>> fetchStories() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final now = DateTime.now().toUtc().toIso8601String();
    
    try {
      // 1. Fetch saved profile IDs
      final savedRes = await _supabase
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', currentUserId);
      
      final List<String> savedUserIds = (savedRes as List)
          .map((item) => item['saved_user_id'].toString())
          .toList();

      if (!savedUserIds.contains(currentUserId)) {
        savedUserIds.add(currentUserId);
      }

      // 2. Fetch stories with seen status
      // We use a left join and filter the joined story_views by the current viewer
      final response = await _supabase
          .from('stories')
          .select('''
            *,
            profiles:user_id(id, username, avatar_url),
            story_views!left(id, viewer_id)
          ''')
          .eq('story_views.viewer_id', currentUserId)
          .gt('expires_at', now)
          .inFilter('user_id', savedUserIds)
          .order('created_at', ascending: true);

      final List<dynamic> storiesData = response;
      final Map<String, UserStories> userStoriesMap = {};
      
      for (var item in storiesData) {
        final userId = item['user_id'];
        final profile = item['profiles'];
        
        final story = StoryModel.fromMap(item);
        
        if (!userStoriesMap.containsKey(userId)) {
          userStoriesMap[userId] = UserStories(
            userId: userId,
            username: profile?['username'] ?? 'User',
            avatarUrl: profile?['avatar_url'],
            stories: [],
          );
        }
        
        userStoriesMap[userId]!.stories.add(story);
      }

      final userStoriesList = userStoriesMap.values.toList();
      for (var us in userStoriesList) {
        // Count how many stories have at least one view entry for the current user
        int viewedCount = 0;
        for (var story in us.stories) {
          final originalItem = storiesData.firstWhere((item) => item['id'].toString() == story.id);
          final views = originalItem['story_views'] as List?;
          if (views != null && views.isNotEmpty) {
            viewedCount++;
          }
        }
        
        final totalCount = us.stories.length;
        us.allSeen = totalCount > 0 && viewedCount == totalCount;
        
        if (kDebugMode) {
          print('Story Sync [${us.username}]: $viewedCount/$totalCount seen. allSeen: ${us.allSeen}');
        }
      }

      userStoriesList.sort((a, b) {
        if (a.userId == currentUserId) return -1;
        if (b.userId == currentUserId) return 1;
        if (a.allSeen != b.allSeen) return a.allSeen ? 1 : -1;
        final aLatest = a.stories.last.createdAt;
        final bLatest = b.stories.last.createdAt;
        return bLatest.compareTo(aLatest);
      });

      return userStoriesList;
    } catch (e) {
      if (kDebugMode) print('Story fetch error: $e');
      return [];
    }
  }

  Future<void> markStoryAsSeen(String storyId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      // First, check if the view already exists to avoid duplicates and 'ON CONFLICT' errors
      final existing = await _supabase
          .from('story_views')
          .select('id')
          .eq('story_id', storyId)
          .eq('viewer_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Insert only if it doesn't exist
        await _supabase.from('story_views').insert({
          'story_id': storyId,
          'viewer_id': userId,
        });
        if (kDebugMode) print('Story $storyId marked seen by $userId');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to mark story as seen: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchStoryViewers(String storyId) async {
    try {
      final response = await _supabase
          .from('story_views')
          .select('''
            created_at,
            profiles:viewer_id(id, username, avatar_url)
          ''')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching viewers: $e');
      return [];
    }
  }

  Future<void> deleteStory(String storyId, String mediaUrl) async {
    try {
      await _supabase.from('stories').delete().eq('id', storyId);
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 7) {
        final storagePath = pathSegments.sublist(pathSegments.indexOf('stories') + 1).join('/');
        await _supabase.storage.from('stories').remove([storagePath]);
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting story: $e');
      rethrow;
    }
  }

  Future<void> likeStory(String storyId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('story_likes').upsert({
        'story_id': storyId,
        'user_id': userId,
      }, onConflict: 'story_id,user_id');
    } catch (e) {
      if (kDebugMode) print('Error liking story: $e');
    }
  }

  Future<void> uploadStory(File file, StoryMediaType type, {String? caption}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final String userId = user.id;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final path = 'stories/$userId/$fileName';
    
    try {
      await _supabase.storage.from('stories').upload(path, file);
      final mediaUrl = _supabase.storage.from('stories').getPublicUrl(path);

      await _supabase.from('stories').insert({
        'user_id': userId,
        'media_url': mediaUrl,
        'media_type': type == StoryMediaType.video ? 'video' : 'image',
        'caption': caption,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('Story upload error: ${e.toString()}');
      rethrow;
    }
  }
}

final storyService = StoryService();
