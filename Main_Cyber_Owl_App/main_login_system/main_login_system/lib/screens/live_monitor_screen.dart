import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../services/abuse_detection_service.dart';
import '../widgets/forgot_code_dialog.dart';

class LiveMonitorScreen extends StatefulWidget {
  final String monitorType; // 'main', 'abuse', 'nudity'
  final VoidCallback onBack;

  const LiveMonitorScreen({
    super.key,
    required this.monitorType,
    required this.onBack,
  });

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen>
    with SingleTickerProviderStateMixin {
  final AbuseDetectionService _detectionService = AbuseDetectionService();

  List<AbuseAlert> _alerts = [];
  MonitoringStatus _status =
      MonitoringStatus(running: false, alertsCount: 0, uptimeSeconds: 0);

  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.8, end: 1.2).animate(_pulseController);

    _initializeService();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    // Force timeout to prevent infinite loading
    final timeoutFuture =
        Future.delayed(const Duration(seconds: 5), () => false);

    bool healthy = false;
    try {
      // Race between health check and timeout
      healthy =
          await Future.any([_detectionService.checkHealth(), timeoutFuture]);
    } catch (e) {
      healthy = false;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (!healthy) {
        _showSnack('Connection failed. Retrying...', Colors.orange);
        // Retry logic or just let user manually refresh
      }
    }

    if (healthy) {
      await _loadData();
      await _detectionService
          .syncState(); // Ensure polling is active if running

      _detectionService.alertsStream.listen((alerts) {
        if (mounted) setState(() => _alerts = alerts);
      });
      // Removed transcripts listener
      _detectionService.statusStream.listen((status) {
        if (mounted) setState(() => _status = status);
      });

      // BACKUP: Force periodic refresh to guarantee UI updates
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _loadData();
      });

      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    final user = await AuthService.getLocalUser();
    final deviceId = user?['device_name'];

    final alerts =
        await _detectionService.getAlerts(limit: 100, deviceId: deviceId);
    final status = await _detectionService.getStatus(deviceId: deviceId);

    if (mounted) {
      setState(() {
        _alerts = alerts;
        _status = status;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_status.running) {
      // Secure Stop: Prompt for code
      final codeController = TextEditingController();
      final shouldStop = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(FluentIcons.lock_closed_24_regular,
                  color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              const Text('Secure Stop'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your secret code to stop monitoring:'),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) {
                  if (codeController.text.trim().isNotEmpty) {
                    Navigator.pop(context, true);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Secret Code',
                  prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ForgotSecretCodeDialog(),
                    );
                  },
                  child: const Text('Forgot Secret Code?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Stop Monitoring',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldStop == true) {
        final result = await _detectionService.stopMonitoring(
            secretCode: codeController.text.trim());
        if (mounted) {
          if (result['success'] == true) {
            _showSnack('Monitoring stopped successfully', Colors.orange);
          } else {
            _showSnack('Stop Failed: ${result['error']}', Colors.red);
          }
        }
      }
    } else {
      // Start (No code required)
      final result = await _detectionService.startMonitoring();
      if (mounted) {
        if (result['success'] == true) {
          _showSnack('Audio and Nudity monitoring is started', Colors.green);
        } else {
          _showSnack('Failed: ${result['error']}', Colors.red);
        }
      }
    }
    await _loadData();
  }

  void _showSnack(String msg, Color color) {
    IconData icon = FluentIcons.info_24_regular;
    if (color == Colors.green) icon = FluentIcons.checkmark_circle_24_regular;
    if (color == Colors.red) icon = FluentIcons.error_circle_24_regular;
    if (color == Colors.orange) icon = FluentIcons.warning_24_regular;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearAllAlerts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content:
            const Text('Are you sure you want to clear the alert history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _detectionService.clearAlerts();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;
        final bg = AppColors.getBackground(t);
        final text = AppColors.getTextPrimary(t);
        final textSec = AppColors.getTextSecondary(t);
        final surface = AppColors.getSurface(t);

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(text, textSec),
                if (_isLoading)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildStatusHero(surface, text, textSec, t, isDark),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Recent Detections',
                                    style:
                                        AppTextStyles.h3.copyWith(color: text)),
                                if (_alerts.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _clearAllAlerts,
                                    icon: const Icon(
                                        FluentIcons.delete_24_regular,
                                        size: 18),
                                    label: const Text('Clear Log'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: textSec),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildAlertsFeed(bg, surface, text, textSec),
                            const SizedBox(height: 40),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color text, Color textSec) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: text.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(FluentIcons.arrow_left_24_regular,
                  size: 20, color: text),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Live Monitor",
                  style: AppTextStyles.h2.copyWith(color: text, height: 1.1)),
              Text("Real-time abuse detection system",
                  style: AppTextStyles.subBody
                      .copyWith(color: textSec, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHero(
      Color surface, Color text, Color textSec, double t, bool isDark) {
    final running = _status.running;
    final activeColor = Colors.greenAccent[400]!;
    final inactiveColor = Colors.grey[400]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
            color: AppColors.interpolate(
                Colors.black.withValues(alpha: 0.05), Colors.white10, t)),
      ),
      child: Column(
        children: [
          // Icon ring
          ScaleTransition(
            scale:
                running ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: running
                    ? activeColor.withValues(alpha: 0.1)
                    : AppColors.interpolate(Colors.grey[100]!,
                        Colors.white.withValues(alpha: 0.05), t),
                border: Border.all(
                  color: running
                      ? activeColor.withValues(alpha: 0.5)
                      : inactiveColor,
                  width: 2,
                ),
              ),
              child: Icon(
                running
                    ? FluentIcons.mic_24_regular
                    : FluentIcons.mic_off_24_regular,
                size: 32,
                color: running ? activeColor : textSec,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            running ? "System Active" : "System Paused",
            style: AppTextStyles.h3.copyWith(color: text),
          ),
          const SizedBox(height: 8),
          Text(
            running
                ? "Listening for abuse and scanning for nudity..."
                : "Monitoring stopped. Press start to resume.",
            style: AppTextStyles.body.copyWith(color: textSec),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _toggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: running ? Colors.redAccent : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                running ? "Stop Monitoring" : "Start Monitoring",
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsFeed(Color bg, Color surface, Color text, Color textSec) {
    if (_alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(FluentIcons.shield_24_regular,
                    size: 48, color: Colors.greenAccent[400]),
              ),
              const SizedBox(height: 24),
              Text("System Secure",
                  style: AppTextStyles.h3.copyWith(color: text)),
              const SizedBox(height: 8),
              Text("No active threats or abusive content detected",
                  style: TextStyle(color: textSec, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return HoverableAlertCard(
          alert: alert,
          surface: surface,
          text: text,
          textSec: textSec,
        );
      },
    );
  }

  // Unused helper removed
}

class HoverableAlertCard extends StatefulWidget {
  final AbuseAlert alert;
  final Color surface;
  final Color text;
  final Color textSec;

  const HoverableAlertCard({
    super.key,
    required this.alert,
    required this.surface,
    required this.text,
    required this.textSec,
  });

  @override
  State<HoverableAlertCard> createState() => _HoverableAlertCardState();
}

class _HoverableAlertCardState extends State<HoverableAlertCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final highRisk = alert.isHighConfidence;
    final riskColor = highRisk ? Colors.redAccent : Colors.orangeAccent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.02),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
          border: Border.all(
            color: _isHovered
                ? riskColor.withValues(alpha: 0.5)
                : Colors
                    .transparent, // Minimal look: no border unless hovered or extremely high risk
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header (Always Visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    highRisk
                        ? FluentIcons.warning_24_regular
                        : FluentIcons.info_24_regular,
                    color: riskColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alert.label.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: widget.text,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    alert.timestamp,
                    style: TextStyle(
                      color: widget.textSec,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            // Expanded Content (Visible on Hover Only)
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      height: 1, color: widget.textSec.withValues(alpha: 0.1)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alert.sentence != null)
                          Text(
                            "\"${alert.sentence}\"",
                            style: TextStyle(
                              fontSize: 15,
                              color: widget.text,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildMiniTag(
                              label:
                                  "${(alert.score * 100).toInt()}% Confidence",
                              color: widget.textSec,
                              bg: widget.textSec.withValues(alpha: 0.1),
                            ),
                            if (alert.matched != null) ...[
                              const SizedBox(width: 8),
                              _buildMiniTag(
                                label: "Detected: ${alert.matched}",
                                color: widget.textSec,
                                bg: widget.textSec.withValues(alpha: 0.1),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              crossFadeState: _isHovered
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(
      {required String label, required Color color, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
