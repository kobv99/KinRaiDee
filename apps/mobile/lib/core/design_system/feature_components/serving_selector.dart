import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_typography.dart';

/// Minus / count / plus selector for "สำหรับกี่คน?".
///
/// This widget only reports the selected count via [onChanged] — recipe
/// ingredient-quantity recalculation must happen in domain logic, not here.
class ServingSelector extends StatelessWidget {
  const ServingSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 12,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          width: 72,
          alignment: Alignment.center,
          child: Column(
            children: [
              Text('$value', style: AppTypography.display),
              Text('คน', style: AppTypography.caption),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.surfaceMuted
          : AppColors.surfaceMuted.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
