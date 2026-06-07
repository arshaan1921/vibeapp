import 'package:flutter/material.dart';
import '../services/streak_restore_service.dart';

class StreakRestoreScreen extends StatefulWidget {
  const StreakRestoreScreen({super.key});

  @override
  State<StreakRestoreScreen> createState() => _StreakRestoreScreenState();
}

class _StreakRestoreScreenState extends State<StreakRestoreScreen> {
  bool _isLoading = false;

  Future<void> _purchaseRestore(String productId) async {
    setState(() => _isLoading = true);
    try {
      await StreakRestoreService().buyRestore(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🔥 Restore added successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("STREAK RESTORES"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Never Lose a Streak",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0A3321),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Lost a streak? Buy a restore pack to bring it back instantly! 🔥",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    _buildRestoreCard(
                      context,
                      id: StreakRestoreService.restore1,
                      title: "1 Streak Restore",
                      price: "₹19",
                    ),
                    _buildRestoreCard(
                      context,
                      id: StreakRestoreService.restore5,
                      title: "5 Streak Restores",
                      price: "₹79",
                      isRecommended: true,
                    ),
                    _buildRestoreCard(
                      context,
                      id: StreakRestoreService.restore20,
                      title: "20 Streak Restores",
                      price: "₹199",
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRestoreCard(
    BuildContext context, {
    required String id,
    required String title,
    required String price,
    bool isRecommended = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isRecommended 
              ? Colors.orange.withOpacity(0.5) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _purchaseRestore(id),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.titleLarge?.color,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 13,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isRecommended ? "Best Value Pack" : "Available instantly",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
