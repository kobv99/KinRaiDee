import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';

/// Shimmering placeholder block. Compose several of these to build a
/// skeleton layout that matches the shape of the real content
/// (per spec: "avoid using only a centered spinner for full-page loading").
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.smallRadius,
  });

  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: widget.radius,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.6 + (_controller.value * 0.3);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted.withValues(alpha: opacity),
            borderRadius: widget.radius,
          ),
        );
      },
    );
  }
}

/// Preset skeleton matching a recipe card shape, for Home screen loading.
class AppRecipeCardSkeleton extends StatelessWidget {
  const AppRecipeCardSkeleton({super.key, this.width = 144});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(
            width: width,
            height: width,
            radius: AppRadius.largeRadius,
          ),
          const SizedBox(height: 8),
          AppSkeleton(width: width * 0.8, height: 14),
          const SizedBox(height: 6),
          AppSkeleton(width: width * 0.5, height: 12),
        ],
      ),
    );
  }
}
