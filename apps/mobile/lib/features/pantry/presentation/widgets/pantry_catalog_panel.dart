import 'package:flutter/material.dart';

import '../../domain/models/food_category.dart';

class PantryCatalogPanel extends StatelessWidget {
  const PantryCatalogPanel({
    required this.suggestions,
    required this.onSelected,
    super.key,
  });

  final List<FoodCatalogItem> suggestions;
  final ValueChanged<FoodCatalogItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = suggestions[index];
            return ListTile(
              dense: true,
              leading: Text(
                entry.item.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(entry.item.name),
              subtitle: Text(entry.category),
              trailing: const Icon(Icons.add_circle_outline_rounded),
              onTap: () => onSelected(entry),
            );
          },
        ),
      ),
    );
  }
}
