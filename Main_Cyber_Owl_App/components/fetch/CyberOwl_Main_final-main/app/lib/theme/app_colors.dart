import 'package:flutter/material.dart';

/// Cyber Owl Color Palette
/// Continuous Theme Support (0.0 Dark -> 1.0 Light)
class AppColors {
  // ============= EXTREME COLORS =============
  // Dark Extreme (Pitch Black)
  static const Color blackBackground = Color(0xFF000000);
  static const Color blackSurface = Color(0xFF101010);
  static const Color blackText = Color(0xFFE8EAF6); // White text on black

  // Light Extreme (Pure White)
  static const Color whiteBackground = Color(0xFFFFFFFF);
  static const Color whiteSurface = Color(0xFFF0F0F0);
  static const Color whiteText = Color(0xFF000000); // Black text on white

  // Gradient stops for existing Navy/Off-White feel in middle (optional, but requested pitch black to white)
  // User requested: Pitch Dark -> Dark Black -> Light Black -> Grey -> Greyish White -> Pure White

  // ============= BRAND COLORS =============
  // Primary Purple (Cyber Owl signature)
  static const Color primaryPurple = Color(0xFF6366F1); // Radiant Indigo/Purple
  static const Color primaryPurpleLight = Color(0xFF818CF8);
  static const Color primaryPurpleDark = Color(0xFF4F46E5);

  // Secondary Blue
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryBlueDark = Color(0xFF1E40AF);

  // ============= ACCENT COLORS (Static) =============
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentBlue = primaryBlue;
  static const Color accentPurple = primaryPurple;
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color errorDark = Color(0xFFCF6679);
  static const Color warningDark = Color(0xFFD97706); // Amber 600

  // Alias for legacy support
  static const Color primary = primaryPurple;

  // ============= HELPER =============
  static Color interpolate(Color start, Color end, double t) {
    return Color.lerp(start, end, t) ?? start;
  }

  // ============= THEME-AWARE GETTERS =============

  // Backgrounds
  static Color getBackground(double t) =>
      interpolate(blackBackground, whiteBackground, t);
  static Color getBackgroundSecondary(double t) =>
      interpolate(const Color(0xFF050505), const Color(0xFFF5F5F5), t);
  static Color getSurface(double t) =>
      interpolate(blackSurface, whiteSurface, t);
  static Color getSidebarBackground(double t) =>
      interpolate(const Color(0xFF080808), const Color(0xFFFAFAFA), t);

  // Glassmorphism
  static Color getGlass(double t) =>
      interpolate(const Color(0x1AFFFFFF), const Color(0xE6FFFFFF), t);
  static Color getGlassBorder(double t) =>
      interpolate(const Color(0x33FFFFFF), const Color(0x1A000000), t);
  static Color getGlassHover(double t) =>
      interpolate(const Color(0x26FFFFFF), const Color(0xF0FFFFFF), t);

  // Text
  static Color getTextPrimary(double t) => t < 0.5 ? blackText : whiteText;
  static Color getTextSecondary(double t) =>
      t < 0.5 ? const Color(0xFF9CA3AF) : const Color(0xFF4A5568);
  static Color getTextTertiary(double t) =>
      t < 0.5 ? const Color(0xFF6B7280) : const Color(0xFF718096);

  // Dividers & Borders
  static Color getDivider(double t) =>
      interpolate(const Color(0xFF2D3748), const Color(0xFFE2E8F0), t);
  static Color getBorder(double t) =>
      interpolate(const Color(0xFF374151), const Color(0xFFCBD5E0), t);

  // Status Colors (Interpolated)
  static Color getSuccess(double t) =>
      interpolate(const Color(0xFF10B981), const Color(0xFF059669), t);
  static Color getWarning(double t) =>
      interpolate(const Color(0xFFFBBF24), const Color(0xFFD97706), t);
  static Color getError(double t) =>
      interpolate(const Color(0xFFF87171), const Color(0xFFDC2626), t);
  static Color getInfo(double t) =>
      interpolate(const Color(0xFF60A5FA), const Color(0xFF2563EB), t);

  // Glow Effects
  static Color getGlowPurple(double t) =>
      interpolate(const Color(0x66AC6AFF), const Color(0x33AC6AFF), t);
  static Color getGlowBlue(double t) =>
      interpolate(const Color(0x663B82F6), const Color(0x331E40AF), t);

  // Brand Colors
  static Color getPrimary(double t) =>
      interpolate(primaryPurple, primaryPurpleDark, t);
  static Color getSecondary(double t) =>
      interpolate(primaryBlue, primaryBlueDark, t);

  // Gradient Helpers
  static LinearGradient getRadiantGradient(double t) {
    final startColor = interpolate(primaryPurple, primaryPurpleDark, t);
    final endColor = interpolate(primaryPurpleDark, const Color(0xFF6366F1), t);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
    );
  }

  // Utility for logic that still needs a boolean (e.g. brightness)
  static bool isDark(double t) => t < 0.5;
}
