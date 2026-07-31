/// Spacing scale for KinRaiDee. All layout gaps, padding, and margins
/// should be built from these values so spacing stays visually consistent
/// across every screen.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Primary horizontal page padding, phone width.
  static const double pageHorizontalPhone = 16;

  /// Primary horizontal page padding, tablet width.
  static const double pageHorizontalTablet = 28;

  // Legacy aliases (lib/app/theme/app_spacing.dart re-exports this file).
  static const double xxs = xs; // 4
  static const double screenHorizontal = xl; // 20
  static const double screenVertical = xxl; // 24
  // Note: legacy xs(8)->sm, sm(12)->md, md(16)->lg, lg(24)->xxl, xl(32)->xxxl,
  // xxl(48)->giant already match this scale's existing named values 1:1.
}
