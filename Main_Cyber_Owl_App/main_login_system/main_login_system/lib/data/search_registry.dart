import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

enum SearchTargetType { screen, action }

class SearchResult {
  final String title;
  final List<String> keywords;
  final SearchTargetType type;
  final int? screenIndex;
  final IconData icon;
  final String description;

  const SearchResult({
    required this.title,
    required this.keywords,
    required this.type,
    this.screenIndex,
    required this.icon,
    required this.description,
  });
}

final List<SearchResult> appSearchRegistry = [
  // Navigation Screens
  const SearchResult(
    title: 'Dashboard',
    keywords: [
      'home',
      'main',
      'overview',
      'stats',
      'dashboard',
      'graphs',
      'charts'
    ],
    type: SearchTargetType.screen,
    screenIndex: 0,
    icon: FluentIcons.grid_24_regular,
    description: 'Go to main dashboard overview',
  ),
  const SearchResult(
    title: 'Rules & Blocking',
    keywords: [
      'rules',
      'block',
      'whitelist',
      'blacklist',
      'keywords',
      'restriction',
      'ban'
    ],
    type: SearchTargetType.screen,
    screenIndex: 1,
    icon: FluentIcons.gavel_24_regular,
    description: 'Manage blocking rules and lists',
  ),
  const SearchResult(
    title: 'Activity History',
    keywords: [
      'history',
      'logs',
      'past',
      'alerts',
      'report',
      'audit',
      'tracker'
    ],
    type: SearchTargetType.screen,
    screenIndex: 2,
    icon: FluentIcons.history_24_regular,
    description: 'View past alerts and logs',
  ),
  const SearchResult(
    title: 'Live Monitor',
    keywords: [
      'live',
      'monitor',
      'realtime',
      'screen',
      'camera',
      'watch',
      'spy',
      'stream'
    ],
    type: SearchTargetType.screen,
    screenIndex: 3,
    icon: FluentIcons.pulse_24_regular,
    description: 'Start real-time monitoring',
  ),
  const SearchResult(
    title: 'Profile',
    keywords: [
      'profile',
      'account',
      'user',
      'name',
      'avatar',
      'email',
      'password',
      'edit profile'
    ],
    type: SearchTargetType.screen,
    screenIndex: 4,
    icon: FluentIcons.person_24_regular,
    description: 'Manage your account details',
  ),
  const SearchResult(
    title: 'Settings',
    keywords: [
      'settings',
      'config',
      'theme',
      'dark mode',
      'light mode',
      'preferences',
      'notification'
    ],
    type: SearchTargetType.screen,
    screenIndex: 5,
    icon: FluentIcons.settings_24_regular,
    description: 'System configuration and appearance',
  ),
  const SearchResult(
    title: 'About Cyber Owl',
    keywords: ['about', 'version', 'info', 'team', 'developer', 'credits'],
    type: SearchTargetType.screen,
    screenIndex: 6,
    icon: FluentIcons.info_24_regular,
    description: 'App info and version',
  ),
  const SearchResult(
    title: 'Logout',
    keywords: ['logout', 'exit', 'sign out', 'leave', 'system'],
    type: SearchTargetType.screen,
    screenIndex: 7,
    icon: FluentIcons.sign_out_24_regular,
    description: 'Sign out of the system',
  ),

  // Specific Sub-features (mapping to parent screens for now)
  const SearchResult(
    title: 'Face Detection',
    keywords: ['face', 'recognition', 'facial', 'ai'],
    type: SearchTargetType.screen,
    screenIndex: 3, // Redirect to Monitor
    icon: FluentIcons.person_24_regular,
    description: 'Access Face Detection in Live Monitor',
  ),
  const SearchResult(
    title: 'Nudity Detection',
    keywords: ['nudity', 'nsfw', 'adult', 'content', 'filter'],
    type: SearchTargetType.screen,
    screenIndex: 3, // Redirect to Monitor
    icon: FluentIcons.image_off_24_regular,
    description: 'Access Nudity Detection settings',
  ),
  const SearchResult(
    title: 'Theme Settings',
    keywords: ['color', 'appearance', 'ui', 'mode', 'light', 'dark'],
    type: SearchTargetType.screen,
    screenIndex: 5, // Settings
    icon: FluentIcons.color_24_regular,
    description: 'Change app theme in Settings',
  ),
];
