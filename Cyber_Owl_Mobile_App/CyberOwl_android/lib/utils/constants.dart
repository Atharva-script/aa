import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../theme/app_colors.dart';
// import '../theme/app_text_styles.dart';

export '../theme/app_colors.dart';
export '../theme/app_text_styles.dart';

class AppConstants {
  // App Info
  static const String appName = 'CyberOwl';
  static const String appTagline = 'PARENT CONTROL';
  static const String appVersion = '1.0.0';

  // API Configuration - Set your production VPS IP or Domain here
  static String? _dynamicApiBaseUrl;

  static String get apiBaseUrl =>
      _dynamicApiBaseUrl ??
      dotenv.env['API_BASE_URL'] ??
      'https://backend.cyberowll.in';

  static set apiBaseUrl(String url) {
    _dynamicApiBaseUrl = url;
  }

  // Set to false to bypass local network discovery (UDP) for remote servers
  static bool useAutoDiscovery = false;

  // Google OAuth Client ID (Android)
  static const String googleClientId =
      '691983497226-7rna59tuoai4de0i4dhm3hedslpquij3.apps.googleusercontent.com';

  // API Endpoints
  static const String healthEndpoint = '/api/health';
  static const String loginEndpoint = '/api/login';
  static const String statusEndpoint = '/api/status';
  static const String systemStatusEndpoint =
      '/api/system/status'; // New Endpoint
  static const String launchPcAppEndpoint =
      '/api/system/launch-pc-app'; // Launch PC App
  static const String bypassSignInEndpoint =
      '/api/system/bypass-signin'; // Send bypass credentials to running app
  static const String requestLaunchEndpoint =
      '/api/system/request-launch'; // Backend-mediated launch request
  static const String startEndpoint = '/api/start';
  static const String stopEndpoint = '/api/stop';
  static const String alertsEndpoint = '/api/alerts';
  static const String alertStatsEndpoint = '/api/alerts/stats';
  static const String clearAlertsEndpoint = '/api/alerts/clear';
  static const String analyticsEndpoint = '/api/analytics/dashboard';
  static const String configEndpoint = '/api/config';
  // User & Profile
  static const String userEndpoint = '/api/user'; // Legacy?
  static const String userProfileEndpoint = '/api/me';
  static const String userUpdateEndpoint = '/api/user/update';
  static const String uploadPhotoEndpoint =
      '/api/user/upload-photo'; // Image Upload
  static const String secretCodeScheduleEndpoint = '/api/secret-code/schedule';

  // Refresh Intervals
  static const Duration statusRefreshInterval = Duration(seconds: 3);
  static const Duration alertsRefreshInterval = Duration(seconds: 5);
  static const Duration requestsRefreshInterval =
      Duration(seconds: 1); // Fast polling for auth requests

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String emailKey = 'user_email';
  static const String serverUrlKey = 'server_url';
  static const String themeModeKey = 'theme_mode';

  // Assets
  static const String logoPath = 'assets/logo/logo.png';

  // Helper method to resolve profile picture URLs (handles relative paths from Windows/Linux)
  static String? resolveProfilePic(String? pic) {
    if (pic == null || pic.isEmpty) return null;
    if (pic.startsWith('http')) return pic;

    String p = pic;
    if (p.contains(r'\')) p = p.split(r'\').last;
    if (p.contains('/')) p = p.split('/').last;

    return '${AppConstants.apiBaseUrl}/uploads/$p';
  }
}

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    primaryColor: AppColors.primaryPurple,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.surfaceDark,
      error: AppColors.errorDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryDark,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimaryDark),
      displayMedium: TextStyle(color: AppColors.textPrimaryDark),
      bodyLarge: TextStyle(color: AppColors.textPrimaryDark),
      bodyMedium: TextStyle(color: AppColors.textSecondaryDark),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sidebarBackgroundDark,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryPurple,
      unselectedItemColor: AppColors.textSecondaryDark,
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    primaryColor: AppColors.primaryPurple,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.surfaceLight,
      error: AppColors.errorLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimaryLight),
      displayMedium: TextStyle(color: AppColors.textPrimaryLight),
      bodyLarge: TextStyle(color: AppColors.textPrimaryLight),
      bodyMedium: TextStyle(color: AppColors.textSecondaryLight),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sidebarBackgroundLight,
      foregroundColor: AppColors.textPrimaryLight,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primaryPurple,
      unselectedItemColor: AppColors.textSecondaryLight,
    ),
  );
}
