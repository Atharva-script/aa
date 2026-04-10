import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A compact activity feed widget showing recent detection alerts
class ActivityFeed extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final bool isDark;
  final int maxItems;
  final VoidCallback? onViewAll;

  const ActivityFeed({
    super.key,
    required this.alerts,
    required this.isDark,
    this.maxItems = 5,
    this.onViewAll,
  });

  IconData _getLabelIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('nudity')) return FluentIcons.eye_off_24_regular;
    if (l.contains('abuse')) return FluentIcons.warning_24_regular;
    return FluentIcons.alert_24_regular;
  }

  Color _getSeverityColor(double score) {
    if (score >= 0.8) return AppColors.accentRed;
    if (score >= 0.5) return AppColors.accentOrange;
    return AppColors.accentGreen;
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(isDark);
    final textColor = AppColors.getTextPrimary(isDark);
    final secondaryColor = AppColors.getTextSecondary(isDark);
    final borderColor = AppColors.getDivider(isDark).withValues(alpha: 0.5);

    final displayAlerts = alerts.take(maxItems).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.flash_24_regular,
                      color: AppColors.accentPurple, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: AppTextStyles.h3.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Alert List
          if (displayAlerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(FluentIcons.checkmark_circle_24_regular,
                        color: AppColors.accentGreen, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No recent alerts',
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayAlerts.map((alert) {
              final label = alert['label'] ?? 'Unknown';
              final score = (alert['score'] ?? 0.0).toDouble();
              final timestamp = alert['timestamp'] ?? '';
              final color = _getSeverityColor(score);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getLabelIcon(label), color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(score * 100).toInt()}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
