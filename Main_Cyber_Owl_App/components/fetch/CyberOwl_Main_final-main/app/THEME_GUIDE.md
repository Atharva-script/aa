# 🎨 Cyber Owl Theme System

Complete Dark & Light theme support for the Cyber Owl desktop application.

## 📋 Overview

The Cyber Owl theme system provides:
- ✅ **Full Dark Theme** (default) - Deep navy backgrounds with purple/blue neon accents
- ✅ **Full Light Theme** - Soft off-white backgrounds with muted purple/blue accents
- ✅ **System Theme Detection** - Automatically follows Windows theme preference
- ✅ **Manual Toggle** - User can override and choose their preferred theme
- ✅ **Theme Persistence** - Saves user preference using SharedPreferences
- ✅ **Smooth Transitions** - 300ms animated theme switches
- ✅ **Glassmorphism Support** - Theme-aware glass effects for both modes
- ✅ **No Hardcoded Colors** - All colors managed through centralized system

## 📁 File Structure

```
lib/theme/
├── app_colors.dart         # Color palette (dark & light variants)
├── app_theme.dart          # ThemeData configurations
├── theme_manager.dart      # Theme state management
└── app_text_styles.dart    # Typography (existing)

lib/widgets/
└── theme_toggle.dart       # Theme switching UI components

lib/examples/
└── theme_example.dart      # Usage examples and documentation
```

## 🎨 Color Palette

### Dark Theme
| Category | Color | Hex |
|----------|-------|-----|
| Background | Deep Navy | `#0A0E27` |
| Surface | Card/Surface | `#1A1F35` |
| Primary | Neon Purple | `#AC6AFF` |
| Secondary | Electric Blue | `#3B82F6` |
| Text Primary | Soft White | `#E8EAF6` |
| Text Secondary | Light Grey | `#9CA3AF` |
| Glow Purple | 40% Purple | `#66AC6AFF` |
| Glow Blue | 40% Blue | `#663B82F6` |

### Light Theme
| Category | Color | Hex |
|----------|-------|-----|
| Background | Soft Off-White | `#F5F7FA` |
| Surface | Pure White | `#FFFFFF` |
| Primary | Deep Purple | `#7A3BBF` |
| Secondary | Deep Blue | `#1E40AF` |
| Text Primary | Near Black | `#1A202C` |
| Text Secondary | Dark Grey | `#4A5568` |
| Glow Purple | 20% Purple | `#33AC6AFF` |
| Glow Blue | 20% Blue | `#331E40AF` |

## 🚀 Quick Start

### 1. Using Theme Colors

```dart
import '../theme/app_colors.dart';

// Get current theme
final isDark = Theme.of(context).brightness == Brightness.dark;

// Use theme-aware colors
Container(
  color: AppColors.getBackground(isDark),
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.getTextPrimary(isDark)),
  ),
)
```

### 2. Adding Theme Toggle

```dart
import '../widgets/theme_toggle.dart';

// In your AppBar or Settings
AppBar(
  actions: [
    ThemeIconToggle(),  // Compact icon button
  ],
)

// Or full control
ThemeToggleButton()  // Shows System/Light/Dark options

// Or dropdown
ThemeDropdown()
```

### 3. Changing Theme Programmatically

```dart
import '../theme/theme_manager.dart';

// Toggle between light and dark
await themeManager.toggleTheme();

// Set specific theme
await themeManager.setTheme(ThemeMode.light);
await themeManager.setTheme(ThemeMode.dark);
await themeManager.useSystem();  // Follow system theme
```

## 🎯 Theme-Aware Components

### Glassmorphism Card

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.getGlass(isDark),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppColors.getGlassBorder(isDark),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 20,
      ),
    ],
  ),
)
```

### Glow Effects (Logo/Buttons)

```dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: AppColors.getGlowPurple(isDark),
        blurRadius: 30,
        spreadRadius: 5,
      ),
    ],
  ),
)
```

### Status Indicators

```dart
// Success, Warning, Error, Info - all theme-adaptive
final successColor = AppColors.getSuccess(isDark);
final errorColor = AppColors.getError(isDark);
final warningColor = AppColors.getWarning(isDark);
final infoColor = AppColors.getInfo(isDark);
```

## 📖 API Reference

### AppColors Getters

```dart
// Backgrounds
AppColors.getBackground(bool isDark)
AppColors.getBackgroundSecondary(bool isDark)
AppColors.getSurface(bool isDark)
AppColors.getSidebarBackground(bool isDark)

// Text
AppColors.getTextPrimary(bool isDark)
AppColors.getTextSecondary(bool isDark)
AppColors.getTextTertiary(bool isDark)

// Brand Colors
AppColors.getPrimary(bool isDark)       // Purple
AppColors.getSecondary(bool isDark)     // Blue

// Glassmorphism
AppColors.getGlass(bool isDark)
AppColors.getGlassBorder(bool isDark)
AppColors.getGlassHover(bool isDark)

// Status Colors
AppColors.getSuccess(bool isDark)
AppColors.getWarning(bool isDark)
AppColors.getError(bool isDark)
AppColors.getInfo(bool isDark)

// Glow Effects
AppColors.getGlowPurple(bool isDark)
AppColors.getGlowBlue(bool isDark)

// Dividers & Borders
AppColors.getDivider(bool isDark)
AppColors.getBorder(bool isDark)
```

### ThemeManager Methods

```dart
// Get current theme
themeManager.themeMode          // ThemeMode enum
themeManager.useSystemTheme     // bool
themeManager.currentThemeName   // String: "System", "Light", or "Dark"

// Check if dark
themeManager.isDarkMode         // Legacy getter
themeManager.isDarkMode(context) // Context-aware

// Change theme
await themeManager.toggleTheme()
await themeManager.setTheme(ThemeMode.light)
await themeManager.setTheme(ThemeMode.dark)
await themeManager.useSystem()
```

## ✨ Special Features

### 1. Smooth Transitions
All theme changes animate smoothly over 300ms:
```dart
MaterialApp(
  themeAnimationDuration: const Duration(milliseconds: 300),
  themeAnimationCurve: Curves.easeInOut,
)
```

### 2. System Theme Detection
Automatically detects Windows system theme:
```dart
// In ThemeManager
if (_themeMode == ThemeMode.system) {
  final brightness = MediaQuery.of(context).platformBrightness;
  return brightness == Brightness.dark;
}
```

### 3. Persistence
Theme preference persists across app restarts:
```dart
// Saves to SharedPreferences
await prefs.setBool('use_system_theme', _useSystemTheme);
await prefs.setString('theme_mode', 'dark' | 'light');
```

## 🔄 Migration from Hardcoded Colors

### Before (Hardcoded)
```dart
Container(
  color: Color(0xFF121212),
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.white),
  ),
)
```

### After (Theme-Aware)
```dart
Container(
  color: AppColors.getBackground(isDark),
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.getTextPrimary(isDark)),
  ),
)
```

## 🎨 Design Guidelines

### Dark Theme Best Practices
- Use deep navy (`#0A0E27`) for main background
- Use subtle glows (40% opacity) for accents
- Keep glassmorphism at 10% white
- Use bright purple/blue for primary actions

### Light Theme Best Practices
- Use soft off-white (`#F5F7FA`) for background
- Use reduced glows (20% opacity) for accents
- Keep glassmorphism at 90% white
- Use muted purple/blue for primary actions
- Avoid harsh pure white backgrounds

## 📝 Example Screens

All existing screens have been updated to be theme-aware:

1. ✅ **Splash Screen** - Loading screen with theme-adaptive colors
2. ✅ **Error Screen** - Error states with softer red in light mode
3. 🔄 **Dashboard** - (Already has theme support)
4. 🔄 **Login Screen** - (To be verified)

See `lib/examples/theme_example.dart` for complete working examples.

## 🛠️ Troubleshooting

### Theme not changing
```dart
// Ensure you're wrapping MaterialApp with AnimatedBuilder
AnimatedBuilder(
  animation: themeManager,
  builder: (context, child) {
    return MaterialApp(
      themeMode: themeManager.themeMode,
      // ...
    );
  },
)
```

### Colors not updating
```dart
// Always get current theme mode
final isDark = Theme.of(context).brightness == Brightness.dark;

// Don't cache isDark outside build method
```

### Legacy code compatibility
```dart
// Old constants still work for backward compatibility
AppColors.primary        // Still available
AppColors.background     // Still available
AppColors.textPrimary    // Still available
```

## 📚 Additional Resources

- **Full Example**: `lib/examples/theme_example.dart`
- **Color Palette**: `lib/theme/app_colors.dart`
- **Theme Config**: `lib/theme/app_theme.dart`
- **State Management**: `lib/theme/theme_manager.dart`

## 🎯 Next Steps

1. Add theme toggle to your Settings screen
2. Verify all custom widgets use theme-aware colors
3. Test both themes thoroughly
4. Consider adding animation preferences

---

**Built with ❤️ for Cyber Owl** - Premium AI + Cybersecurity Platform
