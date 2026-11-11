import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_user_item.dart';

class AdminUserRepository {
  final SupabaseClient _supabase;

  AdminUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetches paginated user list from `profiles` using actual database columns
  Future<List<AdminUserItem>> fetchUsers({
    required String filter, // 'all', 'active', 'suspended', 'shadow_banned'
    required String sort, // 'newest', 'oldest', 'username_az'
    String searchQuery = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      dynamic query = _supabase.from('profiles').select('*');

      // Apply Filters using confirmed schema columns: is_banned, is_shadow_banned
      if (filter == 'suspended') {
        query = query.eq('is_banned', true);
      } else if (filter == 'shadow_banned') {
        query = query.eq('is_shadow_banned', true);
      } else if (filter == 'active') {
        query = query.or('is_banned.is.null,is_banned.eq.false');
      }

      // Apply Search
      final search = searchQuery.trim();
      if (search.isNotEmpty) {
        final isUuid = RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(search);
        if (isUuid) {
          query = query.eq('id', search);
        } else {
          query = query.or('username.ilike.%$search%,name.ilike.%$search%');
        }
      }

      // Apply Sorting
      if (sort == 'oldest') {
        query = query.order('created_at', ascending: true);
      } else if (sort == 'username_az') {
        query = query.order('username', ascending: true);
      } else {
        query = query.order('created_at', ascending: false);
      }

      // Apply Pagination
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      query = query.range(from, to);

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      return data
          .map((map) => AdminUserItem.fromMap(map as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminUserRepository PostgrestException: ${e.message} (Code: ${e.code})');
      throw Exception(
          'Database query error. Please ensure SQL migration is applied.');
    } catch (e) {
      debugPrint('AdminUserRepository error fetching users: $e');
      throw Exception(
          'Unable to load user directory. Please check network connection.');
    }
  }

  /// Fetches user statistics concurrently in a single parallel batch
  Future<UserDetailStats> fetchUserStats(String userId) async {
    int answers = 0;
    int questions = 0;
    int snaps = 0;
    int reports = 0;

    try {
      final results = await Future.wait<dynamic>([
        _supabase.from('answers').select('id').eq('user_id', userId),
        _supabase
            .from('questions')
            .select('id')
            .or('from_user.eq.$userId,to_user.eq.$userId'),
        _supabase.from('snaps').select('id').eq('sender_id', userId),
        _supabase.from('reports').select('id').eq('reported_user_id', userId),
      ]);

      if (results[0] is List) answers = (results[0] as List).length;
      if (results[1] is List) questions = (results[1] as List).length;
      if (results[2] is List) snaps = (results[2] as List).length;
      if (results[3] is List) reports = (results[3] as List).length;
    } catch (e) {
      debugPrint('Error fetching user stats batch: $e');
    }

    return UserDetailStats(
      answersCount: answers,
      questionsCount: questions,
      snapsCount: snaps,
      reportsCount: reports,
    );
  }

  /// Execute user suspension securely via server-side RPC `admin_suspend_user`
  Future<void> suspendUser({
    required String targetId,
    required String reason,
    int? durationDays,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('No active admin session');

    if (targetId == '084ed6d9-7354-4301-9c73-d7f4a6a22a19' ||
        targetId == adminId) {
      throw Exception('Super administrator account cannot be suspended.');
    }

    try {
      await _supabase.rpc('admin_suspend_user', params: {
        'target_user_id': targetId,
        'reason': reason,
        'duration_days': durationDays,
      });
    } on PostgrestException catch (e) {
      debugPrint(
          'RPC admin_suspend_user PostgrestException: ${e.message} (Code: ${e.code})');
      throw Exception(
          'Unable to suspend account. Please ensure admin SQL migration is executed in Supabase.');
    } catch (e) {
      debugPrint('suspendUser error: $e');
      throw Exception('Unable to suspend account. Please try again.');
    }
  }

  /// Restore suspended account securely via server-side RPC `admin_restore_user`
  Future<void> restoreUser({
    required String targetId,
    required String reason,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('No active admin session');

    try {
      await _supabase.rpc('admin_restore_user', params: {
        'target_user_id': targetId,
        'reason': reason,
      });
    } on PostgrestException catch (e) {
      debugPrint(
          'RPC admin_restore_user PostgrestException: ${e.message} (Code: ${e.code})');
      throw Exception(
          'Unable to restore account. Please ensure admin SQL migration is executed in Supabase.');
    } catch (e) {
      debugPrint('restoreUser error: $e');
      throw Exception('Unable to restore account. Please try again.');
    }
  }

  /// Shadow ban user securely via server-side RPC `admin_shadow_ban_user`
  Future<void> shadowBanUser({
    required String targetId,
    required bool shadowBan,
    required String reason,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('No active admin session');

    if (targetId == '084ed6d9-7354-4301-9c73-d7f4a6a22a19' ||
        targetId == adminId) {
      throw Exception('Super administrator account cannot be shadow-banned.');
    }

    try {
      await _supabase.rpc('admin_shadow_ban_user', params: {
        'target_user_id': targetId,
        'shadow_ban': shadowBan,
        'reason': reason,
      });
    } on PostgrestException catch (e) {
      debugPrint(
          'RPC admin_shadow_ban_user PostgrestException: ${e.message} (Code: ${e.code})');
      throw Exception(
          'Unable to update shadow ban. Please ensure admin SQL migration is executed in Supabase.');
    } catch (e) {
      debugPrint('shadowBanUser error: $e');
      throw Exception('Unable to update shadow ban. Please try again.');
    }
  }

  /// Permanently delete user account exclusively via the secure Supabase Edge Function `delete-user`.
  /// Does NOT fall back to client-side SQL RPC calls or direct database updates.
  Future<void> deleteUser({
    required String targetId,
    required String confirmUsername,
    required String reason,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) {
      throw Exception('No active administrator session found.');
    }

    // Client-side self-protection check for Super Admin
    if (targetId == '084ed6d9-7354-4301-9c73-d7f4a6a22a19' ||
        targetId == adminId) {
      throw Exception('Super administrator account cannot be deleted.');
    }

    final trimmedUsername = confirmUsername.trim();
    final trimmedReason = reason.trim();

    if (trimmedUsername.isEmpty) {
      throw Exception('Confirmation username is required.');
    }

    if (trimmedReason.isEmpty) {
      throw Exception('Deletion reason is required.');
    }

    try {
      final res = await _supabase.functions.invoke(
        'delete-user',
        body: {
          'target_user_id': targetId,
          'confirm_username': trimmedUsername,
          'reason': trimmedReason,
        },
      );

      // Verify HTTP 200 response
      if (res.status != 200) {
        String errorMsg = 'Failed to delete account (HTTP ${res.status}).';
        if (res.data is Map && res.data['error'] != null) {
          errorMsg = res.data['error'].toString();
        }
        throw Exception(errorMsg);
      }

      // Verify explicit success: true in response payload
      final data = res.data;
      if (data is Map && data['success'] == true) {
        return; // Success confirmed by Edge Function
      }

      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Server did not confirm successful deletion.';
      throw Exception(msg);
    } on FunctionException catch (e) {
      debugPrint(
          'delete-user Edge FunctionException: status ${e.status}, details: ${e.details}');
      if (e.status == 404) {
        throw Exception(
            'Requested function delete-user was not found (HTTP 404). Please ensure the Edge Function is deployed in Supabase.');
      } else if (e.status == 401 || e.status == 403) {
        throw Exception(
            'Unauthorized to delete account (HTTP ${e.status}). Super admin privileges required.');
      } else if (e.status == 500) {
        throw Exception(
            'Server error while deleting account (HTTP 500). Please try again later.');
      }
      final detailMsg = (e.details is Map && e.details['error'] != null)
          ? e.details['error'].toString()
          : e.toString();
      throw Exception('Deletion failed: $detailMsg');
    } catch (e) {
      debugPrint('deleteUser Edge Function error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unable to delete account. $e');
    }
  }
}
