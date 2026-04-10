import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SeverityItem {
  final double score;
  final String label;
  final String timestamp;

  SeverityItem({
    required this.score,
    required this.label,
    required this.timestamp,
  });

  factory SeverityItem.fromJson(Map<String, dynamic> json) {
    return SeverityItem(
      score: (json['score'] ?? 0.0).toDouble(),
      label: json['label'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

/// Visual grid showing detection severity distribution
class SeverityGrid extends StatelessWidget {
  final List<SeverityItem> items;
  final bool isDark;
  final int columns;

  const SeverityGrid({
    super.key,
    required this.items,
    required this.isDark,
    this.columns = 10,
  });

  Color _getSeverityColor(double score) {
    if (score < 0.3) return AppColors.accentGreen;
    if (score < 0.5) return AppColors.accentCyan;
    if (score < 0.7) return AppColors.warningDark;
    if (score < 0.85) return AppColors.accentOrange;
    return AppColors.accentRed;
  }

  IconData _getLabelIcon(String label) {
    if (label.toLowerCase() == 'nudity') {
      return FluentIcons.eye_off_24_regular;
    }
    return FluentIcons.warning_24_regular;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(isDark);
    final textColor = AppColors.getTextPrimary(isDark);
    final secondaryTextColor = AppColors.getTextSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getDivider(isDark).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Severity Overview',
                    style: AppTextStyles.h3.copyWith(color: textColor),
                  ),
                  Text(
                    'Recent ${items.length} detections',
                    style: AppTextStyles.subBody.copyWith(fontSize: 12),
                  ),
                ],
              ),
              // Stats summary
              Row(
                children: [
                  _buildMiniStat(
                    'High',
                    items.where((i) => (i.score) >= 0.8).length,
                    AppColors.accentRed,
                    secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniStat(
                    'Med',
                    items
                        .where((i) => (i.score) >= 0.5 && (i.score) < 0.8)
                        .length,
                    AppColors.warningDark,
                    secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniStat(
                    'Low',
                    items.where((i) => (i.score) < 0.5).length,
                    AppColors.accentGreen,
                    secondaryTextColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          FluentIcons.checkmark_circle_24_regular,
                          color: AppColors.accentGreen,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No detections',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final color = _getSeverityColor(item.score);

                      return Tooltip(
                        message:
                            '${item.label}\nScore: ${(item.score * 100).toInt()}%\n${item.timestamp}',
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300 + index * 20),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color:
                                color.withValues(alpha: 0.3 + item.score * 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getLabelIcon(item.label),
                                color: color,
                                size: 12,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  'Low (<30%)', AppColors.accentGreen, secondaryTextColor),
              const SizedBox(width: 16),
              _buildLegendItem(
                  'Med (30-70%)', AppColors.warningDark, secondaryTextColor),
              const SizedBox(width: 16),
              _buildLegendItem(
                  'High (>70%)', AppColors.accentRed, secondaryTextColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textColor, fontSize: 10)),
      ],
    );
  }
}
