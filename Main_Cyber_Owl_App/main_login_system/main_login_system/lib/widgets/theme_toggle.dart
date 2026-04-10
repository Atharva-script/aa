import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/theme_manager.dart';

/// Theme Toggle - Black or White (Dark or Light)
class ThemeSlider extends StatelessWidget {
  const ThemeSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, child) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;

        return Row(
          children: [
            // Black (Dark) Option
            _ThemeOption(
              icon: FluentIcons.weather_moon_24_regular,
              label: 'Black',
              isSelected: isDark,
              themeValue: t,
              onTap: () => themeManager.setThemeValue(0.0),
            ),
            const SizedBox(width: 12),
            // White (Light) Option
            _ThemeOption(
              icon: FluentIcons.weather_sunny_24_regular,
              label: 'White',
              isSelected: !isDark,
              themeValue: t,
              onTap: () => themeManager.setThemeValue(1.0),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final double themeValue;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.themeValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.getPrimary(themeValue).withValues(alpha: 0.15)
              : AppColors.getGlass(themeValue),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.getPrimary(themeValue)
                : AppColors.getGlassBorder(themeValue),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.getPrimary(themeValue)
                  : AppColors.getTextSecondary(themeValue),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.getPrimary(themeValue)
                    : AppColors.getTextSecondary(themeValue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
