import 'package:flutter/material.dart';
import '../services/streak_restore_service.dart';

class StreakRestoreStoreDialog extends StatefulWidget {
  const StreakRestoreStoreDialog({super.key});

  @override
  State<StreakRestoreStoreDialog> createState() => _StreakRestoreStoreDialogState();
}

class _StreakRestoreStoreDialogState extends State<StreakRestoreStoreDialog> {
  bool _isLoading = false;
  final _service = StreakRestoreService();

  Future<void> _purchase(String productId) async {
    setState(() => _isLoading = true);
    try {
      await _service.buyRestore(productId);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🔥 Restore added successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Purchase failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange),
          const SizedBox(width: 8),
          Text("Get Streak Restores", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                title: "1 Restore",
                price: "₹19",
                icon: Icons.flash_on_rounded,
                onTap: () => _purchase(StreakRestoreService.restore1),
              ),
              const SizedBox(height: 12),
              _buildOption(
                title: "5 Restores",
                price: "₹79",
                icon: Icons.flash_on_rounded,
                onTap: () => _purchase(StreakRestoreService.restore5),
                isRecommended: true,
              ),
              const SizedBox(height: 12),
              _buildOption(
                title: "20 Restores",
                price: "₹199",
                icon: Icons.flash_on_rounded,
                onTap: () => _purchase(StreakRestoreService.restore20),
              ),
            ],
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
      ],
    );
  }

  Widget _buildOption({
    required String title,
    required String price,
    required IconData icon,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended ? Colors.orange : Colors.grey.withOpacity(0.3),
            width: isRecommended ? 2 : 1,
          ),
          color: isRecommended ? Colors.orange.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                  if (isRecommended)
                    const Text("BEST VALUE", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
