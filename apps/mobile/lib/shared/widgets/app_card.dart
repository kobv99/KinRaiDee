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
      // The Material must sit between this opaque decoration and [child],
      // not merely somewhere above it in the tree: a ListTile-family widget
      // (ListTile, CheckboxListTile, ExpansionTile, ...) paints its ink and
      // background onto its nearest Material ancestor, but that paint layer
      // is still covered by any opaque box between the Material and the
      // ListTile — an ancestor Material alone does not fix it. Wrapping
      // [child] itself in a transparent Material (mirroring how Flutter's
      // own Card does it) puts the Material on the correct side.
      child: Material(color: Colors.transparent, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: content,
      ),
    );
  }
}
