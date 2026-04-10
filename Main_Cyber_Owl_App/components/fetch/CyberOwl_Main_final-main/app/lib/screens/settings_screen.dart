import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/abuse_detection_service.dart';
import '../services/auth_service.dart';
import '../widgets/forgot_code_dialog.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/theme_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _receiverEmailController = TextEditingController();
  final _detectionService = AbuseDetectionService();

  bool _isEmailConfigured = false;
  bool _isSaving = false;
  bool _isServerOnline = false;
  bool _checkingServer = true;

  @override
  void initState() {
    super.initState();
    _loadEmailConfig();
  }

  Future<void> _loadEmailConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // Check server status in parallel
    _checkServerStatus();

    String storedEmail = prefs.getString('alert_email_to') ?? '';

    // Always attempt to fetch the current user's email to ensure the UI matches the logged-in user
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final userMap = await AuthService.getCurrentUser(token);
        print('DEBUG: Settings UserMap: $userMap'); // Debug log

        if (userMap['email'] != null) {
          // Case 1: Unwrapped user object
          storedEmail = userMap['email'];
        } else if (userMap['user'] != null &&
            userMap['user']['email'] != null) {
          // Case 2: Nested user object
          storedEmail = userMap['user']['email'];
        }
      }
    } catch (e) {
      print('Error fetching current user email: $e');
    }

    if (mounted) {
      setState(() {
        _receiverEmailController.text = storedEmail;
        _isEmailConfigured = _receiverEmailController.text.isNotEmpty;

        // Load Offline Mode state
        bool offline = prefs.getBool('is_offline_mode') ?? false;
        AbuseDetectionService.isOfflineMode = offline;
        AuthService.isOfflineMode = offline;
        if (offline) {
          _isServerOnline = true; // Mock online
          _checkingServer = false;
        }
      });
    }
  }

  Future<void> _checkServerStatus() async {
    final isOnline = await _detectionService.checkHealth();
    if (mounted) {
      setState(() {
        _isServerOnline = isOnline;
        _checkingServer = false;
      });
    }
  }

  Future<void> _saveEmailConfig() async {
    if (_receiverEmailController.text.isEmpty) {
      _showSnackBar('Please enter a receiver email',
          isError: true, icon: FluentIcons.warning_24_regular);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'alert_email_to', _receiverEmailController.text.trim());

      // Update email config in Python backend
      final success = await _detectionService.updateEmailConfig(
        receiverEmail: _receiverEmailController.text.trim(),
      );

      setState(() {
        _isEmailConfigured = true;
        _isSaving = false;
      });

      if (success) {
        _showSnackBar(
          'Email configuration updated successfully! Alerts will be sent to ${_receiverEmailController.text.trim()}',
          icon: FluentIcons.checkmark_circle_24_regular,
        );
      } else {
        _showSnackBar(
          'Settings saved locally. Python API may be offline.',
          isError: false,
          icon: FluentIcons.warning_24_regular,
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to save configuration',
          isError: true, icon: FluentIcons.error_circle_24_regular);
    }
  }

  void _showSnackBar(String message, {bool isError = false, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        final textColor = AppColors.getTextPrimary(t);
        final secondaryTextColor = AppColors.getTextSecondary(t);
        final surfaceColor = AppColors.getSurface(t);
        final dividerColor = AppColors.getDivider(t);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Settings',
                style: AppTextStyles.h1.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your Cyber Owl experience',
                style: AppTextStyles.body.copyWith(color: secondaryTextColor),
              ),
              const SizedBox(height: 32),

              // Email Alerts Configuration
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            FluentIcons.mail_24_regular,
                            color: AppColors.accentRed,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Alert Configuration',
                                style:
                                    AppTextStyles.h3.copyWith(color: textColor),
                              ),
                              if (_isEmailConfigured)
                                const Row(
                                  children: [
                                    Icon(FluentIcons.checkmark_circle_24_filled,
                                        color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Configured',
                                      style: TextStyle(
                                          color: Colors.green, fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Configure email to receive alerts when 2+ abuse instances are detected',
                      style: AppTextStyles.body
                          .copyWith(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 24),

                    // Sender Email Input
                    // Receiver Email Input

                    // Receiver Email Input
                    TextField(
                      controller: _receiverEmailController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveEmailConfig(),
                      decoration: InputDecoration(
                        labelText: 'Receiver Email (Who Gets Alerts)',
                        labelStyle: TextStyle(color: secondaryTextColor),
                        hintText: 'alerts@example.com',
                        hintStyle: TextStyle(
                            color: secondaryTextColor.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(FluentIcons.person_24_regular,
                            color: AppColors.accentRed),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.accentRed, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Save Button
                    if (!_isServerOnline && !_checkingServer)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(FluentIcons.warning_24_regular,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Server is offline. Please start monitoring from Live Monitor to enable full configuration saving.',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.orange[200]
                                      : Colors.orange[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isSaving || !_isServerOnline)
                            ? null
                            : _saveEmailConfig,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(FluentIcons.save_24_regular),
                        label: Text(_isSaving
                            ? 'Saving...'
                            : 'Save Email Configuration'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 24),

              // Security Settings Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            FluentIcons.shield_24_regular,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Security',
                          style: AppTextStyles.h3.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(FluentIcons.key_reset_24_regular,
                            color: secondaryTextColor),
                      ),
                      title: Text(
                        'Change Secret Code',
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Update the code used for secure access',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      trailing: Icon(FluentIcons.chevron_right_24_regular,
                          size: 16, color: secondaryTextColor),
                      onTap: () => _showChangeSecretCodeDialog(),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(FluentIcons.password_24_regular,
                            color: secondaryTextColor),
                      ),
                      title: Text(
                        'Change Password',
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Update your login password securely',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      trailing: Icon(FluentIcons.chevron_right_24_regular,
                          size: 16, color: secondaryTextColor),
                      onTap: () => _showChangePasswordDialog(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Theme Settings Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accentPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            FluentIcons.color_24_regular,
                            color: AppColors.accentPurple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Appearance',
                          style: AppTextStyles.h3.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Theme Toggle
                    Text(
                      'Theme',
                      style: AppTextStyles.body.copyWith(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const ThemeSlider(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // System Information Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            FluentIcons.info_24_regular,
                            color: AppColors.accentBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'System Information',
                          style: AppTextStyles.h3.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(
                        FluentIcons.info_24_regular, 'Version', '1.0.0+1',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor),
                    const SizedBox(height: 16),
                    _buildInfoRow(FluentIcons.shield_checkmark_24_regular,
                        'Build', 'Secure-Rel-2025',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor),
                    const SizedBox(height: 16),
                    _buildInfoRow(FluentIcons.arrow_sync_24_regular,
                        'Last Update', 'Dec 20, 2025',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor),
                    const SizedBox(height: 16),
                    _buildInfoRow(FluentIcons.shield_24_regular,
                        'Security Engine', 'Active & Monitoring',
                        textColor: AppColors.primary,
                        secondaryTextColor: secondaryTextColor),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Developer Options Removed for Security
            ],
          ),
        );
      },
    );
  }

  Future<void> _showChangeSecretCodeDialog() async {
    setState(() => _isSaving = true);

    try {
      // 1. Get current user info to find email
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final userMap = await AuthService.getCurrentUser(token);
      final email = userMap['email'] ?? userMap['user']?['email'] ?? '';

      if (email.isEmpty) {
        throw Exception('User email not found');
      }

      // 2. Request OTP
      await AuthService.requestSecretCodeReset(email);

      setState(() => _isSaving = false);

      if (!mounted) return;

      // 3. Show Dialog starting at OTP step
      await showDialog(
        context: context,
        builder: (context) => ForgotSecretCodeDialog(
          initialEmail: email,
          startAtOtp: true,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''),
          isError: true, icon: FluentIcons.error_circle_24_regular);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    setState(() => _isSaving = true);

    try {
      // 1. Get current user info to find email
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final userMap = await AuthService.getCurrentUser(token);
      final email = userMap['email'] ?? userMap['user']?['email'] ?? '';

      if (email.isEmpty) {
        throw Exception('User email not found');
      }

      // 2. Request OTP
      await AuthService.requestPasswordReset(email);

      setState(() => _isSaving = false);

      if (!mounted) return;

      // 3. Show Dialog starting at OTP step
      await showDialog(
        context: context,
        builder: (context) => ForgotPasswordDialog(
          initialEmail: email,
          startAtOtp: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(e.toString().replaceAll('Exception: ', ''),
            isError: true, icon: FluentIcons.error_circle_24_regular);
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {required Color textColor, required Color secondaryTextColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: secondaryTextColor),
        const SizedBox(width: 12),
        Text(label,
            style: AppTextStyles.subBody.copyWith(color: secondaryTextColor)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _receiverEmailController.dispose();
    _detectionService.dispose();
    super.dispose();
  }
}
