import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Animated KPI Card with embedded sparkline chart
class SparklineCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final List<double> sparklineData;
  final bool isDark;
  final String? trendLabel;
  final bool isPositiveTrend;
  final VoidCallback? onTap;

  const SparklineCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.sparklineData,
    required this.isDark,
    this.trendLabel,
    this.isPositiveTrend = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(isDark);
    final textColor = AppColors.getTextPrimary(isDark);
    final secondaryTextColor = AppColors.getTextSecondary(isDark);
    final borderColor = AppColors.getDivider(isDark).withValues(alpha: 0.5);

    // Generate chart spots from data
    final spots = sparklineData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    // Check if we have actual data (not all zeros)
    final hasData = spots.length >= 2;
    final hasNonZeroData = sparklineData.any((v) => v > 0);

    // If no real data, show flat line at zero
    final effectiveSpots = hasNonZeroData
        ? spots
        : List.generate(spots.length > 1 ? spots.length : 7,
            (i) => FlSpot(i.toDouble(), 0));

    final maxY = hasNonZeroData
        ? (sparklineData.reduce((a, b) => a > b ? a : b) * 1.3).toDouble()
        : 10.0;

    // Create a secondary color for gradient effect
    final gradientEndColor = HSLColor.fromColor(accentColor)
        .withLightness(
            (HSLColor.fromColor(accentColor).lightness * 0.7).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.06 : 0.03),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon and trend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.18),
                        accentColor.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                if (trendLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isPositiveTrend
                              ? AppColors.accentGreen
                              : AppColors.accentRed)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositiveTrend
                              ? FluentIcons.arrow_trending_24_regular
                              : FluentIcons.arrow_trending_down_24_regular,
                          color: isPositiveTrend
                              ? AppColors.accentGreen
                              : AppColors.accentRed,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          trendLabel!,
                          style: TextStyle(
                            color: isPositiveTrend
                                ? AppColors.accentGreen
                                : AppColors.accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Sparkline chart — enhanced
            SizedBox(
              height: 38,
              child: hasData
                  ? LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (effectiveSpots.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          enabled: hasNonZeroData,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) =>
                                accentColor.withValues(alpha: 0.9),
                            tooltipRoundedRadius: 6,
                            tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  spot.y.toStringAsFixed(0),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: hasNonZeroData,
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: effectiveSpots,
                            isCurved: hasNonZeroData,
                            curveSmoothness: 0.35,
                            gradient: hasNonZeroData
                                ? LinearGradient(
                                    colors: [accentColor, gradientEndColor],
                                  )
                                : null,
                            color: hasNonZeroData
                                ? null
                                : secondaryTextColor.withValues(alpha: 0.3),
                            barWidth: hasNonZeroData ? 2.5 : 1.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: hasNonZeroData,
                              getDotPainter: (spot, percent, barData, index) {
                                // Show dot only on last point
                                if (index == effectiveSpots.length - 1) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: accentColor,
                                    strokeWidth: 1.5,
                                    strokeColor:
                                        isDark ? Colors.black : Colors.white,
                                  );
                                }
                                return FlDotCirclePainter(
                                  radius: 0,
                                  color: Colors.transparent,
                                  strokeWidth: 0,
                                  strokeColor: Colors.transparent,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: hasNonZeroData,
                              gradient: hasNonZeroData
                                  ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        accentColor.withValues(alpha: 0.25),
                                        accentColor.withValues(alpha: 0.08),
                                        accentColor.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'No data',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 4),

            // Value
            Text(
              value,
              style: AppTextStyles.h2.copyWith(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 1),
            // Title
            Text(
              title,
              style: AppTextStyles.subBody.copyWith(
                color: secondaryTextColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
