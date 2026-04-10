import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../models/sidebar_item.dart';
import 'toxi_guard_logo.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Function(bool)? onHoverChanged;
  final bool isLiveMonitorEnabled;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onHoverChanged,
    this.isLiveMonitorEnabled = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  // Reduced collapsed width for sleek look, expanded for full content
  final double _collapsedWidth = 88.0;
  final double _expandedWidth = 280.0;

  final List<SidebarItem> _mainItems = [
    const SidebarItem(
        icon: FluentIcons.grid_24_regular,
        title: 'Dashboard',
        color: AppColors.primaryBlue),
    const SidebarItem(
        icon: FluentIcons.gavel_24_regular,
        title: 'Rules',
        color: AppColors.accentTeal),
    const SidebarItem(
        icon: FluentIcons.history_24_regular,
        title: 'History',
        color: AppColors.primaryBlue),
    const SidebarItem(
        icon: FluentIcons.pulse_24_regular,
        title: 'Live Monitor',
        color: AppColors.errorDark),
    const SidebarItem(
        icon: FluentIcons.person_24_regular,
        title: 'Profile',
        color: AppColors.primaryPurple),
    const SidebarItem(
        icon: FluentIcons.settings_24_regular,
        title: 'Settings',
        color: AppColors.accentTeal),
    const SidebarItem(
        icon: FluentIcons.info_24_regular,
        title: 'About',
        color: AppColors.accentCyan),
  ];

  final List<SidebarItem> _bottomItems = [
    const SidebarItem(
        icon: FluentIcons.sign_out_24_regular,
        title: 'Logout',
        color: AppColors.errorDark),
  ];

  @override
  Widget build(BuildContext context) {
    // Get continuous theme value
    final t = themeManager.themeValue;
    final isDark = themeManager.isDark;

    final sidebarBg = AppColors.getSidebarBackground(t);
    final textColor = AppColors.getTextPrimary(t);
    final secondaryTextColor = AppColors.getTextSecondary(t);
    final dividerColor = AppColors.getDivider(t);

    // Prominent equal spacing for all elements
    const double itemSpacing = 25.0;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isExpanded = true);
        widget.onHoverChanged?.call(true);
      },
      onExit: (_) {
        setState(() => _isExpanded = false);
        widget.onHoverChanged?.call(false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
        width: _isExpanded ? _expandedWidth : _collapsedWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: sidebarBg,
          border: Border(
            right: BorderSide(
                color: dividerColor.withValues(alpha: 0.5), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            _buildHeader(textColor, constraints),
                      ),
                      const SizedBox(
                          height: itemSpacing), // Equal spacing after logo
                      ..._mainItems.asMap().entries.expand(
                            (e) => [
                              _buildMenuItem(e.value,
                                  index: e.key,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  isDark: isDark,
                                  t: t,
                                  isDisabled: e.key == 3 &&
                                      !widget.isLiveMonitorEnabled),
                              if (e.key < _mainItems.length - 1)
                                const SizedBox(
                                    height:
                                        itemSpacing), // Equal spacing between items
                            ],
                          ),
                      const SizedBox(
                          height:
                              itemSpacing), // Equal spacing before bottom items
                      ..._bottomItems.asMap().entries.map((e) => _buildMenuItem(
                          e.value,
                          index: _mainItems.length + e.key,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          isDark: isDark,
                          t: t)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(SidebarItem item,
      {required int index,
      required Color textColor,
      required Color secondaryTextColor,
      required bool isDark,
      required double t,
      bool isDisabled = false}) {
    // Accept isDark and t
    final bool isSelected = widget.selectedIndex == index;
    final Color itemColor = item.color ?? AppColors.primaryPurple;
    final Color iconColor =
        isDisabled ? secondaryTextColor.withValues(alpha: 0.4) : itemColor;

    // Adjusted width to prevent overflow
    const double iconBoxWidth = 60.0;

    return Container(
      margin:
          const EdgeInsets.symmetric(vertical: 2), // Tighter vertical margin
      padding: const EdgeInsets.symmetric(
          horizontal: 8), // Tighter horizontal padding
      child: GestureDetector(
        onTap: isDisabled ? null : () => widget.onItemSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected && !isDisabled
                ? itemColor.withValues(
                    alpha: AppColors.interpolate(
                            const Color(0x26000000), const Color(0x14000000), t)
                        .a) // Interpolate opacity
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Fixed width container for icon - does not animate
              SizedBox(
                width: iconBoxWidth,
                child: Center(
                  child: Icon(item.icon, color: iconColor, size: 24),
                ),
              ),
              // Expandable text area
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  curve: Curves.easeInOut,
                  child: Text(
                    item.title,
                    style: AppTextStyles.body.copyWith(
                      color: isDisabled
                          ? secondaryTextColor.withValues(alpha: 0.4)
                          : isSelected
                              ? AppColors.interpolate(Colors.white, itemColor,
                                  t) // White (dark) -> Color (light)
                              : secondaryTextColor,
                      fontWeight: isSelected && !isDisabled
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, BoxConstraints constraints) {
    // Dynamic logo size based on expansion
    const double logoSize = 60.0;
    // Must match iconBoxWidth in _buildMenuItem
    const double iconBoxWidth = 60.0;

    return Container(
      padding: const EdgeInsets.only(left: 12), // Shifted right slightly
      child: Row(
        children: [
          const SizedBox(
            width: iconBoxWidth, // Consistent width with menu items
            child: Center(
              child: SizedBox(
                width: iconBoxWidth,
                height: iconBoxWidth,
                child: OverflowBox(
                  maxWidth: logoSize,
                  maxHeight: logoSize,
                  minWidth: logoSize,
                  minHeight: logoSize,
                  alignment: Alignment.center,
                  child: ToxiGuardLogo(size: logoSize, animate: false),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isExpanded ? 1.0 : 0.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CYBER OWL',
                    style: AppTextStyles.h3.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 18,
                    ),
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  Text(
                    'The silent eyes\nthat capture',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    softWrap: false,
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
