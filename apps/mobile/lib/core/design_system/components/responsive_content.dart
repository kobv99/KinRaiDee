import 'package:flutter/material.dart';

/// Wraps primary consumer screens so they don't stretch full-width on
/// tablet/desktop. Below [breakpoint] the child renders exactly as on
/// phone (no behavior change). Above it, content is centered and capped
/// at [maxWidth].
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.breakpoint = 768,
  });

  final Widget child;
  final double maxWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
