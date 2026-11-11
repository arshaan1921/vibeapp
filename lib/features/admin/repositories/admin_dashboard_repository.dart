import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MetricItem {
  final String title;
  final String value;
  final bool isAvailable;
  final String subtitle;
  final IconData icon;

  const MetricItem({
    required this.title,
    required this.value,
    required this.isAvailable,
    required this.subtitle,
    required this.icon,
  });
}

class AdminMetrics {
  final MetricItem totalUsers;
  final MetricItem newUsersToday;
  final MetricItem dailyActiveUsers;
  final MetricItem monthlyActiveUsers;
  final MetricItem pendingReports;
  final MetricItem suspendedUsers;

  const AdminMetrics({
    required this.totalUsers,
    required this.newUsersToday,
    required this.dailyActiveUsers,
    required this.monthlyActiveUsers,
    required this.pendingReports,
    required this.suspendedUsers,
  });
}

class AdminDashboardRepository {
  final SupabaseClient _supabase;

  AdminDashboardRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<AdminMetrics> fetchMetrics() async {
    int? totalUsersCount;
    int? newUsersTodayCount;
    int? pendingReportsCount;
    int? suspendedUsersCount;

    // 1. Total Users query from profiles table
    try {
      final res = await _supabase.from('profiles').select('id');
      totalUsersCount = (res as List).length;
    } catch (e) {
      debugPrint('AdminRepo: Error fetching total users count: $e');
    }

    // 2. New Users Today query from profiles table
    try {
      final now = DateTime.now().toUtc();
      final startOfDay =
          DateTime.utc(now.year, now.month, now.day).toIso8601String();
      final res = await _supabase
          .from('profiles')
          .select('id')
          .gte('created_at', startOfDay);
      newUsersTodayCount = (res as List).length;
    } catch (e) {
      debugPrint('AdminRepo: Error fetching new users today: $e');
    }

    // 3. Pending Reports query from reports table
    try {
      final res = await _supabase.from('reports').select('id');
      pendingReportsCount = (res as List).length;
    } catch (e) {
      debugPrint('AdminRepo: Error fetching pending reports: $e');
    }

    // 4. Suspended Users query from profiles table
    try {
      final res = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_suspended', true);
      suspendedUsersCount = (res as List).length;
    } catch (_) {
      try {
        final res =
            await _supabase.from('profiles').select('id').eq('is_banned', true);
        suspendedUsersCount = (res as List).length;
      } catch (e) {
        debugPrint('AdminRepo: Suspended column query unavailable: $e');
        suspendedUsersCount = null;
      }
    }

    final numberFormat = NumberFormat.decimalPattern();

    return AdminMetrics(
      totalUsers: MetricItem(
        title: 'Total Users',
        value: totalUsersCount != null
            ? numberFormat.format(totalUsersCount)
            : 'N/A',
        isAvailable: totalUsersCount != null,
        subtitle: totalUsersCount != null
            ? 'Registered HIGH5 accounts'
            : 'Data unavailable',
        icon: Icons.people_alt_rounded,
      ),
      newUsersToday: MetricItem(
        title: 'New Users Today',
        value: newUsersTodayCount != null
            ? numberFormat.format(newUsersTodayCount)
            : 'N/A',
        isAvailable: newUsersTodayCount != null,
        subtitle: newUsersTodayCount != null
            ? 'Accounts registered today'
            : 'Data unavailable',
        icon: Icons.person_add_alt_1_rounded,
      ),
      dailyActiveUsers: MetricItem(
        title: 'Daily Active Users',
        value: 'N/A',
        isAvailable: false,
        subtitle: 'Awaiting reliable activity tracking',
        icon: Icons.show_chart_rounded,
      ),
      monthlyActiveUsers: MetricItem(
        title: 'Monthly Active Users',
        value: 'N/A',
        isAvailable: false,
        subtitle: 'Awaiting reliable activity tracking',
        icon: Icons.stacked_line_chart_rounded,
      ),
      pendingReports: MetricItem(
        title: 'Pending Reports',
        value: pendingReportsCount != null
            ? numberFormat.format(pendingReportsCount)
            : 'N/A',
        isAvailable: pendingReportsCount != null,
        subtitle: pendingReportsCount != null
            ? 'Reports awaiting review'
            : 'Data unavailable',
        icon: Icons.report_problem_rounded,
      ),
      suspendedUsers: MetricItem(
        title: 'Suspended Users',
        value: suspendedUsersCount != null
            ? numberFormat.format(suspendedUsersCount)
            : 'N/A',
        isAvailable: suspendedUsersCount != null,
        subtitle: suspendedUsersCount != null
            ? 'Currently restricted accounts'
            : 'Currently restricted accounts',
        icon: Icons.block_rounded,
      ),
    );
  }
}
