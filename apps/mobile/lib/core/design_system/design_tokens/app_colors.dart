import 'package:flutter/material.dart';

/// KinRaiDee raw color palette.
///
/// These are the literal color values approved for the KinRaiDee design
/// system (Sprint 5.5). Do NOT reference these constants directly from
/// feature widgets — use the semantic roles exposed through
/// [AppColorScheme] / [Theme.of(context).colorScheme] instead. This file
/// exists purely as the single source of truth for the raw palette.
class AppColors {
  AppColors._();

  // Brand / primary --------------------------------------------------------
  static const Color primary = Color(0xFFFF6547); // Approved coral
  static const Color primarySoft = Color(0xFFFFF0EA);
  static const Color primaryPressed = Color(0xFFE1492D);

  // Surfaces ----------------------------------------------------------------
  static const Color background = Color(0xFFFCFAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F3F0);

  // Text ----------------------------------------------------------------
  static const Color textPrimary = Color(0xFF2B2826);
  static const Color textSecondary = Color(0xFF7B726D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFB8B0AB);

  // Border --------------------------------------------------------------
  static const Color border = Color(0xFFECE4DF);

  // Semantic status -------------------------------------------------------
  static const Color success = Color(0xFF43B96B);
  static const Color successSoft = Color(0xFFE9F6EA);
  static const Color warning = Color(0xFFF4A340);
  static const Color warningSoft = Color(0xFFFCF1DF);
  static const Color error = Color(
    0xFFD3453B,
  ); // Reserved for destructive actions/real errors only
  static const Color errorSoft = Color(0xFFFAE7E5);
  static const Color info = Color(0xFF3D7DD8);

  // Cooking Mode (dark) ---------------------------------------------------
  static const Color cookingBackground = Color(0xFF10201D);
  static const Color cookingSurface = Color(0xFF1B2E29);
  static const Color cookingTextPrimary = Color(0xFFFAF8F6);
  static const Color cookingTextSecondary = Color(0xFFB7C0BB);

  // Feature accent colors (Pantry / Recipe / Shopping / Nutrition tabs) ---
  static const Color pantry = Color(0xFF5F9C68);
  static const Color recipe = Color(0xFFFF8A50);
  static const Color shopping = Color(0xFF4B86C6);
  static const Color nutrition = Color(0xFF9B6BC3);

  // ---------------------------------------------------------------------
  // Legacy aliases (lib/app/theme/app_colors.dart re-exports this file).
  // Kept so pre-Sprint-5.5 screens compile unchanged against the same
  // underlying palette. New code should prefer the semantic names above.
  // ---------------------------------------------------------------------
  static const Color primaryDark = primaryPressed;
  static const Color primaryLight = primarySoft;
  static const Color secondary = success;
  static const Color secondaryDark = Color(0xFF2E8B4E);
  static const Color secondaryLight = successSoft;
  static const Color surfaceVariant = surfaceMuted;
  static const Color textMuted = Color(0xFF9A918C);
  static const Color divider = border;
}
