import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';

/// Semantic tokens that don't map cleanly onto Flutter's [ColorScheme]
/// (success/warning states, soft surfaces, Cooking Mode palette). Access
/// via `Theme.of(context).extension<AppSemanticColors>()!`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.border,
    required this.cookingBackground,
    required this.cookingSurface,
    required this.cookingTextPrimary,
    required this.cookingTextSecondary,
  });

  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color border;
  final Color cookingBackground;
  final Color cookingSurface;
  final Color cookingTextPrimary;
  final Color cookingTextSecondary;

  static const AppSemanticColors light = AppSemanticColors(
    primarySoft: AppColors.primarySoft,
    success: AppColors.success,
    successSoft: AppColors.successSoft,
    warning: AppColors.warning,
    warningSoft: AppColors.warningSoft,
    border: AppColors.border,
    cookingBackground: AppColors.cookingBackground,
    cookingSurface: AppColors.cookingSurface,
    cookingTextPrimary: AppColors.cookingTextPrimary,
    cookingTextSecondary: AppColors.cookingTextSecondary,
  );

  @override
  AppSemanticColors copyWith({
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? border,
    Color? cookingBackground,
    Color? cookingSurface,
    Color? cookingTextPrimary,
    Color? cookingTextSecondary,
  }) {
    return AppSemanticColors(
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      border: border ?? this.border,
      cookingBackground: cookingBackground ?? this.cookingBackground,
      cookingSurface: cookingSurface ?? this.cookingSurface,
      cookingTextPrimary: cookingTextPrimary ?? this.cookingTextPrimary,
      cookingTextSecondary: cookingTextSecondary ?? this.cookingTextSecondary,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      cookingBackground: Color.lerp(cookingBackground, other.cookingBackground, t)!,
      cookingSurface: Color.lerp(cookingSurface, other.cookingSurface, t)!,
      cookingTextPrimary: Color.lerp(cookingTextPrimary, other.cookingTextPrimary, t)!,
      cookingTextSecondary: Color.lerp(cookingTextSecondary, other.cookingTextSecondary, t)!,
    );
  }
}
