/// Responsive width breakpoints (logical pixels).
class AppBreakpoints {
  AppBreakpoints._();

  static const double smallPhone = 360;
  static const double phone = 430;
  static const double tablet = 768;
  static const double desktop = 1280;

  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  static bool isPhone(double width) => width < tablet;
}
