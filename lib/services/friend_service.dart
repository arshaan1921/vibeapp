import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class FriendService {
  final _supabase = Supabase.instance.client;

  Future<void> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // 1. Insert into friend_requests table
    await _supabase.from('friend_requests').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });

    // 2. Send push notification
    try {
      // Fetch sender username from profiles table
      final profileRes = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      
      final username = profileRes?['username'] ?? "Someone";

      // Send push notification to receiver using NotificationService
      await NotificationService.sendNotification(
        userId: receiverId,
        title: "Friend Request",
        body: "$username sent you a friend request",
        data: {
          "type": "friend_request",
          "sender_id": user.id,
        },
      );
      debugPrint("✅ Friend request notification sent to $receiverId");
    } catch (e) {
      debugPrint("⚠️ Friend request notification failed: $e");
      // Notification failure shouldn't affect the friend request itself
    }
  }

  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // 1. Update request status
    await _supabase.from('friend_requests').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    // 2. Add to friends table
    await _supabase.from('friends').insert({
      'user1_id': senderId.compareTo(user.id) < 0 ? senderId : user.id,
      'user2_id': senderId.compareTo(user.id) < 0 ? user.id : senderId,
    });

    // 3. Send push notification
    try {
      // Fetch current user's username
      final profileRes = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      
      final username = profileRes?['username'] ?? "Someone";

      // Send notification to the person who sent the request (senderId)
      await NotificationService.sendNotification(
        userId: senderId,
        title: "Friend Request Accepted",
        body: "$username accepted your friend request",
        data: {
          "type": "friend_accepted",
          "friend_id": user.id,
        },
      );
      debugPrint("✅ Friend acceptance notification sent to $senderId");
    } catch (e) {
      debugPrint("⚠️ Friend acceptance notification failed: $e");
      // Notification failure shouldn't affect the friendship itself
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _supabase.from('friend_requests').update({
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> blockUser(String requestId) async {
    await _supabase.from('friend_requests').update({
      'status': 'blocked',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> unfriend(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final u1 = user.id.compareTo(otherUserId) < 0 ? user.id : otherUserId;
    final u2 = user.id.compareTo(otherUserId) < 0 ? otherUserId : user.id;

    try {
      debugPrint('FRIEND_AUDIT: Unfriending: Me=${user.id}, Them=$otherUserId');
      debugPrint('FRIEND_AUDIT: Target row: user1=$u1, user2=$u2');
      
      // 1. Fetch the friendship row ID first to be absolutely sure what we are deleting
      final existingFriend = await _supabase
          .from('friends')
          .select('id')
          .eq('user1_id', u1)
          .eq('user2_id', u2)
          .maybeSingle();
      
      if (existingFriend != null) {
        final rowId = existingFriend['id'];
        debugPrint('FRIEND_AUDIT: Found friendship row to delete: $rowId');
        
        final deleteRes = await _supabase
            .from('friends')
            .delete()
            .eq('id', rowId)
            .select();
        
        debugPrint('FRIEND_AUDIT: Delete by ID result: $deleteRes');
      } else {
        debugPrint('FRIEND_AUDIT: No row found in friends table to delete.');
      }

      // 2. Delete matching friend requests
      final requestDeleteRes = await _supabase
          .from('friend_requests')
          .delete()
          .or('and(sender_id.eq.${user.id},receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.${user.id})')
          .select();
      
      debugPrint('FRIEND_AUDIT: Delete requests result: $requestDeleteRes');
    } catch (e) {
      debugPrint('FRIEND_SERVICE_ERROR: unfriend fail: $e');
      rethrow;
    }
  }

  Future<String?> getFriendshipStatus(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Check if friends
      final u1 = user.id.compareTo(otherUserId) < 0 ? user.id : otherUserId;
      final u2 = user.id.compareTo(otherUserId) < 0 ? otherUserId : user.id;
      
      final friendRes = await _supabase
          .from('friends')
          .select()
          .eq('user1_id', u1)
          .eq('user2_id', u2)
          .maybeSingle();
      
      debugPrint('FRIEND_AUDIT: friendRes for $u1, $u2 = $friendRes');
      
      if (friendRes != null) {
        debugPrint('FRIEND_AUDIT: $otherUserId status = friends');
        return 'friends';
      }

      // 2. Check friend requests (most recent first)
      final requestRes = await _supabase
          .from('friend_requests')
          .select()
          .or('and(sender_id.eq.${user.id},receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.${user.id})')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (requestRes == null) {
        debugPrint('FRIEND_AUDIT: $otherUserId status = none');
        return 'none';
      }
      
      final status = requestRes['status'];
      
      // IMPORTANT: If we found an 'accepted' request but NO row in friends table,
      // it means they were unfriended. We should treat this as 'none'.
      if (status == 'accepted') {
        debugPrint('FRIEND_AUDIT: Found accepted request but no friends row. Returning none.');
        return 'none';
      }

      if (status == 'pending') {
        final result = requestRes['sender_id'] == user.id ? 'pending_sent' : 'pending_received';
        debugPrint('FRIEND_AUDIT: $otherUserId status = $result');
        return result;
      }
      
      debugPrint('FRIEND_AUDIT: $otherUserId status = $status');
      return status;
    } catch (e) {
      debugPrint('FRIEND_SERVICE_ERROR: getFriendshipStatus fail: $e');
      return 'none';
    }
  }

  Future<int> getFriendsCount(String userId) async {
    try {
      final res = await _supabase
          .from('friends')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');
      
      return (res as List).length;
    } catch (e) {
      debugPrint('FRIEND_SERVICE_ERROR: getFriendsCount fail: $e');
      return 0;
    }
  }

  Future<int> getMutualFriendsCount(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final myFriendsRes = await _supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');
      
      final otherFriendsRes = await _supabase
          .from('friends')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$otherUserId,user2_id.eq.$otherUserId');

      final myFriends = (myFriendsRes as List).map((f) => f['user1_id'] == user.id ? f['user2_id'] : f['user1_id']).toSet();
      final otherFriends = (otherFriendsRes as List).map((f) => f['user1_id'] == otherUserId ? f['user2_id'] : f['user1_id']).toSet();

      final count = myFriends.intersection(otherFriends).length;
      debugPrint('FRIEND_AUDIT: Mutual friends with $otherUserId = $count');
      return count;
    } catch (e) {
      debugPrint('FRIEND_SERVICE_ERROR: getMutualFriendsCount fail: $e');
      return 0;
    }
  }

  Future<void> migrateFromFollows() async {
    final supabase = Supabase.instance.client;
    
    // 1. Fetch all follows
    final allFollowsRes = await supabase.from('saved_profiles').select('user_id, saved_user_id');
    final List<dynamic> follows = allFollowsRes as List;
    
    final Map<String, Set<String>> followMap = {};
    for (var f in follows) {
      final u = f['user_id'] as String;
      final s = f['saved_user_id'] as String;
      followMap.putIfAbsent(u, () => {}).add(s);
    }
    
    final Set<String> processedPairs = {};
    
    for (var f in follows) {
      final u1 = f['user_id'] as String;
      final u2 = f['saved_user_id'] as String;
      
      final pair = u1.compareTo(u2) < 0 ? '${u1}_$u2' : '${u2}_$u1';
      if (processedPairs.contains(pair)) continue;
      processedPairs.add(pair);
      
      final u1FollowsU2 = followMap[u1]?.contains(u2) ?? false;
      final u2FollowsU1 = followMap[u2]?.contains(u1) ?? false;
      
      if (u1FollowsU2 && u2FollowsU1) {
        // Mutual -> Friends
        await supabase.from('friends').upsert({
          'user1_id': u1.compareTo(u2) < 0 ? u1 : u2,
          'user2_id': u1.compareTo(u2) < 0 ? u2 : u1,
        });
      } else if (u1FollowsU2) {
        // One way -> Pending request from u1 to u2
        await supabase.from('friend_requests').upsert({
          'sender_id': u1,
          'receiver_id': u2,
          'status': 'pending',
        });
      } else if (u2FollowsU1) {
        // One way -> Pending request from u2 to u1
        await supabase.from('friend_requests').upsert({
          'sender_id': u2,
          'receiver_id': u1,
          'status': 'pending',
        });
      }
    }
  }
}

final friendService = FriendService();
