import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A compact widget showing the category breakdown (Nudity vs Abuse)
class CategoryBreakdown extends StatelessWidget {
  final double nudityPercent;
  final double abusePercent;
  final bool isDark;

  const CategoryBreakdown({
    super.key,
    required this.nudityPercent,
    required this.abusePercent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(isDark);
    final textColor = AppColors.getTextPrimary(isDark);
    final secondaryColor = AppColors.getTextSecondary(isDark);
    final borderColor = AppColors.getDivider(isDark).withValues(alpha: 0.5);

    final total = nudityPercent + abusePercent;
    final hasData = total > 0;

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
            children: [
              Icon(FluentIcons.data_pie_24_regular,
                  color: AppColors.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text(
                'Category Split',
                style: AppTextStyles.h3.copyWith(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No data available',
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
              ),
            )
          else ...[
            // Nudity Bar
            _buildProgressBar(
              label: 'Nudity',
              percent: nudityPercent,
              color: AppColors.accentOrange,
              textColor: textColor,
              secondaryColor: secondaryColor,
            ),
            const SizedBox(height: 12),
            // Abuse Bar
            _buildProgressBar(
              label: 'Abuse',
              percent: abusePercent,
              color: AppColors.accentRed,
              textColor: textColor,
              secondaryColor: secondaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double percent,
    required Color color,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress Bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (percent / 100).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
