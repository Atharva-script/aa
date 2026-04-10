import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

import '../theme/theme_manager.dart';
import '../widgets/sidebar.dart';

import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'rules_screen.dart';
import 'profile_screen.dart';
import 'live_monitor_screen.dart';
import 'about_screen.dart';
import 'history_screen.dart';

import 'system_account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSidebarHovered = false;
  bool _dashboardReady = false;

  void _onItemSelected(int index) {
    // Block Live Monitor (index 3) until dashboard is ready
    if (index == 3 && !_dashboardReady) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (_selectedIndex < 6) _onItemSelected(_selectedIndex + 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (_selectedIndex > 0) _onItemSelected(_selectedIndex - 1);
        },
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: themeManager,
          builder: (context, _) {
            final t = themeManager.themeValue;

            final backgroundColor = AppColors.getBackground(t);

            return Scaffold(
              backgroundColor: backgroundColor,
              body: Stack(
                children: [
                  // ... (keep stack content)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubicEmphasized,
                    margin: const EdgeInsets.only(
                        left: 88), // Fixed margin: Collapsed Width
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeInQuart,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _buildScreen(_selectedIndex),
                      ),
                    ),
                  ),

                  // 2. Sidebar (Top Layer for Shadow)
                  Sidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onItemSelected,
                    onHoverChanged: (isExpanded) {
                      setState(() => _isSidebarHovered = isExpanded);
                    },
                    isLiveMonitorEnabled: _dashboardReady,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: // Dashboard
        return DashboardScreen(
          isExpanded: _isSidebarHovered,
          onViewHistory: () => _onItemSelected(2),
          onNavigateToProfile: () => _onItemSelected(4), // Jump to Profile
          onNavigationRequest: _onItemSelected,
          onDashboardReady: () {
            if (!_dashboardReady) setState(() => _dashboardReady = true);
          },
        );
      case 1: // Rules
        return const RulesScreen();
      case 2: // History
        return HistoryScreen(isExpanded: _isSidebarHovered);
      case 3: // Live Monitor
        return LiveMonitorScreen(
          monitorType: 'main',
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 4: // Profile
        return const ProfileScreen();
      case 5: // Settings
        return const SettingsScreen();
      case 6: // About
        return const AboutScreen();
      case 7: // System/Logout
        return const SystemAccountScreen();

      // Hidden/Submenu Items
      case 20:
        return LiveMonitorScreen(
          monitorType: 'main',
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 21:
        return LiveMonitorScreen(
          monitorType: 'abuse',
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 22:
        return LiveMonitorScreen(
          monitorType: 'nudity',
          onBack: () => setState(() => _selectedIndex = 0),
        );
      default:
        return const Center(child: Text("Page not found"));
    }
  }
}
