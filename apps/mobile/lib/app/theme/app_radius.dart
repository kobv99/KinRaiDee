import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));

  static const BorderRadius largeCard = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
}
