import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../services/abuse_detection_service.dart';
import 'login_screen.dart';

class SystemAccountScreen extends StatefulWidget {
  const SystemAccountScreen({super.key});

  @override
  State<SystemAccountScreen> createState() => _SystemAccountScreenState();
}

class _SystemAccountScreenState extends State<SystemAccountScreen> {
  final AbuseDetectionService _detectionService = AbuseDetectionService();

  // Secret Code Schedule State
  bool _isLoadingSchedule = false;
  bool _scheduleIsActive = false;
  String _scheduleFrequency = 'daily';
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 0, minute: 0);
  int _scheduleDayOfWeek = 0; // 0=Monday

  @override
  void initState() {
    super.initState();
    _fetchSecretCodeSchedule();
  }

  Future<void> _fetchSecretCodeSchedule() async {
    setState(() => _isLoadingSchedule = true);
    try {
      final schedule = await AuthService.getSecretCodeSchedule();
      if (mounted) {
        setState(() {
          _scheduleIsActive = schedule['is_active'] ?? false;
          _scheduleFrequency = schedule['frequency'] ?? 'daily';
          _scheduleDayOfWeek = schedule['day_of_week'] ?? 0;

          final timeStr = schedule['rotation_time'] ?? '00:00';
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            _scheduleTime = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      }
    } catch (e) {
      print('Failed to fetch schedule: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  Future<void> _saveSecretCodeSchedule() async {
    setState(() => _isLoadingSchedule = true);
    try {
      final timeStr =
          '${_scheduleTime.hour.toString().padLeft(2, '0')}:${_scheduleTime.minute.toString().padLeft(2, '0')}';

      await AuthService.setSecretCodeSchedule(
        frequency: _scheduleFrequency,
        rotationTime: timeStr,
        dayOfWeek: _scheduleDayOfWeek,
        isActive: _scheduleIsActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Rotation schedule updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: themeManager,
        builder: (context, _) {
          final t = themeManager.themeValue;
          // Using a transparent/neutral background for the screen, assumed handled by parent or standard background

          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              // Main Screen Column
              children: [
                // Header
                Text(
                  'System & Account',
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.getTextPrimary(t),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // Content Row
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LEFT COLUMN: Profile Card
                      SizedBox(
                        width: 320,
                        child: _buildProfileCard(t),
                      ),
                      const SizedBox(width: 32),

                      // RIGHT COLUMN: System Info & Actions
                      SizedBox(
                        width: 450,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildSystemInfoCard(t),
                              const SizedBox(height: 24),
                              _buildSecretCodeScheduleCard(t),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildActionButton(
                                          icon:
                                              FluentIcons.arrow_sync_24_regular,
                                          label: "Check Updates",
                                          color: Colors.blueAccent,
                                          t: t)),
                                  const SizedBox(width: 24),
                                  Expanded(
                                      child: _buildActionButton(
                                          icon: FluentIcons
                                              .question_circle_24_regular,
                                          label: "Get Support",
                                          color: Colors.purpleAccent,
                                          t: t)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSignOutButton(t),
                              const SizedBox(height: 16),
                              // _buildDeleteAccountButton(isDark), // Removed for security
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }

  // ... (rest of the file until _handleLogout)

  Widget _buildProfileCard(double t) {
    return FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.getLocalUser(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          final name = userData?['name'] ?? 'Guest User';
          final email = userData?['email'] ?? 'guest@example.com';
          var photoUrl = userData?['photo_url'] ?? userData?['profile_pic'];
          String? displayUrl;
          if (photoUrl != null && photoUrl.toString().isNotEmpty) {
            String p = photoUrl.toString();
            if (p.startsWith('http')) {
              displayUrl = p;
            } else {
              if (p.contains(r'\')) p = p.split(r'\').last;
              if (p.contains('/')) p = p.split('/').last;
              displayUrl =
                  '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$p';
            }
          }

          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.getSurface(t),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accentBlue.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        displayUrl != null ? NetworkImage(displayUrl) : null,
                    backgroundColor: AppColors.getBackground(t),
                    child: photoUrl == null
                        ? Icon(FluentIcons.person_24_regular,
                            size: 50, color: AppColors.getTextSecondary(t))
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.getTextPrimary(t),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.getTextSecondary(t),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.checkmark_starburst_24_regular,
                          size: 16, color: AppColors.accentGreen),
                      SizedBox(width: 8),
                      Text(
                        'Active License',
                        style: TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
  }

  Widget _buildSystemInfoCard(double t) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.getSurface(t),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getDivider(t).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Information',
            style: TextStyle(
              color: AppColors.getTextSecondary(t),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
              FluentIcons.laptop_24_regular, 'Platform', 'Windows 11', t),
          const SizedBox(height: 16),
          _buildInfoRow(FluentIcons.server_24_regular, 'Version',
              '1.0.0 (Build 2025)', t),
          const SizedBox(height: 16),
          StreamBuilder<MonitoringStatus>(
              stream: _detectionService.statusStream,
              builder: (context, snapshot) {
                final isRunning = snapshot.data?.running ?? false;
                return _buildInfoRow(
                    FluentIcons.shield_24_regular,
                    'Security Engine',
                    isRunning ? 'Active & Monitoring' : 'Inactive (Idle)',
                    t,
                    valueColor:
                        isRunning ? AppColors.accentBlue : AppColors.accentRed);
              }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, double t,
      {Color? valueColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.getTextSecondary(t).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.getTextSecondary(t)),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextSecondary(t),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.getTextPrimary(t),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required double t}) {
    return Container(
      height: 80, // Taller button style
      decoration: BoxDecoration(
        color: color, // Opaque
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24), // White icon
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white, // White text
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(double t) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentRed, // Opaque
          foregroundColor: Colors.white, // White Text
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.sign_out_24_regular),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Always require secret code for logout
    if (!mounted) return;
    _showSecureLogoutDialog();
  }

  Future<void> _performLogout(String? secretCode) async {
    try {
      if (secretCode != null) {
        // Stop monitoring if running, or just verify code
        await _detectionService.stopMonitoring(
            secretCode: secretCode, forceStop: false, reason: 'logout');
      } else {
        await _detectionService.stopMonitoring(
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showSecureLogoutDialog() {
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
                'For security, please enter your Secret Code to logout.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: secretCodeController,
                obscureText: true,
                autofocus: true,
                onSubmitted: isProcessing
                    ? null
                    : (value) async {
                        if (secretCodeController.text.isEmpty) return;
                        setState(() => isProcessing = true);

                        // Verify code by attempting to stop monitoring
                        final result = await _detectionService.stopMonitoring(
                            secretCode: secretCodeController.text,
                            reason: 'logout');

                        if (result['success'] == true) {
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            // Proceed to actual logout
                            _performLogout(secretCodeController.text);
                          }
                        } else {
                          setState(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(result['error'] ??
                                      'Invalid Secret Code')),
                            );
                          }
                        }
                      },
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
                      final result = await _detectionService.stopMonitoring(
                          secretCode: secretCodeController.text,
                          reason: 'logout');

                      if (result['success'] == true) {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          // Proceed to actual logout
                          _performLogout(secretCodeController.text);
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

  Widget _buildSecretCodeScheduleCard(double t) {
    if (_isLoadingSchedule) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.getSurface(t),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getDivider(t).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.arrow_repeat_all_24_regular,
                  color: AppColors.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Auto-Rotate Secret Code',
                style: TextStyle(
                  color: AppColors.getTextSecondary(t),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Switch(
                value: _scheduleIsActive,
                activeThumbColor: AppColors.accentBlue,
                onChanged: (val) {
                  setState(() => _scheduleIsActive = val);
                  _saveSecretCodeSchedule();
                },
              ),
            ],
          ),
          if (_scheduleIsActive) ...[
            const SizedBox(height: 24),

            // Frequency Dropdown
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency',
                          style: TextStyle(
                              color: AppColors.getTextSecondary(t),
                              fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(t),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.getDivider(t)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _scheduleFrequency,
                            isExpanded: true,
                            dropdownColor: AppColors.getSurface(t),
                            items: const [
                              DropdownMenuItem(
                                  value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(
                                  value: 'weekly', child: Text('Weekly')),
                            ],
                            onChanged: (val) {
                              setState(() => _scheduleFrequency = val!);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Time Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Time',
                          style: TextStyle(
                              color: AppColors.getTextSecondary(t),
                              fontSize: 12)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _scheduleTime,
                          );
                          if (time != null) {
                            setState(() => _scheduleTime = time);
                          }
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.getBackground(t),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.getDivider(t)),
                          ),
                          child: Text(
                            _scheduleTime.format(context),
                            style:
                                TextStyle(color: AppColors.getTextPrimary(t)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_scheduleFrequency == 'weekly') ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day of Week',
                      style: TextStyle(
                          color: AppColors.getTextSecondary(t), fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getBackground(t),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getDivider(t)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _scheduleDayOfWeek,
                        isExpanded: true,
                        dropdownColor: AppColors.getSurface(t),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Monday')),
                          DropdownMenuItem(value: 1, child: Text('Tuesday')),
                          DropdownMenuItem(value: 2, child: Text('Wednesday')),
                          DropdownMenuItem(value: 3, child: Text('Thursday')),
                          DropdownMenuItem(value: 4, child: Text('Friday')),
                          DropdownMenuItem(value: 5, child: Text('Saturday')),
                          DropdownMenuItem(value: 6, child: Text('Sunday')),
                        ],
                        onChanged: (val) {
                          setState(() => _scheduleDayOfWeek = val!);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveSecretCodeSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Schedule',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
