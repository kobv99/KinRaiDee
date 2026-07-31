import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';

enum RecipeReadiness { ready, pantryFriendly, almostReady }

/// Visual recipe card used on Home (horizontal top-picks row) and Recipe
/// list. Deliberately concise — image, name, pantry match %, one status
/// label, and cooking time only (per spec: "do not place every possible
/// badge on the card").
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.name,
    required this.pantryMatchPercent,
    required this.readiness,
    required this.cookingTimeMinutes,
    required this.onTap,
    this.imageProvider,
    this.width = 160,
  });

  final String name;
  final int pantryMatchPercent;
  final RecipeReadiness readiness;
  final int cookingTimeMinutes;
  final VoidCallback onTap;
  final ImageProvider? imageProvider;
  final double width;

  String get _readinessLabel => switch (readiness) {
        RecipeReadiness.ready => 'พร้อมทำ',
        RecipeReadiness.pantryFriendly => 'Pantry',
        RecipeReadiness.almostReady => 'ใกล้พร้อม',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name, พร้อมทำ $pantryMatchPercent เปอร์เซ็นต์, ใช้เวลา $cookingTimeMinutes นาที',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.largeRadius,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.largeRadius,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: imageProvider != null
                          ? Image(image: imageProvider!, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.primarySoft,
                              child: const Icon(Icons.restaurant, color: AppColors.primary, size: 32),
                            ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Text(
                        '$pantryMatchPercent% $_readinessLabel',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                style: AppTypography.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('$cookingTimeMinutes นาที', style: AppTypography.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
