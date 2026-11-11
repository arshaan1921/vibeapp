import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme.dart';
import '../models/admin_user_item.dart';
import '../repositories/admin_user_repository.dart';

class AdminUserDetailsScreen extends StatefulWidget {
  final AdminUserItem user;

  const AdminUserDetailsScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  final AdminUserRepository _repository = AdminUserRepository();

  late AdminUserItem _user;
  UserDetailStats? _stats;
  bool _loadingStats = true;
  bool _performingAction = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats = await _repository.fetchUserStats(_user.id);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "User Management Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _performingAction ? null : _loadStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Summary Card
              _buildHeaderCard(isDark),
              const SizedBox(height: 20),

              // Protected Super Admin Banner
              if (_user.isSuperAdmin) _buildSuperAdminProtectionBanner(isDark),

              // Activity & Moderation Statistics
              Text(
                "ACCOUNT METRICS & ACTIVITY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white54 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsGrid(isDark),
              const SizedBox(height: 24),

              // Moderation Status Box
              Text(
                "CURRENT MODERATION STATUS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white54 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildModerationStatusCard(isDark),
              const SizedBox(height: 28),

              // Administrative Action Buttons
              Text(
                "ADMINISTRATIVE ACTIONS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white54 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildActionsSection(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final joinedText = _user.createdAt != null
        ? DateFormat('MMMM dd, yyyy').format(_user.createdAt!)
        : 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: _user.avatarUrl ?? '',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 64,
                    height: 64,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user.name ?? "No Name",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "@${_user.username}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Account UUID:",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _user.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("UUID copied to clipboard")),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "${_user.id.substring(0, 8)}...${_user.id.substring(_user.id.length - 6)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          size: 14, color: AppTheme.accentColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Joined Date:",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              Flexible(
                child: Text(
                  joinedText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_user.isSuperAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.accentColor, width: 0.8),
        ),
        child: const Text(
          "SUPER ADMIN",
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentColor,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    if (_user.isCurrentlyBanned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.redAccent, width: 0.8),
        ),
        child: const Text(
          "SUSPENDED",
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    if (_user.isShadowBanned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orangeAccent, width: 0.8),
        ),
        child: const Text(
          "SHADOW BANNED",
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF34D399), width: 0.8),
      ),
      child: const Text(
        "ACTIVE",
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF34D399),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSuperAdminProtectionBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppTheme.accentColor, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Official Super Administrator account is protected. Administrative actions cannot be performed on @high5.",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    if (_loadingStats) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _stats ?? const UserDetailStats();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard("Answers", stats.answersCount.toString(),
            Icons.question_answer_rounded, isDark),
        _buildStatCard("Questions", stats.questionsCount.toString(),
            Icons.help_outline_rounded, isDark),
        _buildStatCard("Snaps Sent", stats.snapsCount.toString(),
            Icons.photo_camera_rounded, isDark),
        _buildStatCard("Reports Received", stats.reportsCount.toString(),
            Icons.report_problem_rounded, isDark),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationStatusCard(bool isDark) {
    final bool isBanned = _user.isCurrentlyBanned;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBanned
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                color: isBanned ? Colors.redAccent : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBanned
                      ? "Account Suspended / Banned"
                      : "Account Clear & Active",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isBanned) ...[
            const SizedBox(height: 10),
            Text(
              "Expires: ${_user.bannedUntil != null ? DateFormat('MMM dd, yyyy HH:mm').format(_user.bannedUntil!) : 'Indefinite'}",
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
          ],
          if (_user.isShadowBanned) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.visibility_off_rounded,
                    color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Shadow Banned (Content hidden from global discovery)",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection(bool isDark) {
    final bool disabled = _user.isSuperAdmin || _performingAction;
    final bool isBanned = _user.isCurrentlyBanned;

    return Column(
      children: [
        // Suspend / Restore Button
        if (!isBanned)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: disabled ? null : _showSuspendDialog,
            icon: _performingAction
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.block_rounded, size: 18),
            label: const Text("Suspend Account"),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5C4D),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: disabled ? null : _showRestoreDialog,
            icon: _performingAction
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text("Restore Account"),
          ),
        const SizedBox(height: 12),

        // Shadow Ban Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orangeAccent,
            side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: disabled ? null : _showShadowBanDialog,
          icon: Icon(
              _user.isShadowBanned
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 18),
          label: Text(
              _user.isShadowBanned ? "Lift Shadow Ban" : "Shadow Ban User"),
        ),
        const SizedBox(height: 12),

        // Permanent Deletion Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade900,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: disabled ? null : _showDeleteDialog,
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text("Permanently Delete Account"),
        ),
      ],
    );
  }

  // --- DIALOGS WITH SINGLECHILDSCROLLVIEW TO PREVENT OVERFLOW ON KEYBOARD DISPLAY ---

  void _showSuspendDialog() {
    final reasonController = TextEditingController();
    int? selectedDays = 7;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Suspend Account"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "Suspending @${_user.username} will temporarily block access."),
                const SizedBox(height: 16),
                const Text("Duration:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<int?>(
                  isExpanded: true,
                  value: selectedDays,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text("3 Days")),
                    DropdownMenuItem(value: 7, child: Text("7 Days")),
                    DropdownMenuItem(value: 30, child: Text("30 Days")),
                    DropdownMenuItem(
                        value: null,
                        child: Text("Indefinite (Permanent until restored)")),
                  ],
                  onChanged: (val) => setDialogState(() => selectedDays = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: "Reason for Suspension *",
                    hintText: "Enter violation details",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Reason is required")));
                  return;
                }
                Navigator.pop(ctx);
                _executeSuspend(reason, selectedDays);
              },
              child: const Text("SUSPEND"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSuspend(String reason, int? durationDays) async {
    setState(() => _performingAction = true);
    try {
      await _repository.suspendUser(
        targetId: _user.id,
        reason: reason,
        durationDays: durationDays,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account suspended successfully.")),
        );
        setState(() {
          _user = AdminUserItem(
            id: _user.id,
            username: _user.username,
            name: _user.name,
            avatarUrl: _user.avatarUrl,
            createdAt: _user.createdAt,
            isBanned: true,
            bannedUntil: durationDays != null
                ? DateTime.now().add(Duration(days: durationDays))
                : null,
            banReason: reason,
            isShadowBanned: _user.isShadowBanned,
            strikeCount: _user.strikeCount,
            reportCount: _user.reportCount,
          );
        });
      }
    } catch (e) {
      debugPrint("Suspend action error: $e");
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText)),
        );
      }
    } finally {
      if (mounted) setState(() => _performingAction = false);
    }
  }

  void _showRestoreDialog() {
    final reasonController =
        TextEditingController(text: "Account restored by super administrator");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Account"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  "Are you sure you want to restore access for @${_user.username}?"),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration:
                    const InputDecoration(labelText: "Restoration Note"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeRestore(reasonController.text.trim());
            },
            child: const Text("RESTORE"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRestore(String reason) async {
    setState(() => _performingAction = true);
    try {
      await _repository.restoreUser(targetId: _user.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account restored successfully.")),
        );
        setState(() {
          _user = AdminUserItem(
            id: _user.id,
            username: _user.username,
            name: _user.name,
            avatarUrl: _user.avatarUrl,
            createdAt: _user.createdAt,
            isBanned: false,
            bannedUntil: null,
            banReason: null,
            isShadowBanned: _user.isShadowBanned,
            strikeCount: _user.strikeCount,
            reportCount: _user.reportCount,
          );
        });
      }
    } catch (e) {
      debugPrint("Restore action error: $e");
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText)),
        );
      }
    } finally {
      if (mounted) setState(() => _performingAction = false);
    }
  }

  void _showShadowBanDialog() {
    final reasonController = TextEditingController();
    final bool nextState = !_user.isShadowBanned;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nextState ? "Shadow Ban User" : "Lift Shadow Ban"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nextState
                    ? "Shadow banning @${_user.username} will hide their posts from discovery without notifying them."
                    : "Lift shadow ban for @${_user.username}?",
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: "Reason *"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              _executeShadowBan(nextState, reason);
            },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeShadowBan(bool shadowBan, String reason) async {
    setState(() => _performingAction = true);
    try {
      await _repository.shadowBanUser(
          targetId: _user.id, shadowBan: shadowBan, reason: reason);
      if (mounted) {
        final msg = shadowBan
            ? "Shadow ban applied successfully."
            : "Shadow ban lifted successfully.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() {
          _user = AdminUserItem(
            id: _user.id,
            username: _user.username,
            name: _user.name,
            avatarUrl: _user.avatarUrl,
            createdAt: _user.createdAt,
            isBanned: _user.isBanned,
            bannedUntil: _user.bannedUntil,
            banReason: _user.banReason,
            isShadowBanned: shadowBan,
            strikeCount: _user.strikeCount,
            reportCount: _user.reportCount,
          );
        });
      }
    } catch (e) {
      debugPrint("Shadow ban action error: $e");
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText)),
        );
      }
    } finally {
      if (mounted) setState(() => _performingAction = false);
    }
  }

  void _showDeleteDialog() {
    final confirmController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permanent Account Deletion"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "WARNING: This action is permanent and cannot be undone. Profile data and credentials will be removed.",
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text("Type the exact username '${_user.username}' to confirm:"),
              const SizedBox(height: 6),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: _user.username,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Deletion Reason *",
                  hintText: "Why is this account being deleted?",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            onPressed: () {
              final typed = confirmController.text.trim();
              final reason = reasonController.text.trim();
              if (typed != _user.username) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Username confirmation does not match")),
                );
                return;
              }
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Deletion reason is required")),
                );
                return;
              }
              Navigator.pop(ctx);
              _executeDelete(reason);
            },
            child: const Text("PERMANENTLY DELETE"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete(String reason) async {
    setState(() => _performingAction = true);
    try {
      await _repository.deleteUser(
        targetId: _user.id,
        confirmUsername: _user.username,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Account permanently deleted successfully.")),
        );
        Navigator.pop(context, true); // Return to user list
      }
    } catch (e) {
      debugPrint("Delete action error: $e");
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText)),
        );
      }
    } finally {
      if (mounted) setState(() => _performingAction = false);
    }
  }
}
