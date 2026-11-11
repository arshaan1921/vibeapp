import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../services/admin_access_service.dart';
import '../repositories/admin_dashboard_repository.dart';
import '../widgets/admin_metric_card.dart';
import 'admin_user_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminAccessService _accessService = AdminAccessService();
  final AdminDashboardRepository _repository = AdminDashboardRepository();

  AdminAccessResult? _accessResult;
  bool _isVerifying = true;

  AdminMetrics? _metrics;
  bool _loadingMetrics = false;
  int _selectedNavIndex = 0;

  final List<String> _navTitles = [
    'Overview',
    'Users',
    'Moderation',
    'Reports',
    'Analytics',
  ];

  final List<IconData> _navIcons = [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.gavel_rounded,
    Icons.report_problem_rounded,
    Icons.analytics_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _verifyAccessAndLoad();
  }

  Future<void> _verifyAccessAndLoad() async {
    setState(() {
      _isVerifying = true;
    });

    final result = await _accessService.verifyAdminAccess();

    if (!mounted) return;

    setState(() {
      _accessResult = result;
      _isVerifying = false;
    });

    if (result.isAuthorized) {
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loadingMetrics = true;
    });

    final metrics = await _repository.fetchMetrics();

    if (!mounted) return;

    setState(() {
      _metrics = metrics;
      _loadingMetrics = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_rounded,
                color: AppTheme.accentColor, size: 22),
            const SizedBox(width: 8),
            Text(
              "HIGH5 ADMIN",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isVerifying && (_accessResult?.isAuthorized ?? false))
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Metrics',
              onPressed: _loadMetrics,
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_isVerifying) {
      return _buildVerifyingState(isDark);
    }

    if (_accessResult == null || !_accessResult!.isAuthorized) {
      return _buildAccessDeniedState(isDark);
    }

    return Column(
      children: [
        // Navigation bar for 5 sections
        _buildNavTabBar(isDark),
        const Divider(height: 1),

        // Active Section Content
        Expanded(
          child: IndexedStack(
            index: _selectedNavIndex,
            children: [
              _buildOverviewSection(isDark),
              const AdminUserScreen(),
              const AdminModerationScreen(),
              const AdminReportsScreen(),
              const AdminAnalyticsScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(
            "Verifying Official Administrator Credentials...",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Querying public.is_high5_admin() backend security context",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedState(bool isDark) {
    final status = _accessResult?.status;
    final message =
        _accessResult?.errorMessage ?? "Administrator privileges required.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                size: 56,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Access Restricted",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Only the official @high5 account with valid database super_admin authorization can view this portal.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == AdminAccessStatus.networkError)
                  ElevatedButton.icon(
                    onPressed: _verifyAccessAndLoad,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Retry Verification"),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text("Return to App"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTabBar(bool isDark) {
    return Container(
      height: 54,
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _navTitles.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedNavIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor
                        : (isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _navIcons[index],
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _navTitles[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewSection(bool isDark) {
    final username = _accessResult?.username ?? 'high5';
    final rawRole = _accessResult?.role ?? 'super_admin';
    final formattedRole = rawRole.replaceAll('_', ' ').toUpperCase();

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Dashboard Header
            _buildHeaderCard(username, formattedRole, isDark),
            const SizedBox(height: 24),

            // Section Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "System Metrics",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_loadingMetrics)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 6 Metric Cards Grid with Fixed Extent for guaranteed responsiveness
            if (_metrics == null && _loadingMetrics)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_metrics != null)
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 160,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final metricItems = [
                    _metrics!.totalUsers,
                    _metrics!.newUsersToday,
                    _metrics!.dailyActiveUsers,
                    _metrics!.monthlyActiveUsers,
                    _metrics!.pendingReports,
                    _metrics!.suspendedUsers,
                  ];
                  return AdminMetricCard(metric: metricItems[index]);
                },
              ),

            const SizedBox(height: 28),

            // Official Platform Banner / Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161618) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Database Authorization Verified",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Authenticated session confirmed via public.is_high5_admin()",
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String username, String roleText, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F5C4D), const Color(0xFF0A3C32)]
              : [const Color(0xFF0F5C4D), const Color(0xFF167260)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.accentColor.withOpacity(0.8), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: AppTheme.accentColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      roleText,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.shield_outlined,
                color: Colors.white30,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "HIGH5 ADMIN",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Official Platform Management",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                "@$username — Super Administrator",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
