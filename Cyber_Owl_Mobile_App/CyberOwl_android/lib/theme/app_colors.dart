import 'package:flutter/material.dart';

/// Cyber Owl Color Palette - Ported from PC Version
/// Premium AI + Cybersecurity themed colors for Dark & Light modes
class AppColors {
  // ============= BRAND COLORS =============
  // Primary Purple (Cyber Owl signature)
  static const Color primaryPurple = Color(0xFFAC6AFF); // Neon Purple
  static const Color primaryPurpleDark = Color(0xFF7A3BBF); // Deep Purple
  static const Color primaryPurpleLight = Color(0xFFD4B0FF); // Light Purple

  // Secondary Blue (Tech/Cyber accent)
  static const Color primaryBlue = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryBlueDark = Color(0xFF1E40AF); // Deep Blue
  static const Color primaryBlueLight = Color(0xFF93C5FD); // Sky Blue

  // ============= DARK THEME COLORS =============
  // Backgrounds - Pure Black / Dark Grey
  static const Color backgroundDark = Color(0xFF000000); // Pure Black
  static const Color backgroundDarkSecondary =
      Color(0xFF0A0A0A); // Almost Black
  static const Color surfaceDark = Color(0xFF121212); // Material Dark Surface
  static const Color sidebarBackgroundDark = Color(0xFF000000); // Sidebar

  // Glassmorphism - Dark Mode
  static const Color glassDark = Color(0x1AFFFFFF); // 10% white
  static const Color glassDarkBorder = Color(0x33FFFFFF); // 20% white
  static const Color glassDarkHover = Color(0x26FFFFFF); // 15% white

  // Text - Dark Mode
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondaryDark = Color(0xFFA0A0A0); // Light grey
  static const Color textTertiaryDark = Color(0xFF707070); // Medium grey

  // Dividers & Borders - Dark Mode
  static const Color dividerDark = Color(0xFF202020);
  static const Color borderDark = Color(0xFF303030);

  // ============= LIGHT THEME COLORS =============
  // Backgrounds - Soft Off-White / Light Grey
  static const Color backgroundLight = Colors.white; // Pure white
  static const Color backgroundLightSecondary = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceLight = Color(0xFFFFFFFF); // Card/Surface
  static const Color sidebarBackgroundLight = Color(0xFFFAFBFC); // Sidebar

  // Glassmorphism - Light Mode
  static const Color glassLight = Color(0xE6FFFFFF); // 90% white
  static const Color glassLightBorder = Color(0x1A000000); // 10% black
  static const Color glassLightHover = Color(0xF0FFFFFF); // 94% white

  // Text - Light Mode
  static const Color textPrimaryLight = Color(0xFF1A202C); // Near black
  static const Color textSecondaryLight = Color(0xFF4A5568); // Dark grey
  static const Color textTertiaryLight = Color(0xFF718096); // Medium grey

  // Dividers & Borders - Light Mode
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFCBD5E0);

  // ============= ACCENT COLORS (Theme-Adaptive) =============
  // Success
  static const Color successDark = Color(0xFF10B981); // Bright green
  static const Color successLight = Color(0xFF059669); // Muted green

  // Warning
  static const Color warningDark = Color(0xFFFBBF24); // Bright amber
  static const Color warningLight = Color(0xFFD97706); // Muted amber

  // Error (Softer in light mode)
  static const Color errorDark = Color(0xFFF87171); // Bright red
  static const Color errorLight = Color(0xFFDC2626); // Softer red

  // Info
  static const Color infoDark = Color(0xFF60A5FA); // Bright blue
  static const Color infoLight = Color(0xFF2563EB); // Muted blue

  // Additional Accents
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentOrange = Color(0xFFFF9F67);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPink = Color(0xFFEC4899);

  // ============= GLOW COLORS =============
  // Logo & Progress Bar Glows
  static const Color glowPurpleDark = Color(0x66AC6AFF); // 40% purple glow
  static const Color glowBlueDark = Color(0x663B82F6); // 40% blue glow
  static const Color glowPurpleLight = Color(0x33AC6AFF); // 20% purple glow
  static const Color glowBlueLight = Color(0x331E40AF); // 20% blue glow

  // ============= THEME-AWARE GETTERS =============
  static Color getBackground(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;

  static Color getBackgroundSecondary(bool isDark) =>
      isDark ? backgroundDarkSecondary : backgroundLightSecondary;

  static Color getSurface(bool isDark) => isDark ? surfaceDark : surfaceLight;

  static Color getGlass(bool isDark) => isDark ? glassDark : glassLight;

  static Color getGlassBorder(bool isDark) =>
      isDark ? glassDarkBorder : glassLightBorder;

  static Color getGlassHover(bool isDark) =>
      isDark ? glassDarkHover : glassLightHover;

  static Color getTextPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;

  static Color getTextSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;

  static Color getTextTertiary(bool isDark) =>
      isDark ? textTertiaryDark : textTertiaryLight;

  static Color getDivider(bool isDark) => isDark ? dividerDark : dividerLight;

  static Color getBorder(bool isDark) => isDark ? borderDark : borderLight;

  static Color getSuccess(bool isDark) => isDark ? successDark : successLight;

  static Color getWarning(bool isDark) => isDark ? warningDark : warningLight;

  static Color getError(bool isDark) => isDark ? errorDark : errorLight;

  static Color getInfo(bool isDark) => isDark ? infoDark : infoLight;

  // Primary brand color (always purple)
  static Color getPrimary(bool isDark) =>
      isDark ? primaryPurple : primaryPurpleDark;

  static Color getSecondary(bool isDark) =>
      isDark ? primaryBlue : primaryBlueDark;

  // Legacy aliases for backward compatibility
  static const Color primary = primaryPurple;
  static const Color primaryDark = primaryPurpleDark;
  static const Color primaryLight = backgroundDarkSecondary;
  static const Color accentBlue = primaryBlue;
  static const Color accentGreen = successDark;
  static const Color accentRed = errorDark;
  static const Color accentPurple = primaryPurple;
  static const Color accentAmber = warningDark;

  // Mobile App Compatibility Aliases
  static const Color secondary = primaryBlue;
  static const Color background = backgroundDark;
  static const Color card = surfaceDark;
  static const Color text = textPrimaryDark;
  static const Color success = successDark;
  static const Color warning = warningDark;
  static const Color danger = errorDark;
  static const Color surface = surfaceDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textMuted = textTertiaryDark;
  static const Color textMutedLight = textTertiaryLight;

  // Legacy getters
  static const Color sidebarBackground = sidebarBackgroundDark;
  // static const Color background = backgroundDark; // Already defined above
  // static const Color surface = surfaceDark; // Already defined above
  static const Color sidebarDark = sidebarBackgroundDark;
  static const Color textPrimary = textPrimaryDark;
  // static const Color textSecondary = textSecondaryDark; // Already defined above
  static const Color textLight = textPrimaryDark;
  static const Color divider = dividerDark;
  static const Color textLightTheme = textPrimaryLight;

  // ============= GRADIENTS =============
  // Gradient - matching owl logo (purple to pink)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFAC6AFF), Color(0xFFEC4899)], // Purple to Pink
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Colors.black, Color(0xFF121212), Colors.black],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    colors: [backgroundLight, backgroundLightSecondary, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient cardGradient = LinearGradient(
    colors: [
      const Color(0xFF1E1E1E).withValues(alpha: 0.9),
      const Color(0xFF121212).withValues(alpha: 0.8)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Logo gradient (purple to pink matching owl)
  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFFAC6AFF), Color(0xFFEC4899)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
