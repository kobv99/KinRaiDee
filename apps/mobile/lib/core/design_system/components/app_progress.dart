import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_motion.dart';
import '../design_tokens/app_radius.dart';

/// Linear progress bar used for Pantry readiness % and Cooking Mode step
/// progress. Animates changes instead of jumping.
class AppProgress extends StatelessWidget {
  const AppProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.trackColor = AppColors.surfaceMuted,
    this.valueColor = AppColors.success,
  });

  /// 0.0 - 1.0
  final double value;
  final double height;
  final Color trackColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: AppRadius.pillRadius,
      child: Container(
        height: height,
        color: trackColor,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: AppMotion.emphasized,
          curve: AppMotion.emphasizedCurve,
          builder: (context, animatedValue, _) {
            return FractionallySizedBox(
              widthFactor: animatedValue,
              child: Container(color: valueColor),
            );
          },
        ),
      ),
    );
  }
}
