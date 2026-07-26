import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/food_category.dart';

class PantryFrequentSection extends StatelessWidget {
  const PantryFrequentSection({
    required this.items,
    required this.onItemTap,
    required this.onRemove,
    super.key,
  });

  final List<FoodCatalogItem> items;
  final ValueChanged<FoodCatalogItem> onItemTap;
  final ValueChanged<FoodCatalogItem> onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'ซื้อประจำ',
          subtitle: 'แตะเพื่อเพิ่มเข้าคลังอีกครั้ง โดยไม่ต้องค้นหาใหม่',
          icon: Icons.shopping_basket_outlined,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = items[index];

              return SizedBox(
                width: 176,
                child: AppCard(
                  onTap: () => onItemTap(entry),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: Text(
                          entry.item.emoji,
                          style: const TextStyle(fontSize: 27),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              entry.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'แตะเพื่อเพิ่ม',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'นำออกจากซื้อประจำ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onRemove(entry),
                        icon: const Icon(
                          Icons.star_rounded,
                          size: 21,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
