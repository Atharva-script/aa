import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:math' as math;
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class MonitoringTab extends StatefulWidget {
  const MonitoringTab({super.key});

  @override
  State<MonitoringTab> createState() => _MonitoringTabState();
}

class _MonitoringTabState extends State<MonitoringTab>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  bool? _optimisticIsRunning; // null means use provider state

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _showStopDialog() {
    final secretCodeController = TextEditingController();
    bool isLoading = false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Icon(FluentIcons.shield_24_regular,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                'Stop Monitoring?',
                style: TextStyle(
                    color: theme.textTheme.titleLarge?.color,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your secret code to confirm.',
                style: AppTextStyles.body
                    .copyWith(color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: secretCodeController,
                obscureText: true,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Secret Code',
                  hintStyle: TextStyle(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.5)),
                  prefixIcon: Icon(FluentIcons.key_24_regular,
                      color: theme.textTheme.bodyMedium?.color),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (secretCodeController.text.isEmpty) return;

                      setState(() => isLoading = true);

                      final provider = context.read<AppProvider>();
                      final success = await provider
                          .stopMonitoring(secretCodeController.text);

                      if (mounted && ctx.mounted) Navigator.pop(ctx);

                      if (success) {
                        setState(() => _optimisticIsRunning = false);
                        // Reset optimistic state after a short delay to allow provider to sync
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() => _optimisticIsRunning = null);
                          }
                        });
                      } else if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ??
                                'Failed to stop monitoring'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Stop',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isRunning = _optimisticIsRunning ?? provider.isMonitoring;
        final isConnected = provider.isConnected;
        final laptopOnline = provider.laptopOnline;

        return RefreshIndicator(
          onRefresh: () async {
            await provider.refreshStatus();
            await provider.refreshAlerts();
            await provider.checkLaptopStatus();
          },
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Device Selector & Header ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monitoring',
                              style: AppTextStyles.h1.copyWith(
                                  color: AppColors.getPrimary(isDark),
                                  fontSize: 24),
                            ),
                            Text(
                              provider.selectedChild != null
                                  ? 'Target: ${provider.selectedChild!['name']}'
                                  : 'Select a device',
                              style: TextStyle(
                                color: AppColors.getTextSecondary(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        // Device Selector Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(isDark),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.getGlassBorder(isDark)),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: AppColors.getSurface(isDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: provider.selectedChildId,
                                hint: Text("Select Device",
                                    style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            AppColors.getTextTertiary(isDark))),
                                icon: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                      FluentIcons.chevron_down_16_regular,
                                      size: 16,
                                      color:
                                          AppColors.getTextSecondary(isDark)),
                                ),
                                style: TextStyle(
                                  color: AppColors.getTextPrimary(isDark),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                dropdownColor: AppColors.getSurface(isDark),
                                borderRadius: BorderRadius.circular(16),
                                elevation: 4,
                                onChanged: (String? newValue) async {
                                  if (newValue != null &&
                                      newValue != provider.selectedChildId) {
                                    final success =
                                        await provider.selectChild(newValue);
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "Authentication failed. Switch cancelled."),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                                items: provider.children
                                    .map<DropdownMenuItem<String>>((child) {
                                  return DropdownMenuItem<String>(
                                    value: child['email'],
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primaryPurple
                                                .withValues(alpha: 0.1),
                                            image: (child['profile_pic'] !=
                                                        null &&
                                                    child['profile_pic']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? DecorationImage(
                                                    image: NetworkImage(child[
                                                                'profile_pic']
                                                            .toString()
                                                            .startsWith('http')
                                                        ? child['profile_pic']
                                                        : '${AppConstants.apiBaseUrl}/${child['profile_pic']}'),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: (child['profile_pic'] ==
                                                      null ||
                                                  child['profile_pic']
                                                      .toString()
                                                      .isEmpty)
                                              ? Icon(
                                                  FluentIcons.laptop_16_regular,
                                                  size: 14,
                                                  color:
                                                      AppColors.primaryPurple)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          child['name'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: AppColors.getTextPrimary(
                                                isDark),
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (child['email'] ==
                                            provider.selectedChildId) ...[
                                          const SizedBox(width: 8),
                                          Icon(FluentIcons.checkmark_16_filled,
                                              size: 16,
                                              color: AppColors.primaryPurple)
                                        ]
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Shield Status Hero ──
                  _buildShieldHero(provider, isRunning, isDark),

                  const SizedBox(height: 20),

                  // ── Live Stats Row ──
                  _buildLiveStatsRow(provider, isDark),

                  const SizedBox(height: 20),

                  // ── Quick Actions ──
                  _buildSectionLabel(
                      'Quick Actions', FluentIcons.flash_24_regular, isDark),
                  const SizedBox(height: 10),
                  _buildQuickActions(
                      provider, isRunning, isConnected, laptopOnline, isDark),

                  const SizedBox(height: 20),

                  // ── Connection & Device Info ──
                  _buildSectionLabel('Device & Connection',
                      FluentIcons.plug_connected_24_regular, isDark),
                  const SizedBox(height: 10),
                  _buildDeviceInfoCard(provider, isDark),

                  const SizedBox(height: 20),

                  // ── Preferences ──
                  _buildSectionLabel('Monitoring Preferences',
                      FluentIcons.options_24_regular, isDark),
                  const SizedBox(height: 10),
                  _buildPreferences(provider, isDark, theme),

                  const SizedBox(height: 20),

                  // ── Recent Detections Summary ──
                  _buildSectionLabel('Recent Activity',
                      FluentIcons.history_24_regular, isDark),
                  const SizedBox(height: 10),
                  _buildRecentActivity(provider, isDark),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Shield Hero with animated ring ──
  Widget _buildShieldHero(AppProvider provider, bool isRunning, bool isDark) {
    final statusColor =
        isRunning ? AppColors.getSuccess(isDark) : AppColors.getError(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRunning
              ? [
                  statusColor.withValues(alpha: 0.12),
                  statusColor.withValues(alpha: 0.04)
                ]
              : [
                  AppColors.getError(isDark).withValues(alpha: 0.08),
                  Colors.transparent
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Animated shield
          ScaleTransition(
            scale:
                isRunning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated rotating ring
                if (isRunning)
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, child) => Transform.rotate(
                      angle: _ringController.value * 2 * math.pi,
                      child: child,
                    ),
                    child: CustomPaint(
                      size: const Size(100, 100),
                      painter: _DashedCirclePainter(
                        color: statusColor.withValues(alpha: 0.3),
                        strokeWidth: 2,
                        dashCount: 12,
                      ),
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.15),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Icon(
                    isRunning
                        ? FluentIcons.shield_checkmark_24_regular
                        : FluentIcons.shield_dismiss_24_regular,
                    size: 36,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isRunning ? 'Protection Active' : 'Protection Inactive',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRunning
                ? 'Uptime: ${provider.formattedUptime}'
                : (provider.selectedChildId != null
                    ? (provider.isPcAppOnline
                        ? 'Ready to monitor'
                        : 'Connecting...')
                    : 'Select a device to start'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 20),
          // Start/Stop Toggle Button
          Builder(
            builder: (context) {
              final canStart = provider.isPcAppOnline || isRunning;
              return Column(
                children: [
                  GestureDetector(
                    onTap: canStart
                        ? () {
                            if (isRunning) {
                              _showStopDialog();
                            } else {
                              if (provider.selectedChildId != null) {
                                setState(() => _optimisticIsRunning = true);
                                provider.startMonitoring().then((success) {
                                  // Reset optimistic state after a short delay to allow provider to sync
                                  Future.delayed(const Duration(seconds: 2),
                                      () {
                                    if (mounted) {
                                      setState(
                                          () => _optimisticIsRunning = null);
                                    }
                                  });
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Please select a device first"),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 140,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: !canStart
                              ? Colors.grey.withValues(alpha: 0.2)
                              : (isRunning
                                  ? AppColors.danger.withValues(alpha: 0.1)
                                  : AppColors.primaryPurple
                                      .withValues(alpha: 0.1)),
                          border: Border.all(
                            color: !canStart
                                ? Colors.grey.withValues(alpha: 0.3)
                                : (isRunning
                                    ? AppColors.danger
                                    : AppColors.primaryPurple),
                            width: 2,
                          ),
                        ),
                        child: Center(
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            isRunning
                                ? FluentIcons.stop_24_filled
                                : FluentIcons.play_24_filled,
                            size: 20,
                            color: canStart
                                ? (isRunning
                                    ? AppColors.danger
                                    : AppColors.primaryPurple)
                                : AppColors.getTextSecondary(isDark)
                                    .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRunning ? 'STOP' : 'START',
                            style: TextStyle(
                              color: canStart
                                  ? (isRunning
                                      ? AppColors.danger
                                      : AppColors.primaryPurple)
                                  : AppColors.getTextSecondary(isDark)
                                      .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ]))),
                  ),
                  if (!canStart) ...[
                    const SizedBox(height: 8),
                    Text(
                      'PC App must be online first',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(isDark)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Live Stats Grid ──
  Widget _buildLiveStatsRow(AppProvider provider, bool isDark) {
    final uptime = provider.formattedUptime;
    final alerts = provider.totalAlerts;
    final critical = provider.criticalAlerts;
    final laptopUptime = provider.laptopUptimeFormatted;

    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            icon: FluentIcons.timer_24_regular,
            label: 'Session',
            value: provider.isMonitoring ? uptime : '--:--',
            color: AppColors.primaryBlue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            icon: FluentIcons.warning_24_regular,
            label: 'Alerts',
            value: '$alerts',
            color: alerts > 0
                ? AppColors.getError(isDark)
                : AppColors.getSuccess(isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            icon: FluentIcons.fire_24_regular,
            label: 'Critical',
            value: '$critical',
            color: critical > 0
                ? AppColors.warningDark
                : AppColors.getTextTertiary(isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            icon: FluentIcons.desktop_24_regular,
            label: 'PC Up',
            value: laptopUptime,
            color: AppColors.accentTeal,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Quick Actions ──
  Widget _buildQuickActions(AppProvider provider, bool isRunning,
      bool isConnected, bool laptopOnline, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: FluentIcons.arrow_sync_24_regular,
            label: 'Refresh',
            color: AppColors.primaryBlue,
            isDark: isDark,
            onTap: () async {
              await provider.refreshStatus();
              await provider.refreshAlerts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Status refreshed'),
                    backgroundColor: AppColors.getSuccess(isDark),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionTile(
            icon: FluentIcons.desktop_24_regular,
            label: laptopOnline ? 'PC Online' : 'Wake PC',
            color: laptopOnline
                ? AppColors.getSuccess(isDark)
                : AppColors.warningDark,
            isDark: isDark,
            onTap: () async {
              if (!laptopOnline) {
                // Try Wake-on-LAN first
                final success = await provider.wakeUpPc();
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Wake-on-LAN signal sent'),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    );
                  }
                } else {
                  // Fallback or show error
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(provider.errorMessage ?? 'Failed to wake PC'),
                        backgroundColor: AppColors.getError(isDark),
                      ),
                    );
                  }
                }
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionTile(
            icon: FluentIcons.alert_off_24_regular,
            label: 'Clear Alerts',
            color: AppColors.getError(isDark),
            isDark: isDark,
            onTap: () async {
              final success = await provider.clearAlerts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(success ? 'Alerts cleared' : 'Failed to clear'),
                    backgroundColor: success
                        ? AppColors.getSuccess(isDark)
                        : AppColors.getError(isDark),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // ── Device Info Card ──
  Widget _buildDeviceInfoCard(AppProvider provider, bool isDark) {
    final hostname = provider.laptopHostname;
    final ip = provider.laptopIp;
    final connected = provider.isConnected;
    final pcOnline = provider.laptopOnline;
    final pcAppOnline = provider.isPcAppOnline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getGlassBorder(isDark)),
      ),
      child: Column(
        children: [
          _DeviceInfoRow(
            icon: FluentIcons.globe_24_regular,
            label: 'Server',
            value: connected ? 'Connected' : 'Disconnected',
            valueColor: connected
                ? AppColors.getSuccess(isDark)
                : AppColors.getError(isDark),
            isDark: isDark,
          ),
          Divider(
              height: 20,
              color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
          _DeviceInfoRow(
            icon: FluentIcons.desktop_24_regular,
            label: 'PC Status',
            value:
                pcOnline ? (pcAppOnline ? 'App Running' : 'Online') : 'Offline',
            valueColor: pcOnline
                ? AppColors.getSuccess(isDark)
                : AppColors.getTextTertiary(isDark),
            isDark: isDark,
          ),
          Divider(
              height: 20,
              color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
          _DeviceInfoRow(
            icon: FluentIcons.laptop_24_regular,
            label: 'Hostname',
            value: hostname.isEmpty || hostname == 'Unknown' ? '--' : hostname,
            isDark: isDark,
          ),
          Divider(
              height: 20,
              color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
          _DeviceInfoRow(
            icon: FluentIcons.wifi_1_24_regular,
            label: 'IP Address',
            value: ip.isEmpty || ip == 'Unknown' ? '--' : ip,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ── Preferences ──
  Widget _buildPreferences(AppProvider provider, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getGlassBorder(isDark)),
      ),
      child: Column(
        children: [
          _PreferenceTile(
            icon: FluentIcons.mic_24_regular,
            title: 'Audio Monitoring',
            subtitle: 'Detect abusive language in real-time',
            value: provider.audioMonitoringEnabled,
            iconColor: AppColors.getError(isDark),
            onChanged: (val) => provider.setMonitoringPreference('audio', val),
          ),
          Divider(
              height: 1,
              indent: 56,
              color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
          _PreferenceTile(
            icon: FluentIcons.eye_24_regular,
            title: 'Screen Monitoring',
            subtitle: 'Detect inappropriate visual content',
            value: provider.screenMonitoringEnabled,
            iconColor: AppColors.accentIndigo,
            onChanged: (val) => provider.setMonitoringPreference('screen', val),
          ),
          Divider(
              height: 1,
              indent: 56,
              color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
          _PreferenceTile(
            icon: FluentIcons.alert_24_regular,
            title: 'Push Notifications',
            subtitle: 'Receive instant detection alerts',
            value: provider.pushNotificationsEnabled,
            iconColor: AppColors.primaryPurple,
            onChanged: (val) => provider.setMonitoringPreference('push', val),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity ──
  Widget _buildRecentActivity(AppProvider provider, bool isDark) {
    final recentAlerts = provider.alerts.take(3).toList();

    if (recentAlerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.getGlassBorder(isDark)),
        ),
        child: Column(
          children: [
            Icon(FluentIcons.checkmark_circle_24_regular,
                size: 40,
                color: AppColors.getSuccess(isDark).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              'All Clear',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.getSuccess(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No detections recorded yet',
              style: TextStyle(
                  color: AppColors.getTextTertiary(isDark), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: recentAlerts.map((alert) {
        final label = alert['label'] ?? 'Detection';
        final score = ((alert['score'] ?? 0.0) as num).toDouble();
        final time = alert['timestamp'] ?? '';
        final type = alert['type'] ?? 'abuse';
        final isNudity = type == 'nudity';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                (isNudity ? AppColors.accentPink : AppColors.getError(isDark))
                    .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  (isNudity ? AppColors.accentPink : AppColors.getError(isDark))
                      .withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isNudity
                          ? AppColors.accentPink
                          : AppColors.getError(isDark))
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNudity
                      ? FluentIcons.eye_off_24_regular
                      : FluentIcons.warning_24_regular,
                  size: 16,
                  color: isNudity
                      ? AppColors.accentPink
                      : AppColors.getError(isDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.getTextPrimary(isDark),
                        )),
                    Text('${(score * 100).toStringAsFixed(0)}% confidence',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextTertiary(isDark),
                        )),
                  ],
                ),
              ),
              Text(
                _formatTimestamp(time),
                style: TextStyle(
                    fontSize: 10, color: AppColors.getTextTertiary(isDark)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return ts.length > 10 ? ts.substring(0, 10) : ts;
    }
  }

  Widget _buildSectionLabel(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.getTextTertiary(isDark)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(isDark),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Stat Mini Card ──
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getGlassBorder(isDark)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.getTextTertiary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Tile ──
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Device Info Row ──
class _DeviceInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _DeviceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.getTextTertiary(isDark)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.getTextPrimary(isDark),
          ),
        ),
      ],
    );
  }
}

// ── Preference Tile ──
class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color iconColor;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.iconColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: iconColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title,
          style: AppTextStyles.body
              .copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
    );
  }
}

// ── Dashed Circle Painter ──
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final dashAngle = (2 * math.pi) / dashCount;
    final gapAngle = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle - gapAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
