import 'package:flutter/material.dart';

class ExpiryOverview extends StatelessWidget {
  const ExpiryOverview({
    super.key,
    required this.expired,
    required this.withinThreeDays,
    required this.withinSevenDays,
    required this.safe,
  });

  final int expired;
  final int withinThreeDays;
  final int withinSevenDays;
  final int safe;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ภาพรวมวันหมดอายุ',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _OverviewRow(
              icon: Icons.error_outline,
              label: 'หมดอายุแล้ว',
              value: expired,
            ),
            const Divider(height: 20),
            _OverviewRow(
              icon: Icons.local_fire_department_outlined,
              label: 'ภายใน 3 วัน',
              value: withinThreeDays,
            ),
            const Divider(height: 20),
            _OverviewRow(
              icon: Icons.schedule_outlined,
              label: 'ภายใน 4–7 วัน',
              value: withinSevenDays,
            ),
            const Divider(height: 20),
            _OverviewRow(
              icon: Icons.check_circle_outline,
              label: 'ยังปลอดภัย',
              value: safe,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 22, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          '$value รายการ',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
