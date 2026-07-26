import 'package:flutter/material.dart';

import 'summary_card.dart';

class DashboardSummary extends StatelessWidget {
  const DashboardSummary({
    super.key,
    required this.totalIngredients,
    required this.expiringSoonIngredients,
    required this.expiredIngredients,
    required this.categories,
  });

  final int totalIngredients;
  final int expiringSoonIngredients;
  final int expiredIngredients;
  final int categories;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                icon: Icons.inventory_2_outlined,
                title: 'วัตถุดิบทั้งหมด',
                value: '$totalIngredients',
                unit: 'รายการ',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                icon: Icons.schedule_outlined,
                title: 'ใกล้หมดอายุ',
                value: '$expiringSoonIngredients',
                unit: 'รายการ',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                icon: Icons.warning_amber_rounded,
                title: 'หมดอายุแล้ว',
                value: '$expiredIngredients',
                unit: 'รายการ',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                icon: Icons.category_outlined,
                title: 'หมวดหมู่',
                value: '$categories',
                unit: 'หมวด',
              ),
            ),
          ],
        );
      },
    );
  }
}
