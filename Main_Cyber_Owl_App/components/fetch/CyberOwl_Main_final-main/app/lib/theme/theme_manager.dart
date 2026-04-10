import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

/// Cyber Owl Theme Manager
/// Manages theme state: 0.0 = Dark (Black), 1.0 = Light (White)
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;

  ThemeManager._internal();

  /// Initialize and load saved theme (call before runApp)
  Future<void> init() async {
    await _loadTheme();
  }

  // 0.0 = Dark (Black), 1.0 = Light (White)
  double _themeValue = 0.0;
  Timer? _debounceTimer;

  double get themeValue => _themeValue;

  // Helper to check if currently dark
  bool get isDark => _themeValue < 0.5;

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('theme_value') ?? 0.0;
      // Snap to binary values
      _themeValue = saved >= 0.5 ? 1.0 : 0.0;
      notifyListeners();
    } catch (e) {
      _themeValue = 0.0;
    }
  }

  /// Set theme value (0.0 = Dark, 1.0 = Light)
  Future<void> setThemeValue(double value) async {
    // Snap to binary: < 0.5 = dark (0.0), >= 0.5 = light (1.0)
    _themeValue = value >= 0.5 ? 1.0 : 0.0;
    notifyListeners();
    await _saveTheme();

    // Debounce API sync (2 seconds)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      AuthService.updateTheme(_themeValue);
    });
  }

  /// Toggle between dark and light
  Future<void> toggleTheme() async {
    await setThemeValue(isDark ? 1.0 : 0.0);
  }

  /// Sync theme from User Object (Login)
  Future<void> syncTheme(double? value) async {
    if (value != null) {
      // Snap to binary values
      _themeValue = value >= 0.5 ? 1.0 : 0.0;
      notifyListeners();
      await _saveTheme();
    }
  }

  /// Save theme preference
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('theme_value', _themeValue);
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }
  }
}

final themeManager = ThemeManager();
