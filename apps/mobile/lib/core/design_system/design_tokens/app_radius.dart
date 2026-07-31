import 'package:flutter/material.dart';

/// Corner radius scale for KinRaiDee surfaces and controls.
class AppRadius {
  AppRadius._();

  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double pill = 999;

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(large));
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(extraLarge));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));

  // Legacy aliases (lib/app/theme/app_radius.dart re-exports this file).
  static const double xs = small;
  static const double sm = medium;
  static const double md = large;
  static const double lg = extraLarge;
  static const BorderRadius card = largeRadius; // was BorderRadius.circular(md=16)
  static const BorderRadius largeCard = extraLargeRadius;
  static const BorderRadius button = mediumRadius; // was BorderRadius.circular(sm=12)

}
