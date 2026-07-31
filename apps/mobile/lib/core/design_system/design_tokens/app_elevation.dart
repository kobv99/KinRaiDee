import 'package:flutter/material.dart';

/// Soft, subtle elevation. KinRaiDee avoids heavy shadows — these are
/// intentionally low-opacity, low-blur values.
class AppElevation {
  AppElevation._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x0F2B2725),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x142B2725),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
