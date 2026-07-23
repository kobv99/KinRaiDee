import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFFF7A45);
  static const Color primaryDark = Color(0xFFE85F2A);
  static const Color primaryLight = Color(0xFFFFE9DF);

  // Secondary
  static const Color secondary = Color(0xFF2E8B57);
  static const Color secondaryDark = Color(0xFF1F6A40);
  static const Color secondaryLight = Color(0xFFE1F3E8);

  // Background
  static const Color background = Color(0xFFFFFBF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF7F3F0);

  // Text
  static const Color textPrimary = Color(0xFF241F1C);
  static const Color textSecondary = Color(0xFF6F6661);
  static const Color textMuted = Color(0xFF9A918C);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border and divider
  static const Color border = Color(0xFFE9E1DC);
  static const Color divider = Color(0xFFF0E8E3);

  // Feedback
  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFF4A340);
  static const Color error = Color(0xFFD94B4B);
  static const Color info = Color(0xFF3D7DD8);

  // Feature colors
  static const Color pantry = Color(0xFF5F9C68);
  static const Color recipe = Color(0xFFFF8A50);
  static const Color shopping = Color(0xFF4B86C6);
  static const Color nutrition = Color(0xFF9B6BC3);
}
