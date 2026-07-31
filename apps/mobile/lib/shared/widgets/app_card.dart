import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
    this.showBorder = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;
  final Color borderColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.card,
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    // Always provide a Material ancestor here, even when onTap is null.
    // AppCard wraps its child in an opaque DecoratedBox (the card
    // background), and any ListTile-family widget nested inside (ListTile,
    // CheckboxListTile, ExpansionTile, ...) needs a Material between itself
    // and that opaque box to paint its own background/ink splashes —
    // otherwise Flutter throws "ListTile background color or ink splashes
    // may be invisible" at runtime.
    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadius.card,
              child: content,
            ),
    );
  }
}
