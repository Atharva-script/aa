import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final surfaceColor = AppColors.getSurface(t);
        final backgroundColor = AppColors.getBackground(t);
        final textColor = AppColors.getTextPrimary(t);
        final secondaryTextColor = AppColors.getTextSecondary(t);
        final dividerColor = AppColors.getDivider(t);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Revenue Overview',
                      style: AppTextStyles.h3.copyWith(color: textColor)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dividerColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'This Year',
                          style: AppTextStyles.subBody.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(FluentIcons.chevron_down_24_regular,
                            size: 18, color: secondaryTextColor),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    height: 300,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar('Jan', 0.45, AppColors.primary,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('Feb', 0.65, AppColors.accentBlue,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('Mar', 0.35, AppColors.accentCyan,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('Apr', 0.85, AppColors.primary,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('May', 0.55, AppColors.accentOrange,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('Jun', 0.95, AppColors.accentBlue,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                        const SizedBox(width: 12),
                        _buildBar('Jul', 0.45, AppColors.accentCyan,
                            backgroundColor: backgroundColor,
                            secondaryTextColor: secondaryTextColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(String label, double heightFactor, Color color,
      {required Color backgroundColor, required Color secondaryTextColor}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 32,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: heightFactor),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    heightFactor: value,
                    child: Container(
                      width: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            color.withValues(alpha: 0.8),
                            color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTextStyles.subBody.copyWith(
            fontWeight: FontWeight.w500,
            color: secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
