/// Motion durations and curves used across KinRaiDee.
///
/// Animations should be lightweight and never slow down navigation.
/// Screens that need to respect reduced-motion accessibility settings
/// should check `MediaQuery.of(context).disableAnimations` and fall back
/// to [none] when true.
library;

import 'package:flutter/animation.dart';

class AppMotion {
  AppMotion._();

  static const Duration none = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 280);

  static const Curve standardCurve = Curves.easeInOut;
  static const Curve emphasizedCurve = Curves.easeOutCubic;
}
