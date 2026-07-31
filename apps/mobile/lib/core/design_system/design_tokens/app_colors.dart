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
  static const Color primary = Color(0xFFFF5B3D); // Warm coral-orange
  static const Color primarySoft = Color(0xFFFFF0EB); // Soft peach surface
  static const Color primaryPressed = Color(0xFFE1492D);

  // Surfaces ----------------------------------------------------------------
  static const Color background = Color(0xFFFCFAF7); // Warm off-white
  static const Color surface = Color(0xFFFFFFFF); // Card surface
  static const Color surfaceMuted = Color(0xFFF7F3F0);

  // Text ----------------------------------------------------------------
  static const Color textPrimary = Color(0xFF2B2725); // Deep warm charcoal
  static const Color textSecondary = Color(0xFF756D69); // Warm muted grey
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFB8B0AB);

  // Border --------------------------------------------------------------
  static const Color border = Color(0xFFEDE4DF); // Very light warm grey

  // Semantic status -------------------------------------------------------
  static const Color success = Color(0xFF3FA34D); // Fresh natural green
  static const Color successSoft = Color(0xFFE9F6EA);
  static const Color warning = Color(0xFFE8A13D); // Warm amber
  static const Color warningSoft = Color(0xFFFCF1DF);
  static const Color error = Color(0xFFD3453B); // Reserved for real errors
  static const Color errorSoft = Color(0xFFFAE7E5);

  // Cooking Mode (dark) ---------------------------------------------------
  static const Color cookingBackground = Color(0xFF1B2320); // Charcoal-green
  static const Color cookingSurface = Color(0xFF232C28);
  static const Color cookingTextPrimary = Color(0xFFFAF8F6);
  static const Color cookingTextSecondary = Color(0xFFB7C0BB);
}
