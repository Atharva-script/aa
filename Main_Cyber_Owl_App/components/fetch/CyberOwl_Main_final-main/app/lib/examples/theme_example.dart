/// CYBER OWL - THEME SYSTEM GUIDE
/// ================================
///
/// This guide shows how to use the continuous theme system in your app.
///
/// THEME FILES:
/// - lib/theme/app_colors.dart     → All color definitions (Continuous 0.0 - 1.0)
/// - lib/theme/app_theme.dart      → Interpolated ThemeData
/// - lib/theme/theme_manager.dart  → Theme state management (double themeValue)
/// - lib/widgets/theme_toggle.dart → ThemeSlider widget
///
/// ================================

library theme_example;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/theme_manager.dart';
import '../widgets/theme_toggle.dart';

/// Example: Using theme-aware colors in your widgets
class ThemeExampleScreen extends StatelessWidget {
  const ThemeExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get continuous theme value
    final double t = themeManager.themeValue;

    // Legacy support logic
    final bool isDark = themeManager.isDark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(t),
      appBar: AppBar(
        title: const Text('Theme Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example 1: Theme-aware text
            Text(
              'Primary Text',
              style: TextStyle(
                color: AppColors.getTextPrimary(t),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secondary text with theme awareness',
              style: TextStyle(
                color: AppColors.getTextSecondary(t),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 32),

            // Example 2: Glassmorphism card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getGlass(t),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getGlassBorder(t),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glassmorphism Card',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(t),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This card automatically adapts to theme slider value',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(t),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Example 3: Theme Toggle Slider
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getSurface(t),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getBorder(t),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Controls',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(t),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Slider
                  const Center(child: ThemeSlider()),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Manual buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            themeManager.setThemeValue(1.0); // Light
                          },
                          icon:
                              const Icon(FluentIcons.weather_sunny_24_regular),
                          label: const Text('Light'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            themeManager.setThemeValue(0.0); // Dark
                          },
                          icon: const Icon(FluentIcons.weather_moon_24_regular),
                          label: const Text('Dark'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Example 4: Status colors
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getSurface(t),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getBorder(t),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Colors (Theme-Adaptive)',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(t),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusBadge('Success', AppColors.getSuccess(t), t),
                  const SizedBox(height: 8),
                  _buildStatusBadge('Warning', AppColors.getWarning(t), t),
                  const SizedBox(height: 8),
                  _buildStatusBadge('Error', AppColors.getError(t), t),
                  const SizedBox(height: 8),
                  _buildStatusBadge('Info', AppColors.getInfo(t), t),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Current theme info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(t).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getPrimary(t),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.info_24_regular,
                    color: AppColors.getPrimary(t),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Theme Value: ${themeManager.themeValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.getTextPrimary(t),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Mode: ${isDark ? "Dark-ish" : "Light-ish"}',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(t),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color, double t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTextPrimary(t),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
