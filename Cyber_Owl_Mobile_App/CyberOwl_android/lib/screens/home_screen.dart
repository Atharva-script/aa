import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'dashboard_tab.dart';
import 'monitoring_tab.dart';
import 'server_tab.dart';
import 'settings_tab.dart';
import 'package:flutter/scheduler.dart'; // Added
import 'children_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isDialogShowing = false;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const ChildrenTab(),
    const MonitoringTab(),
    const ServerTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();

    // Check for pending requests
    if (provider.hasPendingRequests && !_isDialogShowing) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDialogShowing && provider.hasPendingRequests) {
          _showRequestDialog(context, provider.pendingRequests.first);
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.backgroundGradient
              : AppColors.backgroundGradientLight,
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, // or surface
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: FluentIcons.home_24_regular,
                  label: 'Home',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                  theme: theme,
                ),
                _NavItem(
                  icon: FluentIcons.people_24_regular,
                  label: 'Children',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                  theme: theme,
                ),
                _NavItem(
                  icon: FluentIcons.shield_24_regular,
                  label: 'Control',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                  theme: theme,
                ),
                _NavItem(
                  icon: FluentIcons.server_24_regular,
                  label: 'Server',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                  theme: theme,
                ),
                _NavItem(
                  icon: FluentIcons.settings_24_regular,
                  label: 'Settings',
                  isActive: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRequestDialog(BuildContext context, Map<String, dynamic> request) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(FluentIcons.shield_lock_24_regular,
                color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('PC Access Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A PC is requesting remote access.'),
            const SizedBox(height: 12),
            _InfoRow(
                label: 'Device:',
                value: request['device_info'] ?? 'Unknown PC'),
            _InfoRow(label: 'Time:', value: _formatTime(request['created_at'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Deny
              await context
                  .read<AppProvider>()
                  .rejectPcRequest(request['request_id']);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child:
                const Text('Deny', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Approve
              final success = await context
                  .read<AppProvider>()
                  .approvePcRequest(request['request_id']);

              if (!mounted) return;

              if (success && ctx.mounted) {
                Navigator.pop(ctx);
              } else if (!success && context.mounted) {
                // Biometric failed or API error
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Verification Failed'),
                  backgroundColor: AppColors.danger,
                ));
              }
            },
            icon: const Icon(FluentIcons.fingerprint_24_regular),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ).then((_) => _isDialogShowing = false);
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final unselectedColor =
        isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : unselectedColor,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : unselectedColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
