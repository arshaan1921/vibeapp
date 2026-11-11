import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../repositories/admin_dashboard_repository.dart';

class AdminMetricCard extends StatelessWidget {
  final MetricItem metric;

  const AdminMetricCard({
    super.key,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final accentColor = AppTheme.accentColor;

    final cardBg = isDark ? const Color(0xFF161618) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    // Dynamic accent selection based on metric context
    final bool isGoldAccent =
        metric.title == 'Total Users' || metric.title == 'Pending Reports';
    final Color iconColor = metric.isAvailable
        ? (isGoldAccent
            ? accentColor
            : (isDark ? const Color(0xFF34D399) : primaryColor))
        : (isDark ? Colors.white38 : Colors.grey.shade500);

    final Color iconBg = metric.isAvailable
        ? (isGoldAccent
            ? accentColor.withOpacity(0.14)
            : primaryColor.withOpacity(isDark ? 0.22 : 0.1))
        : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Icon container + Optional PENDING badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  metric.icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              if (!metric.isAvailable)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accentColor.withOpacity(0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
            ],
          ),

          // Bottom Content: Value, Title, Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: metric.isAvailable
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.grey.shade500),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metric.title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey.shade900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                metric.subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
