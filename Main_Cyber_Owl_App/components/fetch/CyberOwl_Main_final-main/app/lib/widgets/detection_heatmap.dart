import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Weekly detection heatmap visualization (7 days x 24 hours)
class DetectionHeatmap extends StatelessWidget {
  final List<List<int>> heatmapData; // 7 days x 24 hours, normalized 0-100
  final List<String> dayLabels;
  final double themeValue;
  final int maxValue;

  const DetectionHeatmap({
    super.key,
    required this.heatmapData,
    required this.dayLabels,
    required this.themeValue,
    this.maxValue = 100,
  });

  Color _getHeatColor(int value, double t) {
    if (value == 0) {
      return AppColors.isDark(t)
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05);
    }

    // Color gradient from blue (low) to red (high)
    final normalized = value / 100;
    if (normalized < 0.25) {
      return AppColors.accentCyan.withValues(alpha: 0.3 + normalized);
    } else if (normalized < 0.5) {
      return AppColors.accentGreen.withValues(alpha: 0.4 + normalized * 0.5);
    } else if (normalized < 0.75) {
      return AppColors.warningDark.withValues(alpha: 0.5 + normalized * 0.3);
    } else {
      return AppColors.accentRed.withValues(alpha: 0.6 + normalized * 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(themeValue);
    final textColor = AppColors.getTextPrimary(themeValue);
    final secondaryTextColor = AppColors.getTextSecondary(themeValue);

    // Hour labels (every 4 hours for readability)
    final hourLabels = ['12A', '4A', '8A', '12P', '4P', '8P'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getDivider(themeValue).withValues(alpha: 0.5),
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
                    'Weekly Activity',
                    style: AppTextStyles.h3.copyWith(color: textColor),
                  ),
                  Text(
                    'Detection patterns by hour',
                    style: AppTextStyles.subBody
                        .copyWith(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
              // Legend
              Row(
                children: [
                  Text('Low',
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 10)),
                  const SizedBox(width: 4),
                  Container(
                    width: 60,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentCyan.withValues(alpha: 0.3),
                          AppColors.accentGreen,
                          AppColors.warningDark,
                          AppColors.accentRed,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('High',
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 40) / 24;
                final cellHeight = (constraints.maxHeight - 20) / 7;

                return Column(
                  children: [
                    // Hour labels row
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: hourLabels
                            .map((h) => SizedBox(
                                  width: cellWidth * 4,
                                  child: Text(
                                    h,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 9,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Heatmap grid
                    Expanded(
                      child: Row(
                        children: [
                          // Day labels
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: dayLabels
                                .map((d) => SizedBox(
                                      width: 36,
                                      height: cellHeight - 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: Text(
                                            d,
                                            style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          // Grid cells
                          Expanded(
                            child: Column(
                              children: List.generate(
                                heatmapData.length,
                                (dayIndex) => Expanded(
                                  child: Row(
                                    children: List.generate(
                                      24,
                                      (hourIndex) {
                                        final value = dayIndex <
                                                    heatmapData.length &&
                                                hourIndex <
                                                    heatmapData[dayIndex].length
                                            ? heatmapData[dayIndex][hourIndex]
                                            : 0;
                                        return Expanded(
                                          child: Tooltip(
                                            message:
                                                '${dayLabels[dayIndex]} $hourIndex:00 - $value detections',
                                            child: Container(
                                              margin: const EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                color: _getHeatColor(
                                                    value, themeValue),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
