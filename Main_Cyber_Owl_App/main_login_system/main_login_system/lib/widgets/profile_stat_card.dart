import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';

class ProfileStatCard extends StatelessWidget {
  final double themeValue;
  final String title;
  final String userName;
  final String role;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final String? profileImageUrl;

  const ProfileStatCard({
    super.key,
    required this.themeValue,
    this.title = 'Top Monitor', // Adapted from "Best Seller"
    this.userName = 'Jone Doe',
    this.role = 'Admin',
    this.leftLabel = 'Alerts',
    this.leftValue = '125',
    this.rightLabel = 'Actions',
    this.rightValue = '1,240',
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(themeValue);
    final textColor = AppColors.getTextPrimary(themeValue);
    final secondaryTextColor = AppColors.getTextSecondary(themeValue);
    final borderColor = AppColors.getDivider(themeValue).withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Best Seller / Top Monitor
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          // Profile Image with Blue Ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentBlue, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.getBackground(themeValue),
              child: ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: profileImageUrl != null
                      ? Image.network(
                          profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(FluentIcons.person_24_regular,
                                size: 40, color: Colors.grey);
                          },
                        )
                      : const Icon(FluentIcons.person_24_regular,
                          size: 40, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name and Role Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats Layout (Target Sales | Total Sales style)
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      leftLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leftValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: borderColor,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      rightLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rightValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
