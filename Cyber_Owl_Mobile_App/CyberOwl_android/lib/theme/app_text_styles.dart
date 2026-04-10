import 'package:flutter/material.dart';

class AppTextStyles {
  // Usage: Text('Title', style: AppTextStyles.h1.copyWith(color: AppColors.getTextPrimary(isDark)))

  static const TextStyle heading1 =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold);

  static const TextStyle heading2 =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  static const TextStyle heading3 =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  static const TextStyle body =
      TextStyle(fontSize: 14, fontWeight: FontWeight.normal);

  static const TextStyle caption =
      TextStyle(fontSize: 12, fontWeight: FontWeight.normal);

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // Compatibility aliases
  static const TextStyle h1 = heading1;
  static const TextStyle h2 = heading2;
  static const TextStyle h3 = heading3;
  static const TextStyle subBody = caption;

  static const TextStyle appTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  static const TextStyle appTagline = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 6,
  );
}
