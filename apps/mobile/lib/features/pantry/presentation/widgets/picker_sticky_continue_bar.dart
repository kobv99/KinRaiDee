import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

/// Sticky bottom action shown whenever the picker session has at least one
/// selected ingredient. Always shows the current count so nothing about
/// the batch size is silent.
class PickerStickyContinueBar extends StatelessWidget {
  const PickerStickyContinueBar({
    super.key,
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          key: const ValueKey<String>('ingredient-picker-continue-button'),
          onPressed: onPressed,
          child: Text('เพิ่มวัตถุดิบ $selectedCount รายการ'),
        ),
      ),
    );
  }
}
