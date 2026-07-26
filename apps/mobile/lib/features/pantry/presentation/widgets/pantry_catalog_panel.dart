import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/models/food_category.dart';
import '../../domain/services/pantry_search_engine.dart';
import 'search_highlight_text.dart';

class PantryCatalogPanel extends StatelessWidget {
  const PantryCatalogPanel({
    required this.suggestions,
    required this.searchQuery,
    required this.onSelected,
    super.key,
  });

  final List<FoodCatalogItem> suggestions;
  final String searchQuery;
  final ValueChanged<FoodCatalogItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = suggestions[index];
            final match = PantrySearchEngine.matchCatalogItem(
              entry,
              searchQuery,
            );
            final matchedAlias = match.matchedThroughAlias
                ? match.matchedAlias
                : null;

            return ListTile(
              dense: true,
              leading: Text(
                entry.item.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: SearchHighlightText(
                text: entry.item.name,
                query: searchQuery,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchHighlightText(
                    text: entry.category,
                    query: searchQuery,
                    style: AppTextStyles.bodySmall,
                  ),
                  if (matchedAlias != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'ตรงกับคำค้น “$matchedAlias”',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.add_circle_outline_rounded),
              onTap: () => onSelected(entry),
            );
          },
        ),
      ),
    );
  }
}
