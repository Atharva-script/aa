import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../widgets/radial_gauge_chart.dart';
import '../widgets/sparkline_card.dart';
import '../widgets/severity_grid.dart';
import '../widgets/activity_feed.dart';
import '../widgets/category_breakdown.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Extract data from provider
        final analytics = provider.analytics;
        final double threatLevel =
            (analytics?['threat_level'] ?? 0.0).toDouble();

        // Extract analytics data for KPI cards
        final int totalDetections =
            (analytics?['total_detections'] ?? provider.totalAlerts);
        final int nudityCount = (analytics?['nudity_count'] ?? 0);
        final int abuseCount = (analytics?['abuse_count'] ?? 0);
        final double avgConfidence =
            (analytics?['avg_confidence'] ?? 0.0).toDouble();

        // Category breakdown
        final categoryBreakdown =
            analytics?['category_breakdown'] as Map<String, dynamic>? ?? {};
        final double nudityPercent =
            (categoryBreakdown['nudity'] ?? 0.0).toDouble();
        final double abusePercent =
            (categoryBreakdown['abuse'] ?? 0.0).toDouble();

        // Map alerts to SeverityItems
        final severityItems = provider.alerts.map((alert) {
          return SeverityItem(
            score: (alert['score'] ?? 0.0).toDouble(),
            label: alert['label'] ?? 'Unknown',
            timestamp: alert['timestamp'] ?? '',
          );
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            await provider.refreshParentData(); // Refresh children list
            await provider.refreshStatus();
            await provider.refreshAlerts();
            await provider.refreshAnalytics();
            await provider.checkLaptopStatus();
          },
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, provider),

                  const SizedBox(height: 20),

                  // Laptop Status Card (compact)
                  _buildLaptopStatusCard(context, provider, isDark),

                  const SizedBox(height: 20),

                  // PC App Status Indicator (Green Widget)
                  if (provider.isPcAppOnline)
                    _buildPCAppOpenedWidget(context, isDark),

                  const SizedBox(height: 20),

                  // ========== KPI CARDS GRID (2x2) ==========
                  _buildSectionTitle('Key Metrics',
                      FluentIcons.data_bar_horizontal_24_regular, isDark),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      SparklineCard(
                        title: 'Total Detections',
                        value: '$totalDetections',
                        icon: FluentIcons.shield_checkmark_24_regular,
                        accentColor: AppColors.accentPurple,
                        sparklineData: const [2, 4, 3, 5, 4, 6, 5],
                        isDark: isDark,
                      ),
                      SparklineCard(
                        title: 'Nudity Detected',
                        value: '$nudityCount',
                        icon: FluentIcons.eye_off_24_regular,
                        accentColor: AppColors.accentOrange,
                        sparklineData: const [1, 2, 1, 3, 2, 2, 3],
                        isDark: isDark,
                      ),
                      SparklineCard(
                        title: 'Abuse Detected',
                        value: '$abuseCount',
                        icon: FluentIcons.warning_24_regular,
                        accentColor: AppColors.accentRed,
                        sparklineData: const [1, 1, 2, 1, 2, 3, 2],
                        isDark: isDark,
                      ),
                      SparklineCard(
                        title: 'Avg. Confidence',
                        value: '${avgConfidence.toStringAsFixed(0)}%',
                        icon: FluentIcons.data_trending_24_regular,
                        accentColor: AppColors.accentGreen,
                        sparklineData: const [70, 75, 72, 78, 80, 77, 82],
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ========== THREAT GAUGE ==========
                  _buildSectionTitle('Threat Analysis',
                      FluentIcons.shield_lock_24_regular, isDark),
                  const SizedBox(height: 12),
                  Center(
                    child: RadialGaugeChart(
                      value: threatLevel,
                      isDark: isDark,
                      size: 200,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ========== CATEGORY BREAKDOWN ==========
                  CategoryBreakdown(
                    nudityPercent: nudityPercent,
                    abusePercent: abusePercent,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  // ========== ACTIVITY FEED ==========
                  ActivityFeed(
                    alerts: provider.alerts,
                    isDark: isDark,
                    maxItems: 5,
                  ),

                  const SizedBox(height: 24),

                  // ========== SEVERITY GRID ==========
                  _buildSectionTitle(
                      'Severity Overview', FluentIcons.grid_24_regular, isDark),
                  const SizedBox(height: 12),
                  SeverityGrid(
                    items: severityItems,
                    isDark: isDark,
                    columns: 8,
                  ),

                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPCAppOpenedWidget(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getSuccess(isDark).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getSuccess(isDark).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.getSuccess(isDark).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.desktop_checkmark_24_filled,
              color: AppColors.getSuccess(isDark),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PC App Connected',
                  style: TextStyle(
                    color: AppColors.getSuccess(isDark),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'CyberOwl Desktop is currently active',
                  style: TextStyle(
                    color: AppColors.getSuccess(isDark).withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.getSuccess(isDark),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.getSuccess(isDark).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryPurple, width: 2),
          ),
          child: ClipOval(
            child: (provider.fullUserPhotoUrl != null &&
                    provider.fullUserPhotoUrl!.isNotEmpty)
                ? FadeInImage(
                    placeholder: const AssetImage('assets/logo/logo.png'),
                    image: NetworkImage(provider.fullUserPhotoUrl!),
                    fit: BoxFit.cover,
                    imageErrorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading profile image: $error');
                      return Image.asset('assets/logo/logo.png',
                          fit: BoxFit.cover);
                    },
                  )
                : Image.asset('assets/logo/logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              Text(
                provider.userName ?? 'Parent',
                style: AppTextStyles.h2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _StatusBadge(isActive: provider.isMonitoring),
      ],
    );
  }

  Widget _buildLaptopStatusCard(
      BuildContext context, AppProvider provider, bool isDark) {
    final selectedChild = provider.selectedChild;
    final children = provider.children;
    // Determine the display name and avatar
    final String displayName = selectedChild != null
        ? (selectedChild['name'] ?? 'Unknown PC')
        : 'System Status';

    // Check if we have multiple options to show selector
    final bool canSelect = children.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          // Avatar or Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: (selectedChild != null &&
                    selectedChild['profile_pic'] != null &&
                    selectedChild['profile_pic'].toString().isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      AppConstants.resolveProfilePic(
                          selectedChild['profile_pic']?.toString())!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(FluentIcons.desktop_24_regular,
                            color: AppColors.primaryPurple, size: 20);
                      },
                    ),
                  )
                : (selectedChild == null ||
                        selectedChild['profile_pic'] == null ||
                        selectedChild['profile_pic'].toString().isEmpty)
                    ? Icon(FluentIcons.desktop_24_regular,
                        color: AppColors.primaryPurple, size: 20)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector Row
                PopupMenuButton<String>(
                  enabled: canSelect,
                  onSelected: (String email) async {
                    if (email != provider.selectedChildId) {
                      final success = await provider.selectChild(email);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Authentication failed. Switch cancelled."),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return children.map((child) {
                      return PopupMenuItem<String>(
                        value: child['email'],
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  image: (child['profile_pic'] != null &&
                                          child['profile_pic'].isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              AppConstants.resolveProfilePic(
                                                  child['profile_pic']
                                                      ?.toString())!),
                                          fit: BoxFit.cover)
                                      : null),
                              child: (child['profile_pic'] == null ||
                                      child['profile_pic'].isEmpty)
                                  ? const Icon(Icons.computer,
                                      size: 14, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(child['name'] ?? 'PC',
                                    style: TextStyle(
                                        color:
                                            AppColors.getTextPrimary(isDark)))),
                            if (child['email'] == provider.selectedChildId)
                              Icon(Icons.check,
                                  size: 16, color: AppColors.primaryPurple)
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: AppColors.getTextPrimary(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (canSelect) ...[
                        const SizedBox(width: 4),
                        Icon(FluentIcons.chevron_down_16_regular,
                            size: 14, color: AppColors.textSecondaryLight),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selectedChild != null)
            GestureDetector(
              onTap:
                  (provider.isLaunchingCurrentChild || provider.isPcAppOnline)
                      ? null
                      : () async {
                          final appProvider =
                              Provider.of<AppProvider>(context, listen: false);
                          // Launch for the currently selected child
                          await appProvider.launchPcApp(
                              childEmail: selectedChild['email']);
                        },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: provider.isLaunchingCurrentChild
                      ? AppColors.primaryPurple.withValues(alpha: 0.2)
                      : (provider.laptopOnline
                          ? AppColors.accentGreen.withValues(alpha: 0.15)
                          : AppColors.primaryPurple.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: provider.laptopOnline
                          ? AppColors.accentGreen.withValues(alpha: 0.5)
                          : AppColors.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: provider.isLaunchingCurrentChild
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Waking...',
                            style: TextStyle(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              provider.laptopOnline
                                  ? FluentIcons.checkmark_circle_24_regular
                                  : FluentIcons.power_24_regular,
                              size: 14,
                              color: provider.laptopOnline
                                  ? AppColors.accentGreen
                                  : AppColors.primaryPurple),
                          const SizedBox(width: 4),
                          Text(
                            provider.laptopOnline ? 'Online' : 'Wake Up',
                            style: TextStyle(
                              color: provider.laptopOnline
                                  ? AppColors.accentGreen
                                  : AppColors.primaryPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.successDark.withValues(alpha: 0.1)
            : AppColors.getTextSecondary(false).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.successDark.withValues(alpha: 0.5)
              : AppColors.getTextSecondary(false).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.successDark
                  : AppColors.getTextSecondary(false),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ACTIVE' : 'IDLE',
            style: TextStyle(
              color: isActive
                  ? AppColors.successDark
                  : AppColors.getTextSecondary(false),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
