import 'package:flutter/material.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.days});

  final int? days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String label;

    if (days == null) {
      label = 'ไม่ระบุ';
    } else if (days == 0) {
      label = 'หมดอายุวันนี้';
    } else {
      label = 'เหลือ $days วัน';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
