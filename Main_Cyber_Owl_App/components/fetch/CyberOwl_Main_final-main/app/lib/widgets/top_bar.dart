import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:async';
import '../services/abuse_detection_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../screens/profile_screen.dart';
import '../data/search_registry.dart';

class TopBar extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback? onProfileTap;
  final Function(int)? onNavigateTo;

  const TopBar({
    super.key,
    this.isExpanded = false,
    this.onProfileTap,
    this.onNavigateTo,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with TickerProviderStateMixin {
  late AnimationController _gradientController;
  AnimationController? _spinController;
  late Animation<double> _gradientAnimation;

  // User Data
  String? _userName;
  String? _userPhotoUrl;
  bool _isActive = false;
  bool _isBackendConnected = true;
  Timer? _statusTimer;
  StreamSubscription<bool>? _connectionSub;

  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 1. Setup Gradient Animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _gradientAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);

    // 2. Fetch User Status
    _checkUserStatus();

    // 3. Listen to Backend Connection Status
    _isBackendConnected = AbuseDetectionService().isServerHealthy;
    _connectionSub =
        AbuseDetectionService().connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isBackendConnected = connected);
        if (connected) _checkUserStatus(); // Retry user status if reconnected
      }
    });

    // Poll status every 30 seconds
    _statusTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _checkUserStatus());
  }

  Future<void> _checkUserStatus() async {
    try {
      // 1. Try Local/Memory Check First (Instant Update)
      final localUser = await AuthService.getLocalUser();
      if (localUser != null && mounted) {
        setState(() {
          String rawName = localUser['name'] ?? 'User';
          _userName = rawName
              .split(' ')
              .map((str) => str.isNotEmpty
                  ? '${str[0].toUpperCase()}${str.substring(1)}'
                  : '')
              .join(' ');

          final pic = localUser['photo_url'] ?? localUser['profile_pic'];
          if (pic != null && pic.toString().isNotEmpty) {
            _userPhotoUrl = pic.toString().startsWith('http')
                ? pic
                : '${AuthService.baseUrl.replaceAll('/api', '')}/$pic';
          }
          _isActive = true;
        });
      }

      // 2. Fetch Fresh from Server
      final token = await AuthService.getToken();
      if (token != null) {
        final user = await AuthService.getCurrentUser(token);
        if (mounted) {
          setState(() {
            String rawName = user['name'] ?? 'User';
            _userName = rawName
                .split(' ')
                .map((str) => str.isNotEmpty
                    ? '${str[0].toUpperCase()}${str.substring(1)}'
                    : '')
                .join(' ');

            final pic = user['photo_url'] ?? user['profile_pic'];
            if (pic != null && pic.toString().isNotEmpty) {
              String picStr = pic.toString();
              if (picStr.startsWith('http')) {
                _userPhotoUrl = picStr;
              } else {
                // Sanitize local path artifacts if present
                if (picStr.contains(r'\')) picStr = picStr.split(r'\').last;
                if (picStr.contains('/')) picStr = picStr.split('/').last;
                _userPhotoUrl =
                    '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$picStr';
              }
            } else {
              _userPhotoUrl = null;
            }
            _isActive = true;
          });
        }
      } else {
        if (mounted) setState(() => _isActive = false);
      }
    } catch (e) {
      debugPrint('TopBar User Status Check Error: $e');
      // If we already have local data, don't set inactive just because server check failed
      if (_userName == null && mounted) {
        setState(() => _isActive = false);
      }
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _spinController?.dispose();
    _statusTimer?.cancel();
    _connectionSub?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = themeManager.themeValue;
    final isMobile = MediaQuery.of(context).size.width < 800;

    _spinController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    final topBarBg = AppColors.getSidebarBackground(t);
    final textColor = AppColors.getTextPrimary(t);
    final secondaryTextColor = AppColors.getTextSecondary(t);
    final surfaceColor = AppColors.getSurface(t);

    // Search box border: Theme-aware colors
    final searchBorderColor = AppColors.getBorder(t).withValues(alpha: 0.8);
    final searchBg = AppColors.getSurface(t);

    return AnimatedBuilder(
      animation: Listenable.merge([_gradientController, _spinController!]),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 80,
          padding: const EdgeInsets.fromLTRB(
              4, 25, 20, 8), // Increased top padding for alignment
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                topBarBg.withValues(alpha: 0.9),
                topBarBg.withValues(alpha: 0.95),
                topBarBg.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5 + (_gradientAnimation.value * 0.1), 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                  color: AppColors.accentBlue.withValues(alpha: 0.1), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search Bar - Aligned to extreme left
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  return Autocomplete<SearchResult>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<SearchResult>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return appSearchRegistry.where((SearchResult option) {
                        return option.title.toLowerCase().contains(query) ||
                            option.keywords.any((k) => k.contains(query));
                      });
                    },
                    onSelected: (SearchResult selection) {
                      if (selection.type == SearchTargetType.screen &&
                          selection.screenIndex != null) {
                        if (widget.onNavigateTo != null) {
                          widget.onNavigateTo!(selection.screenIndex!);
                        }
                      }
                      // Clear focus after selection to hide keyboard/cursor
                      FocusScope.of(context).unfocus();
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: surfaceColor,
                          child: Container(
                            width: constraints.maxWidth,
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.getBorder(t)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: options.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppColors.getDivider(t)
                                      .withValues(alpha: 0.3)),
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(option.icon,
                                        size: 18, color: AppColors.primary),
                                  ),
                                  title: Text(option.title,
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(option.description,
                                      style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 12)),
                                  onTap: () => onSelected(option),
                                  hoverColor: AppColors.accentBlue
                                      .withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder:
                        (context, textController, focusNode, onFieldSubmitted) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubicEmphasized,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: searchBg,
                          borderRadius: BorderRadius.circular(50),
                          border:
                              Border.all(color: searchBorderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: textController,
                          focusNode: focusNode,
                          onSubmitted: (val) => onFieldSubmitted(),
                          style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          cursorColor: textColor,
                          decoration: InputDecoration(
                            hintText: 'Search features, pages, or data...',
                            hintStyle: AppTextStyles.body.copyWith(
                                color:
                                    secondaryTextColor.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.normal),
                            prefixIcon: Icon(FluentIcons.search_24_regular,
                                color: textColor.withValues(alpha: 0.7),
                                size: 18),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),

              const SizedBox(width: 16),

              // Action Icons and Profile Group
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconAction(FluentIcons.arrow_sync_24_regular, 'Updates',
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      onTap: _handleRefresh),
                  const SizedBox(width: 12),
                  _buildIconAction(
                      FluentIcons.alert_24_regular, 'Notifications',
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      onTap: _handleNotifications),
                  const SizedBox(width: 12),
                  _buildIconAction(FluentIcons.bookmark_24_regular, 'Saved',
                      surfaceColor: surfaceColor,
                      textColor: textColor, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("No saved items yet"),
                        duration: Duration(seconds: 1)));
                  }),

                  const SizedBox(width: 24),

                  // Status & Profile
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dynamic Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: !_isBackendConnected
                                ? Colors.orange.withValues(alpha: 0.1)
                                : (_isActive
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: !_isBackendConnected
                                    ? Colors.orange.withValues(alpha: 0.3)
                                    : (_isActive
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.red.withValues(alpha: 0.3)))),
                        child: Row(
                          children: [
                            if (!_isBackendConnected)
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.orange),
                                ),
                              )
                            else
                              _BlinkingLight(isActive: _isActive),
                            const SizedBox(width: 8),
                            if (!isMobile)
                              Text(
                                !_isBackendConnected
                                    ? 'Connecting...'
                                    : (_isActive ? 'Active Now' : 'Inactive'),
                                style: TextStyle(
                                    color: !_isBackendConnected
                                        ? Colors.orange[800]
                                        : (_isActive
                                            ? Colors.green[700]
                                            : Colors.red[700]),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // User Name & Profile Pill
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onProfileTap != null) {
                              widget.onProfileTap!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    onBack: () => Navigator.pop(context),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: textColor.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                if (!isMobile) ...[
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                      _userName ?? 'User',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Container(
                                  height: 32,
                                  width: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: surfaceColor,
                                    image: _userPhotoUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(_userPhotoUrl!),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: _userPhotoUrl == null
                                      ? Icon(FluentIcons.person_24_regular,
                                          color: secondaryTextColor, size: 20)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _handleRefresh() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Refreshing system status..."),
          duration: Duration(milliseconds: 800)),
    );
    await AbuseDetectionService().checkHealth();
    await _checkUserStatus();

    // Also broadcast a sync
    await AbuseDetectionService().syncState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("System refreshed"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1)),
      );
    }
  }

  void _handleNotifications() async {
    final alerts = await AbuseDetectionService().getAlerts(limit: 5);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(FluentIcons.alert_24_regular, color: AppColors.accentBlue),
          SizedBox(width: 8),
          Text("Recent Alerts")
        ]),
        content: SizedBox(
          width: 400,
          child: alerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No recent notifications."))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final a = alerts[i];
                    return ListTile(
                      leading: const Icon(FluentIcons.warning_24_regular,
                          color: Colors.red),
                      title: Text(a.label.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(a.sentence ?? "Content detected"),
                      trailing: Text(a.timestamp,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildIconAction(IconData icon, String tooltip,
      {required Color surfaceColor,
      required Color textColor,
      required VoidCallback onTap}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: surfaceColor,
        shape: BoxShape.circle,
        border: Border.all(
            color: textColor, width: 1.5), // Minimal monochrome border
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              color: textColor, // Minimal monochrome icon
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingLight extends StatefulWidget {
  final bool isActive;
  const _BlinkingLight({required this.isActive});

  @override
  State<_BlinkingLight> createState() => _BlinkingLightState();
}

class _BlinkingLightState extends State<_BlinkingLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color baseColor = widget.isActive ? Colors.green : Colors.red;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.6 * _controller.value),
                  blurRadius: 6,
                  spreadRadius: 2 * _controller.value,
                )
              ]),
        );
      },
    );
  }
}
