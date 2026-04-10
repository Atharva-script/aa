import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../widgets/top_bar.dart';
import '../widgets/skeleton_widget.dart';

class SkeletonDemoScreen extends StatefulWidget {
  const SkeletonDemoScreen({super.key});

  @override
  State<SkeletonDemoScreen> createState() => _SkeletonDemoScreenState();
}

class _SkeletonDemoScreenState extends State<SkeletonDemoScreen> {
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLoadingSimulation();
  }

  void _startLoadingSimulation() {
    setState(() => _isLoading = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final backgroundColor = AppColors.getBackground(t);

        return Scaffold(
          backgroundColor: backgroundColor,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _startLoadingSimulation,
            label: Text(_isLoading ? 'Loading...' : 'Reload Data'),
            icon: Icon(_isLoading
                ? FluentIcons.hourglass_24_regular
                : FluentIcons.arrow_sync_24_regular),
            backgroundColor: AppColors.primary,
          ),
          body: Column(
            children: [
              const TopBar(
                  isExpanded: true), // Assuming always expanded for demo
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(t),
                      const SizedBox(height: 24),
                      _buildKPICards(t),
                      const SizedBox(height: 24),
                      _buildAnalyticsSection(t),
                      const SizedBox(height: 24),
                      _buildRecentActivityPanel(t),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(double t) {
    if (_isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton.text(width: 250, height: 32),
          SizedBox(height: 8),
          Skeleton.text(width: 400, height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Overview',
          style: AppTextStyles.h1.copyWith(
            color: AppColors.getTextPrimary(t),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome back, Admin. Here is your system analysis.',
          style: AppTextStyles.subBody.copyWith(
            color: AppColors.getTextSecondary(t),
          ),
        ),
      ],
    );
  }

  Widget _buildKPICards(double t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = width > 1200 ? 4 : (width > 800 ? 2 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: _isLoading
              ? List.generate(
                  4, (index) => const Skeleton.rect(borderRadius: 20))
              : [
                  _buildMetricCard(
                      "Predictions",
                      "842",
                      FluentIcons.sparkle_24_regular,
                      AppColors.accentPurple,
                      t),
                  _buildMetricCard(
                      "Accuracy",
                      "98.5%",
                      FluentIcons.data_bar_horizontal_24_regular,
                      AppColors.accentGreen,
                      t),
                  _buildMetricCard(
                      "Status",
                      "ONLINE",
                      FluentIcons.checkmark_circle_24_regular,
                      AppColors.accentTeal,
                      t),
                  _buildMetricCard("Avg. Response", "0.2s",
                      FluentIcons.timer_24_regular, AppColors.accentOrange, t),
                ],
        );
      },
    );
  }

  Widget _buildAnalyticsSection(double t) {
    if (_isLoading) {
      return const Row(
        children: [
          Expanded(
              flex: 2, child: Skeleton.rect(height: 350, borderRadius: 20)),
          SizedBox(width: 24),
          Expanded(
              flex: 1, child: Skeleton.rect(height: 350, borderRadius: 20)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              color: AppColors.getSurface(t),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getDivider(t).withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text("System Usage Chart",
                style: TextStyle(color: AppColors.getTextSecondary(t))),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              color: AppColors.getSurface(t),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getDivider(t).withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text("Feature Usage",
                style: TextStyle(color: AppColors.getTextSecondary(t))),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityPanel(double t) {
    final surfaceColor = AppColors.getSurface(t);
    final borderColor = AppColors.getDivider(t).withValues(alpha: 0.5);

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton.text(width: 150, height: 24), // Title
            const SizedBox(height: 24),
            // List Items
            for (int i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Skeleton.circle(size: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton.text(width: 200, height: 14),
                          SizedBox(height: 6),
                          Skeleton.text(width: 100, height: 10),
                        ],
                      ),
                    )
                  ],
                ),
              )
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity',
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.getTextPrimary(t))),
          const SizedBox(height: 24),
          // Actual Content would go here
          Text("Activity loaded.",
              style: TextStyle(color: AppColors.getTextSecondary(t))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, double t) {
    final surfaceColor = AppColors.getSurface(t);
    final textColor = AppColors.getTextPrimary(t);
    final secondaryTextColor = AppColors.getTextSecondary(t);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.subBody.copyWith(
              color: secondaryTextColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
