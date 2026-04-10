import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Helper colors
    final textColor = theme.textTheme.bodyMedium?.color;
    final headingColor = theme.textTheme.titleLarge?.color;
    final cardColor = theme.cardColor;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: provider.refreshAlerts,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 16,
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),

                        // Header
                        Text('Detection Alerts',
                            style: AppTextStyles.heading1
                                .copyWith(color: headingColor)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent threats found',
                              style: AppTextStyles.body.copyWith(
                                  color: theme.textTheme.bodySmall?.color),
                            ),
                            if (provider.alerts.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    _confirmClearAlerts(context, provider),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Clear All',
                                    style: TextStyle(
                                        color: AppColors.danger, fontSize: 13)),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // Alerts List
              if (provider.alerts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48,
                            color: AppColors.success.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No threats detected',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= provider.alerts.length) return null;
                        return _AlertCard(
                          alert: provider.alerts[index],
                          isDark: isDark,
                          textColor: textColor,
                          cardColor: cardColor,
                        );
                      },
                      childCount: provider.alerts.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearAlerts(BuildContext context, AppProvider provider) {
    // ... existing clear logic (kept mostly same but minimal)
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear History?'),
        content: const Text('This will permanently remove all detection logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearAlerts();
            },
            child:
                const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final bool isDark;
  final Color? textColor;
  final Color? cardColor;

  const _AlertCard({
    required this.alert,
    this.isDark = true,
    this.textColor,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = alert['label']?.toString() ?? 'Alert';
    final sentence = alert['sentence']?.toString() ?? '';
    final score = (alert['score'] ?? 0.0) as num;
    final timestamp = alert['timestamp']?.toString() ?? '';

    final color = _getAlertColor(label);

    // Condensed minimal card
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
          color: cardColor, // Plain card color
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 4), // Accent strip
            bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200),
            top: BorderSide(
                color: isDark ? Colors.transparent : Colors.grey.shade100),
            right: BorderSide(
                color: isDark ? Colors.transparent : Colors.grey.shade100),
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Smaller font
                    letterSpacing: 0.5),
              ),
              Text(
                timestamp,
                style: TextStyle(
                    color: textColor?.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (sentence.isNotEmpty)
            Text(
              sentence,
              style: TextStyle(
                  fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 12, color: textColor?.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                'Conf: ${(score * 100).toInt()}%',
                style: TextStyle(
                    color: textColor?.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          )
        ],
      ),
    );
  }

  Color _getAlertColor(String label) {
    switch (label.toLowerCase()) {
      case 'nudity':
        return AppColors.danger;
      case 'abuse':
        return AppColors.warning;
      case 'toxic':
        return AppColors.secondary;
      case 'harassment':
        return const Color(0xFFe67e22);
      default:
        return AppColors.danger;
    }
  }
}
