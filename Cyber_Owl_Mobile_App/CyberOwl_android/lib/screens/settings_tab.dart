import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Unused

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 16,
            vertical: 16,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header
                Text(
                  'Settings',
                  style: AppTextStyles.heading1
                      .copyWith(color: theme.textTheme.headlineLarge?.color),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your preferences',
                  style: AppTextStyles.body
                      .copyWith(color: theme.textTheme.bodyMedium?.color),
                ),

                const SizedBox(height: 24),

                // Account
                _SettingsSection(
                  icon: FluentIcons.person_24_regular,
                  iconColor: AppColors.primaryPurple,
                  title: 'Account',
                  children: [
                    _SettingsArrowRow(
                      label: 'My Profile',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Security (Pro Feature)
                _SettingsSection(
                  icon: FluentIcons.shield_lock_24_regular,
                  iconColor: AppColors.primary,
                  title: 'Security',
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Biometric 3FA',
                          style: AppTextStyles.body.copyWith(
                              color: theme.textTheme.bodyMedium?.color),
                        ),
                        Switch(
                          value: provider.biometricEnabled,
                          onChanged: (val) => provider.toggleBiometric(val),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Require face/fingerprint for PC access and login',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Connection Status
                _SettingsSection(
                  icon: FluentIcons.wifi_1_24_regular,
                  iconColor: AppColors.success,
                  title: 'Connection',
                  children: [
                    _SettingsRow(
                      label: 'Server',
                      value: AppConstants.apiBaseUrl.isNotEmpty
                          ? AppConstants.apiBaseUrl
                          : 'Not connected',
                    ),
                    _SettingsRow(
                      label: 'Status',
                      value:
                          provider.isConnected ? 'Connected' : 'Disconnected',
                      valueColor: provider.isConnected
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    _SettingsRow(
                      label: 'Discovery',
                      value: 'Auto (UDP)',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Appearance (NEW)
                _SettingsSection(
                  icon: FluentIcons.color_24_regular,
                  iconColor: AppColors.secondary,
                  title: 'Appearance',
                  children: [
                    _ThemeSelector(provider: provider),
                  ],
                ),

                const SizedBox(height: 16),

                // Notifications
                _SettingsSection(
                  icon: FluentIcons.alert_24_regular,
                  iconColor: AppColors.primary,
                  title: 'Notifications',
                  children: [
                    _SettingsRow(
                      label: 'Push Notifications',
                      value: 'Enabled',
                      valueColor: AppColors.success,
                    ),
                    _SettingsRow(
                      label: 'Detection Alerts',
                      value: 'On',
                    ),
                    _SettingsRow(
                      label: 'Status Updates',
                      value: 'On',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // About
                _SettingsSection(
                  icon: FluentIcons.info_24_regular,
                  iconColor: AppColors.warning,
                  title: 'About',
                  children: [
                    _SettingsRow(
                      label: 'App Version',
                      value: AppConstants.appVersion,
                    ),
                    _SettingsRow(
                      label: 'App Name',
                      value: AppConstants.appName,
                    ),
                    _LinkRow(
                      icon: FluentIcons.code_24_regular,
                      label: 'View on GitHub',
                      onTap: () => _launchUrl(
                          'https://github.com/Muhammadsaqlain-n1/Main_Cyber_Owl_App'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.danger.withValues(alpha: 0.15),
                          AppColors.danger.withValues(alpha: 0.05)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmLogout(context, provider),
                      icon: const Icon(FluentIcons.sign_out_24_regular,
                          color: AppColors.danger),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout?',
            style: TextStyle(
                color: Theme.of(context).textTheme.headlineSmall?.color)),
        content: Text(
          'Are you sure you want to logout?',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url');
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.heading3
                    .copyWith(color: theme.textTheme.titleLarge?.color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SettingsRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body
                .copyWith(color: theme.textTheme.bodyMedium?.color),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: theme.textTheme.bodySmall?.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body
                    .copyWith(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            Icon(FluentIcons.open_24_regular,
                color: theme.textTheme.bodySmall?.color, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final AppProvider provider;

  const _ThemeSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Theme Mode',
          style: AppTextStyles.body
              .copyWith(color: theme.textTheme.bodyMedium?.color),
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeOption(
                icon: FluentIcons.weather_partly_cloudy_day_24_regular,
                isSelected: provider.themeMode == ThemeMode.system,
                onTap: () => provider.setThemeMode(ThemeMode.system),
              ),
              _ThemeOption(
                icon: FluentIcons.weather_sunny_24_regular,
                isSelected: provider.themeMode == ThemeMode.light,
                onTap: () => provider.setThemeMode(ThemeMode.light),
              ),
              _ThemeOption(
                icon: FluentIcons.weather_moon_24_regular,
                isSelected: provider.themeMode == ThemeMode.dark,
                onTap: () => provider.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? Colors.white
              : Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _SettingsArrowRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SettingsArrowRow({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.body
                  .copyWith(color: theme.textTheme.bodyMedium?.color),
            ),
            Icon(FluentIcons.chevron_right_24_regular,
                color: theme.textTheme.bodySmall?.color, size: 20),
          ],
        ),
      ),
    );
  }
}
