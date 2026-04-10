import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../widgets/top_bar.dart';
import '../services/abuse_detection_service.dart';
import '../services/dashboard_analytics_service.dart';
import '../widgets/profile_stat_card.dart';
import '../widgets/skeleton_widget.dart';
import '../widgets/sparkline_card.dart';
import '../widgets/radial_gauge_chart.dart';
import '../widgets/pulse_indicator.dart';
import '../widgets/detection_heatmap.dart';
import '../widgets/severity_grid.dart';

class DashboardScreen extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback? onViewHistory;
  final VoidCallback? onNavigateToProfile;
  final Function(int)? onNavigationRequest;
  final VoidCallback? onDashboardReady;

  const DashboardScreen({
    super.key,
    this.isExpanded = false,
    this.onViewHistory,
    this.onNavigateToProfile,
    this.onNavigationRequest,
    this.onDashboardReady,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AbuseDetectionService _detectionService = AbuseDetectionService();
  final DashboardAnalyticsService _analyticsService =
      DashboardAnalyticsService();

  bool _showLoading = true;

  @override
  void initState() {
    super.initState();
    // Enforce "Only for loading" - fallback after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showLoading = false);
        widget.onDashboardReady?.call();
      }
    });

    _initMonitoring();
  }

  Future<void> _initMonitoring() async {
    final user = await AuthService.getLocalUser();
    final deviceId =
        user?['device_name']; // Extracted during login via DeviceInfoHelper

    // Start polling for detection updates
    _detectionService.startPolling(deviceId: deviceId);
    // Start polling for analytics updates
    _analyticsService.startPolling(deviceId: deviceId);
  }

  @override
  void dispose() {
    _analyticsService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;
        final backgroundColor = AppColors.getBackground(t);

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: backgroundColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: double.infinity,
                    child: TopBar(
                      isExpanded: widget.isExpanded,
                      onProfileTap: widget.onNavigateToProfile,
                      onNavigateTo: widget.onNavigationRequest,
                    )),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(t, isDark),
                      const SizedBox(height: 24),
                      _buildSparklineKPICards(t, isDark),
                      const SizedBox(height: 24),
                      _buildGaugeAndTimelineRow(t, isDark),
                      const SizedBox(height: 24),
                      _buildChartsRow(t, isDark),
                      const SizedBox(height: 24),
                      _buildBottomSection(t, isDark),
                      const SizedBox(height: 24),
                      _buildDataTableSection(t, isDark),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double t, bool isDark) {
    return FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.getLocalUser(),
        builder: (context, snapshot) {
          final rawName = snapshot.data?['name'] ?? 'User';
          final userName = rawName.split(' ')[0];
          final capitalizedName = userName.isNotEmpty
              ? '${userName[0].toUpperCase()}${userName.substring(1)}'
              : 'User';
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview v2.0',
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.getTextPrimary(t),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, $capitalizedName. Here is your system analysis.',
                    style: AppTextStyles.subBody.copyWith(
                      color: AppColors.getTextSecondary(t),
                    ),
                  ),
                ],
              ),
              // Live status indicator
              StreamBuilder<MonitoringStatus>(
                stream: _detectionService.statusStream,
                builder: (context, snapshot) {
                  final isMonitoring = snapshot.data?.running ?? false;
                  return LiveStatusBadge(
                    isMonitoring: isMonitoring,
                    themeValue: themeManager.themeValue,
                  );
                },
              ),
            ],
          );
        });
  }

  Widget _buildSparklineKPICards(double t, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = width > 1100 ? 4 : (width > 850 ? 3 : 2);
        double childAspectRatio = width < 600 ? 1.0 : 1.2;

        return StreamBuilder<DashboardAnalytics>(
            stream: _analyticsService.analyticsStream,
            builder: (context, snapshot) {
              // SKELETON LOADING STATE
              if (!snapshot.hasData && _showLoading) {
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: List.generate(
                      4,
                      (index) => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(t),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.getDivider(t)
                                      .withValues(alpha: 0.5)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Skeleton.rect(
                                    width: 40, height: 40, borderRadius: 12),
                                Spacer(),
                                Skeleton.text(width: 100, height: 28),
                                SizedBox(height: 8),
                                Skeleton.text(width: 60, height: 12),
                              ],
                            ),
                          )),
                );
              }

              final analytics = snapshot.data ?? DashboardAnalytics.empty();

              // Calculate trends
              final detectionTrendDelta = analytics.detectionTrend.length >= 2
                  ? analytics.detectionTrend.last -
                      analytics
                          .detectionTrend[analytics.detectionTrend.length - 2]
                  : 0;

              final nudityTrendDelta = analytics.nudityTrend.length >= 2
                  ? analytics.nudityTrend.last -
                      analytics.nudityTrend[analytics.nudityTrend.length - 2]
                  : 0;

              final abuseTrendDelta = analytics.abuseTrend.length >= 2
                  ? analytics.abuseTrend.last -
                      analytics.abuseTrend[analytics.abuseTrend.length - 2]
                  : 0;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
                children: [
                  SparklineCard(
                    title: 'Total Detections',
                    value: analytics.totalDetections.toString(),
                    icon: FluentIcons.shield_24_regular,
                    accentColor: AppColors.accentPurple,
                    sparklineData: analytics.detectionTrend
                        .map((e) => e.toDouble())
                        .toList(),
                    themeValue: t,
                    trendLabel: detectionTrendDelta != 0
                        ? '${detectionTrendDelta > 0 ? '+' : ''}$detectionTrendDelta'
                        : null,
                    isPositiveTrend: detectionTrendDelta <= 0,
                  ),
                  SparklineCard(
                    title: 'Nudity Detected',
                    value: analytics.nudityCount.toString(),
                    icon: FluentIcons.eye_off_24_regular,
                    accentColor: AppColors.accentOrange,
                    sparklineData:
                        analytics.nudityTrend.map((e) => e.toDouble()).toList(),
                    themeValue: t,
                    trendLabel: nudityTrendDelta != 0
                        ? '${nudityTrendDelta > 0 ? '+' : ''}$nudityTrendDelta'
                        : null,
                    isPositiveTrend: nudityTrendDelta <= 0,
                  ),
                  SparklineCard(
                    title: 'Abuse Detected',
                    value: analytics.abuseCount.toString(),
                    icon: FluentIcons.warning_24_regular,
                    accentColor: AppColors.accentRed,
                    sparklineData:
                        analytics.abuseTrend.map((e) => e.toDouble()).toList(),
                    themeValue: t,
                    trendLabel: abuseTrendDelta != 0
                        ? '${abuseTrendDelta > 0 ? '+' : ''}$abuseTrendDelta'
                        : null,
                    isPositiveTrend: abuseTrendDelta <= 0,
                  ),
                  SparklineCard(
                    title: 'Avg. Confidence',
                    value: '${analytics.avgConfidence.toStringAsFixed(1)}%',
                    icon: FluentIcons.data_bar_horizontal_24_regular,
                    accentColor: AppColors.accentGreen,
                    sparklineData: analytics.accuracyTrend,
                    themeValue: t,
                  ),
                ],
              );
            });
      },
    );
  }

  Widget _buildGaugeAndTimelineRow(double t, bool isDark) {
    return SizedBox(
      height: 380,
      child: Row(
        children: [
          // Threat Gauge
          Expanded(
            flex: 1,
            child: StreamBuilder<DashboardAnalytics>(
              stream: _analyticsService.analyticsStream,
              builder: (context, snapshot) {
                final threatLevel = snapshot.data?.threatLevel ?? 0;
                return RadialGaugeChart(
                  value: threatLevel,
                  label: 'Threat Level',
                  themeValue: t,
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Detection Timeline
          Expanded(
            flex: 2,
            child: _buildTimelineChart(t, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineChart(double t, bool isDark) {
    final surfaceColor = AppColors.getSurface(t);
    final textColor = AppColors.getTextPrimary(t);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
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
                  Text('Detection Timeline',
                      style: AppTextStyles.h3.copyWith(color: textColor)),
                  Text('24-hour activity',
                      style: AppTextStyles.subBody.copyWith(fontSize: 12)),
                ],
              ),
              // Legend
              Row(
                children: [
                  _buildChartLegend('Nudity', AppColors.accentOrange, t),
                  const SizedBox(width: 16),
                  _buildChartLegend('Abuse', AppColors.accentRed, t),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<TimelineData>(
              stream: _analyticsService.timelineStream,
              builder: (context, snapshot) {
                final timeline =
                    snapshot.data?.timeline ?? TimelineData.empty().timeline;

                if (timeline.isEmpty) {
                  return Center(
                      child: Text('No data',
                          style:
                              TextStyle(color: AppColors.getTextSecondary(t))));
                }

                // Create spots for both lines
                final nuditySpots = <FlSpot>[];
                final abuseSpots = <FlSpot>[];

                for (int i = 0; i < timeline.length; i++) {
                  nuditySpots.add(
                      FlSpot(i.toDouble(), timeline[i].nudityCount.toDouble()));
                  abuseSpots.add(
                      FlSpot(i.toDouble(), timeline[i].abuseCount.toDouble()));
                }

                final maxY = timeline.fold<int>(0,
                        (max, h) => h.totalCount > max ? h.totalCount : max) *
                    1.2;

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color:
                                AppColors.getDivider(t).withValues(alpha: 0.2),
                            strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              interval: 4,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < timeline.length) {
                                  return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(timeline[idx].hour,
                                          style: TextStyle(
                                              color:
                                                  AppColors.getTextSecondary(t),
                                              fontSize: 10)));
                                }
                                return const SizedBox.shrink();
                              })),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxY > 0 ? maxY / 4 : 1,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString(),
                                    style: TextStyle(
                                        color: AppColors.getTextSecondary(t),
                                        fontSize: 10));
                              })),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 23,
                    minY: 0,
                    maxY: maxY > 0 ? maxY : 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: nuditySpots,
                        isCurved: true,
                        color: AppColors.accentOrange,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true,
                            color:
                                AppColors.accentOrange.withValues(alpha: 0.1)),
                      ),
                      LineChartBarData(
                        spots: abuseSpots,
                        isCurved: true,
                        color: AppColors.accentRed,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.accentRed.withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color, double t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: AppColors.getTextSecondary(t), fontSize: 11)),
      ],
    );
  }

  Widget _buildChartsRow(double t, bool isDark) {
    return SizedBox(
      height: 350,
      child: Row(
        children: [
          // Category Pie Chart
          Expanded(
            flex: 1,
            child: _buildCategoryPieChart(t, isDark),
          ),
          const SizedBox(width: 24),
          // Weekly Heatmap
          Expanded(
            flex: 2,
            child: StreamBuilder<HeatmapData>(
              stream: _analyticsService.heatmapStream,
              builder: (context, snapshot) {
                final heatmapData = snapshot.data ?? HeatmapData.empty();
                return DetectionHeatmap(
                  heatmapData: heatmapData.heatmap,
                  dayLabels: heatmapData.dayLabels,
                  themeValue: t,
                  maxValue: heatmapData.maxValue,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(double t, bool isDark) {
    final surfaceColor = AppColors.getSurface(t);
    final textColor = AppColors.getTextPrimary(t);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Split',
              style: AppTextStyles.h3.copyWith(color: textColor)),
          Text('Detection types',
              style: AppTextStyles.subBody.copyWith(fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DashboardAnalytics>(
              stream: _analyticsService.analyticsStream,
              builder: (context, snapshot) {
                final analytics = snapshot.data ?? DashboardAnalytics.empty();
                final nudityPct = analytics.categoryBreakdown['nudity'] ?? 0;
                final abusePct = analytics.categoryBreakdown['abuse'] ?? 0;

                if (nudityPct == 0 && abusePct == 0) {
                  return Center(
                      child: Text('No data',
                          style:
                              TextStyle(color: AppColors.getTextSecondary(t))));
                }

                return PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: nudityPct,
                        title: '${nudityPct.toStringAsFixed(0)}%',
                        color: AppColors.accentOrange,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PieChartSectionData(
                        value: abusePct,
                        title: '${abusePct.toStringAsFixed(0)}%',
                        color: AppColors.accentRed,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPieLegend('Nudity', AppColors.accentOrange,
                  AppColors.getTextSecondary(t)),
              const SizedBox(width: 24),
              _buildPieLegend(
                  'Abuse', AppColors.accentRed, AppColors.getTextSecondary(t)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildBottomSection(double t, bool isDark) {
    return SizedBox(
      height: 350,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Grid
          Expanded(
            flex: 1,
            child: StreamBuilder<DashboardAnalytics>(
              stream: _analyticsService.analyticsStream,
              builder: (context, snapshot) {
                final severityItems = snapshot.data?.severityGrid ?? [];
                return SeverityGrid(
                  items: severityItems,
                  themeValue: t,
                  columns: 7,
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Activity Feed
          Expanded(
            flex: 1,
            child: _buildRecentActivityPanel(t, isDark),
          ),
          const SizedBox(width: 24),
          // User Profile Card
          Expanded(
            flex: 1,
            child: FutureBuilder<Map<String, dynamic>?>(
                future: AuthService.getLocalUser(),
                builder: (context, snapshot) {
                  final userData = snapshot.data;
                  final rawName = userData?['name'] ?? 'User';
                  final displayName = rawName
                      .split(' ')
                      .map((str) => str.isNotEmpty
                          ? '${str[0].toUpperCase()}${str.substring(1)}'
                          : '')
                      .join(' ');
                  final role = userData?['email'] ?? 'System Member';
                  String? photoUrl =
                      userData?['photo_url'] ?? userData?['profile_pic'];
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    if (!photoUrl.startsWith('http')) {
                      String cleanPath = photoUrl;
                      if (cleanPath.contains('\\')) {
                        cleanPath = cleanPath.split('\\').last;
                      } else if (cleanPath.contains('/')) {
                        cleanPath = cleanPath.split('/').last;
                      }
                      photoUrl =
                          '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$cleanPath';
                    }
                  }

                  return StreamBuilder<MonitoringStatus>(
                      stream: _detectionService.statusStream,
                      builder: (context, statusSnapshot) {
                        final isRunning = statusSnapshot.data?.running ?? false;

                        return ProfileStatCard(
                          themeValue: themeManager.themeValue,
                          title: 'Current User',
                          userName: displayName,
                          role: role,
                          profileImageUrl: photoUrl,
                          leftLabel: 'Shield',
                          leftValue: isRunning ? 'Active' : 'Inactive',
                          rightLabel: 'Status',
                          rightValue: isRunning ? 'Monitoring' : 'Idle',
                        );
                      });
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityPanel(double t, bool isDark) {
    final surfaceColor = AppColors.getSurface(t);
    final textColor = AppColors.getTextPrimary(t);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity Feed',
                  style: AppTextStyles.h3.copyWith(color: textColor)),
              StreamBuilder<MonitoringStatus>(
                stream: _detectionService.statusStream,
                builder: (context, snapshot) {
                  final isRunning = snapshot.data?.running ?? false;
                  return PulseIndicator(
                    isActive: isRunning,
                    themeValue: t,
                    size: 8,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AbuseAlert>>(
              stream: _detectionService.alertsStream,
              builder: (context, snapshot) {
                // SKELETON LOADING STATE
                if (!snapshot.hasData) {
                  if (_showLoading) {
                    return ListView.separated(
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => const Row(
                        children: [
                          Skeleton.circle(size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeleton.text(width: 150, height: 14),
                                SizedBox(height: 4),
                                Skeleton.text(width: 80, height: 10),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  } else {
                    return Center(
                        child: Text("No data available",
                            style: TextStyle(
                                color: AppColors.getTextSecondary(t))));
                  }
                }

                final detections = snapshot.data
                        ?.where((a) => a.type == 'abuse' || a.type == 'nudity')
                        .toList() ??
                    [];

                if (detections.isEmpty) {
                  return Center(
                      child: Text("No recent threat detections",
                          style:
                              TextStyle(color: AppColors.getTextSecondary(t))));
                }

                // Show limited items
                final displayList = detections.take(6).toList();

                return ListView.separated(
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final alert = displayList[index];
                    return _buildActivityItem(
                      icon: alert.label == 'nudity'
                          ? FluentIcons.eye_off_24_regular
                          : FluentIcons.warning_24_regular,
                      color: alert.label == 'nudity'
                          ? AppColors.accentPurple
                          : AppColors.accentRed,
                      title: '${alert.label} Detected',
                      subtitle:
                          '${alert.timestamp} • "${alert.sentence ?? 'No content'}"',
                      t: t,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required double t,
      required bool isDark}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.getTextPrimary(t),
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Text(subtitle,
                  style: TextStyle(
                      color: AppColors.getTextSecondary(t), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataTableSection(double t, bool isDark) {
    final surfaceColor = AppColors.getSurface(t);
    final textColor = AppColors.getTextPrimary(t);
    final borderColor = AppColors.getDivider(t).withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Detection History',
                  style: AppTextStyles.h3.copyWith(color: textColor)),
              StreamBuilder<AlertStats>(
                stream: _detectionService.statsStream,
                builder: (context, snapshot) {
                  final total = snapshot.data?.total ?? 0;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$total total records',
                      style: const TextStyle(
                        color: AppColors.accentPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<DetectionLog>>(
              stream: _detectionService.logsStream,
              builder: (context, snapshot) {
                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: Text("No logs recorded yet.",
                        style: TextStyle(color: AppColors.getTextSecondary(t))),
                  );
                }

                // Show last 10 logs
                final displayLogs = logs.take(10).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppColors.getBackground(t).withValues(alpha: 0.5)),
                    dataRowColor: WidgetStateProperty.all(Colors.transparent),
                    columnSpacing: 24,
                    horizontalMargin: 12,
                    columns: [
                      DataColumn(
                          label: Text('User',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                      DataColumn(
                          label: Text('Module',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                      DataColumn(
                          label: Text('Label',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                      DataColumn(
                          label: Text('Score',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                      DataColumn(
                          label: Text('Time',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                      DataColumn(
                          label: Text('Content',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor))),
                    ],
                    rows: displayLogs.map((log) {
                      return _buildDataRow(
                          log.user,
                          log.source.toUpperCase(),
                          log.label,
                          "${(log.score * 100).toStringAsFixed(1)}%",
                          log.timestamp,
                          log.sentence ?? '-',
                          t,
                          isDark);
                    }).toList(),
                  ),
                );
              }),
        ],
      ),
    );
  }

  DataRow _buildDataRow(String user, String module, String label, String score,
      String time, String content, double t, bool isDark) {
    final textColor = AppColors.getTextPrimary(t);

    final type = label.toLowerCase();
    Color statusColor;

    if (type.contains('abuse') ||
        type.contains('nudity') ||
        type.contains('threat')) {
      statusColor = AppColors.accentRed;
    } else if (module.contains('AUTH') || module.contains('SECURITY')) {
      statusColor = AppColors.accentBlue;
    } else if (label.toLowerCase().contains('start')) {
      statusColor = AppColors.accentGreen;
    } else if (label.toLowerCase().contains('stop')) {
      statusColor = Colors.grey;
    } else {
      statusColor = AppColors.accentBlue;
    }

    return DataRow(cells: [
      DataCell(Text(user, style: TextStyle(color: textColor))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.accentPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Text(module,
            style:
                const TextStyle(color: AppColors.accentPurple, fontSize: 12)),
      )),
      DataCell(Text(label,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600))),
      DataCell(Text(score, style: TextStyle(color: textColor))),
      DataCell(
          Text(time, style: TextStyle(color: AppColors.getTextSecondary(t)))),
      DataCell(SizedBox(
        width: 200,
        child: Text(content,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontStyle: FontStyle.italic)),
      )),
    ]);
  }
}
