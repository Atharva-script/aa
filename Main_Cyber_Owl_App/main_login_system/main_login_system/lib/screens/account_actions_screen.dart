import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:async';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../services/abuse_detection_service.dart';
import 'login_screen.dart';

class AccountActionsScreen extends StatefulWidget {
  const AccountActionsScreen({super.key});

  @override
  State<AccountActionsScreen> createState() => _AccountActionsScreenState();
}

class _AccountActionsScreenState extends State<AccountActionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Map<String, dynamic>? _userData;

  Duration _sessionDuration = Duration.zero;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _loadUserData();
    _startSessionTimer();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionDuration += const Duration(minutes: 1);
        });
      }
    });
    // Mock session start (random 10-60m ago)
    _sessionDuration = const Duration(minutes: 24);
  }

  Future<void> _loadUserData() async {
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final data = await AuthService.getCurrentUser(token);
        if (mounted) {
          setState(() {
            _userData = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Check Account Status Error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final detectionService = AbuseDetectionService();

    // Check monitoring status first
    final status = await detectionService.getStatus();

    if (status.running) {
      if (!mounted) return;
      _showSecureLogoutDialog(detectionService);
    } else {
      _performLogout(detectionService, null);
    }
  }

  Future<void> _performLogout(
      AbuseDetectionService detectionService, String? secretCode) async {
    try {
      if (secretCode != null) {
        // Stop with secret code and reason 'logout'
        await detectionService.stopMonitoring(
            secretCode: secretCode, forceStop: false, reason: 'logout');
      } else {
        // Just force stop if not secure (though logic implies force stop only if not running, which is redundant but safe)
        await detectionService.stopMonitoring(
            forceStop: true, reason: 'logout');
      }

      final token = await AuthService.getToken();
      if (token != null) {
        await AuthService.logout(token);
      } else {
        await AuthService.clearUser();
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Even if error, force to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showSecureLogoutDialog(AbuseDetectionService detectionService) {
    final secretCodeController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getSurface(themeManager.themeValue),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(FluentIcons.shield_24_regular, color: AppColors.accentRed),
              SizedBox(width: 10),
              Text('Secure Logout',
                  style: TextStyle(color: AppColors.accentRed)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Monitoring is active. You must enter your Secret Code to logout.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: secretCodeController,
                obscureText: true,
                style: TextStyle(
                    color: AppColors.getTextPrimary(themeManager.themeValue)),
                decoration: const InputDecoration(
                  labelText: 'Secret Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (secretCodeController.text.isEmpty) return;
                      setState(() => isProcessing = true);

                      // Verify code by attempting to stop monitoring
                      final result = await detectionService.stopMonitoring(
                          secretCode: secretCodeController.text,
                          reason: 'logout');

                      if (result['success'] == true) {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          // Proceed to actual logout
                          _performLogout(
                              detectionService, secretCodeController.text);
                        }
                      } else {
                        setState(() => isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    result['error'] ?? 'Invalid Secret Code')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationWithSecretCode() {
    final secretCodeController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getSurface(themeManager.themeValue),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(FluentIcons.warning_24_regular, color: AppColors.accentRed),
              SizedBox(width: 10),
              Text('Permanent Deletion',
                  style: TextStyle(color: AppColors.accentRed)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is irreversible. Your account and all data will be permanently deleted.\n\nEnter your Secret Code to confirm.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: secretCodeController,
                obscureText: true,
                style: TextStyle(
                    color: AppColors.getTextPrimary(themeManager.themeValue)),
                decoration: const InputDecoration(
                  labelText: 'Secret Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (secretCodeController.text.isEmpty) return;
                      setState(() => isProcessing = true);
                      try {
                        await AuthService.deleteAccount(
                            secretCodeController.text);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        setState(() => isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(e
                                    .toString()
                                    .replaceAll('Exception: ', ''))),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;
        final bg = AppColors.getBackground(t);
        final surface = AppColors.getSurface(t);
        final text = AppColors.getTextPrimary(t);
        final textSec = AppColors.getTextSecondary(t);

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              // Ambient Background Glow
              Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          blurRadius: 100,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  )),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Text(
                          'Control Center',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 32,
                            color: text,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your session and system security',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subBody.copyWith(color: textSec),
                        ),
                        const SizedBox(height: 40),

                        // USER PROFILE CARD
                        _buildUserCard(t, isDark, surface, text, textSec),
                        const SizedBox(height: 24),

                        // SYSTEM STATUS CARD
                        _buildSystemStatusCard(
                            t, isDark, surface, text, textSec),
                        const SizedBox(height: 40),

                        // LOGOUT ACTION
                        _buildLogoutSlider(isDark),

                        const SizedBox(height: 24),
                        // DELETE ACCOUNT
                        Center(
                          child: TextButton.icon(
                            onPressed: _showDeleteConfirmationWithSecretCode,
                            icon: Icon(FluentIcons.delete_24_regular,
                                color:
                                    AppColors.accentRed.withValues(alpha: 0.7),
                                size: 18),
                            label: Text('Delete Account Permanently',
                                style: TextStyle(
                                    color: AppColors.accentRed
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Cyber Owl Defense System v1.0.0',
                            style: TextStyle(
                                color: textSec.withValues(alpha: 0.4),
                                fontSize: 11),
                          ),
                        )
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

  Widget _buildUserCard(
      double t, bool isDark, Color surface, Color text, Color textSec) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10)
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.getBackground(t),
              backgroundImage: _userData?['profile_pic'] != null
                  ? NetworkImage(_userData!['profile_pic']
                              .toString()
                              .startsWith('http')
                          ? _userData!['profile_pic'] // Remote
                          : '${AuthService.baseUrl.replaceAll('/api', '')}/${_userData!['profile_pic']}') // Local
                      as ImageProvider
                  : null,
              child: _userData?['profile_pic'] == null
                  ? Icon(FluentIcons.person_24_regular, color: textSec)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['name'] ?? 'Loading...',
                  style: AppTextStyles.h2.copyWith(color: text, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _userData?['email'] ?? '',
                  style: AppTextStyles.subBody
                      .copyWith(color: textSec, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PROTECTOR ADMIN',
                      style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard(
      double t, bool isDark, Color surface, Color text, Color textSec) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.6),
                              blurRadius: 8 * _pulseController.value,
                              spreadRadius: 2 * _pulseController.value,
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text('System Operational',
                      style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ],
              ),
              Icon(FluentIcons.checkmark_circle_24_regular,
                  color: Colors.green.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _buildMiniStat(
                      'Session',
                      '${_sessionDuration.inHours}h ${_sessionDuration.inMinutes % 60}m',
                      FluentIcons.timer_24_regular,
                      AppColors.accentPurple,
                      t)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildMiniStat('Shield', 'Active',
                      FluentIcons.shield_24_regular, AppColors.accentBlue, t)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildMiniStat('Region', 'IND',
                      FluentIcons.globe_24_regular, AppColors.accentAmber, t)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String label, String value, IconData icon, Color color, double t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: AppColors.getTextPrimary(t),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(label,
              style: TextStyle(
                  color: AppColors.getTextSecondary(t), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLogoutSlider(bool isDark) {
    return GestureDetector(
      onTap: _handleLogout,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentRed, Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.power_24_regular, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'SIGN OUT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
