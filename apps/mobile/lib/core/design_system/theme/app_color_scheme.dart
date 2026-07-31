import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';

/// Builds the Material [ColorScheme] KinRaiDee uses today (light only).
/// Kept as its own function so a future `appDarkColorScheme()` can sit
/// alongside it without touching [AppTheme].
ColorScheme appLightColorScheme() {
  return const ColorScheme.light(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    secondary: AppColors.primarySoft,
    onSecondary: AppColors.textPrimary,
    error: AppColors.error,
    onError: AppColors.textOnPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceMuted,
    outline: AppColors.border,
  );
}
