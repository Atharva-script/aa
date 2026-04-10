import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'child_details_screen.dart';

class ChildrenTab extends StatefulWidget {
  const ChildrenTab({super.key});

  @override
  State<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<ChildrenTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshParentData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Resolve profile_pic to a full URL using the child's reported IP if relative
  String? _resolveProfilePic(Map<String, dynamic> child) {
    return AppConstants.resolveProfilePic(child['profile_pic']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();
    final children = provider.children;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Compact Header --
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        color: AppColors.primaryPurple,
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Family Devices',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 12,
                        color:
                            AppColors.getPrimary(isDark).withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (children.isEmpty) _buildEmptyState(isDark),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length + 1,
                itemBuilder: (context, index) {
                  if (index == children.length) {
                    return _buildAddChildButton(context, isDark);
                  }
                  return _buildChildCard(context, children[index], isDark);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedComputerDesk01,
              color: AppColors.getTextTertiary(isDark),
              size: 32),
          const SizedBox(height: 10),
          Text(
            "No devices connected",
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Install CyberOwl on your child's PC",
            textAlign: TextAlign.center,
            style: TextStyle(
                color:
                    AppColors.getTextSecondary(isDark).withValues(alpha: 0.5),
                fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(
      BuildContext context, Map<String, dynamic> child, bool isDark) {
    final name = child['name'] ?? child['email'] ?? 'Unknown';
    final device = child['device_name'] ?? child['hostname'] ?? 'PC Device';
    final profilePic = _resolveProfilePic(child);
    final lastIp = child['last_ip'];
    final hostname = child['hostname'];
    final isOnline = (child['online_status'] ?? 'offline') == 'online';
    final isMonitoring = child['is_monitoring'] == true;
    final statusColor = isMonitoring
        ? AppColors.primaryPurple
        : (isOnline
            ? AppColors.accentGreen
            : AppColors.getTextTertiary(isDark));

    // Build compact info string
    final infoItems = <String>[];
    if (hostname != null) infoItems.add(hostname);
    if (lastIp != null) infoItems.add(lastIp);
    final infoLine = infoItems.isNotEmpty ? infoItems.join(' · ') : device;

    // Check if this is the currently selected child
    final isSelected =
        context.watch<AppProvider>().selectedChildId == child['email'];

    return GestureDetector(
      onTap: () async {
        if (child['email'] != null) {
          final provider = context.read<AppProvider>();

          // Use the new secure selectChild method
          final success = await provider.selectChild(child['email']!);

          if (success) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChildDetailsScreen(childData: child),
                ),
              ).then((_) {
                if (mounted) context.read<AppProvider>().refreshParentData();
              });
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Authentication failed. Switch cancelled."),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPurple.withValues(alpha: 0.5)
                : AppColors.getGlassBorder(isDark),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Compact avatar with status dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppColors.primaryPurple.withValues(alpha: 0.12),
                  foregroundImage: profilePic != null && profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : null,
                  onForegroundImageError: (e, s) {
                    debugPrint(
                        "Error loading profile pic from $profilePic: $e");
                  },
                  child: Icon(Icons.person,
                      color: AppColors.primaryPurple.withValues(alpha: 0.5),
                      size: 20),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    infoLine,
                    style: TextStyle(
                      color: AppColors.getTextTertiary(isDark),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'View Details',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 14,
                color: AppColors.getTextTertiary(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddChildButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text("Add New Device"),
                  content: const Text(
                      "To add a child:\n1. Install CyberOwl on their PC.\n2. Sign in with the child's email.\n3. Enter YOUR parent email when prompted (or in settings)."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"))
                  ],
                ));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
                icon: HugeIcons.strokeRoundedPlusSignCircle,
                color: AppColors.primaryPurple,
                size: 16),
            const SizedBox(width: 6),
            Text(
              'Add Device',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
