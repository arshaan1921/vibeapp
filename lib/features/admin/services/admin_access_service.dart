import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminAccessStatus {
  loading,
  authorized,
  unauthorized,
  networkError,
  unauthenticated,
}

class AdminAccessResult {
  final AdminAccessStatus status;
  final String? errorMessage;
  final String? userId;
  final String? username;
  final String? role;

  const AdminAccessResult({
    required this.status,
    this.errorMessage,
    this.userId,
    this.username,
    this.role,
  });

  bool get isAuthorized => status == AdminAccessStatus.authorized;
}

class AdminAccessService {
  final SupabaseClient _supabase;

  AdminAccessService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Verifies administrator access using backend database authorization function `public.is_high5_admin()`.
  /// Never caches permanent admin authorization; performs fresh query against authenticated Supabase session.
  Future<AdminAccessResult> verifyAdminAccess() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const AdminAccessResult(
        status: AdminAccessStatus.unauthenticated,
        errorMessage: 'No active authenticated session found.',
      );
    }

    try {
      // Execute database authorization function public.is_high5_admin()
      final dynamic response = await _supabase.rpc('is_high5_admin');

      final bool isAdmin = (response == true);

      if (!isAdmin) {
        return AdminAccessResult(
          status: AdminAccessStatus.unauthorized,
          userId: user.id,
          errorMessage:
              'Administrator access denied. Insufficient privileges or role revoked.',
        );
      }

      // Fetch user profile info and role details for UI display
      String username = 'high5';
      String role = 'super_admin';

      try {
        final profile = await _supabase
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['username'] != null) {
          username = profile['username'];
        }

        final adminRoleRes = await _supabase
            .from('admin_roles')
            .select('role')
            .eq('user_id', user.id)
            .maybeSingle();
        if (adminRoleRes != null && adminRoleRes['role'] != null) {
          role = adminRoleRes['role'];
        }
      } catch (e) {
        debugPrint('Notice: Error fetching secondary admin metadata: $e');
      }

      return AdminAccessResult(
        status: AdminAccessStatus.authorized,
        userId: user.id,
        username: username,
        role: role,
      );
    } on PostgrestException catch (e) {
      debugPrint('Admin RPC Postgrest error: ${e.message}');
      return AdminAccessResult(
        status: AdminAccessStatus.networkError,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Admin access check exception: $e');
      return AdminAccessResult(
        status: AdminAccessStatus.networkError,
        errorMessage: 'Network or server error during admin verification.',
      );
    }
  }

  /// Helper method for quick verification checks
  Future<bool> checkIsAdmin() async {
    final result = await verifyAdminAccess();
    return result.isAuthorized;
  }
}
