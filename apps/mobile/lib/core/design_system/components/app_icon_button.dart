import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';

/// Compact circular icon button (back, favorite, close, notification bell).
/// Guarantees the 48dp minimum touch target even though the visible glyph
/// is smaller.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.background = AppColors.surface,
    this.foreground = AppColors.textPrimary,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color background;
  final Color foreground;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: foreground, size: 22),
                if (badge)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
