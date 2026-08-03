import 'package:flutter/material.dart';

/// Keeps a full-width call-to-action (e.g. an [AppButton] with the default
/// `expand: true`) genuinely full-width on phone, but caps it to [maxWidth]
/// on tablet/desktop instead of letting it stretch across the whole
/// (already [ResponsiveContent]-capped) content column.
class ResponsiveCta extends StatelessWidget {
  const ResponsiveCta({
    super.key,
    required this.child,
    this.maxWidth = 360,
    this.breakpoint = 768,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final double maxWidth;
  final double breakpoint;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) return child;
    return Align(
      alignment: alignment,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
