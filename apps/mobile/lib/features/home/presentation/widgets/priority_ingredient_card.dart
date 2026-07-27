import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/presentation/ingredient_presentation.dart';
import '../../../../core/presentation/unit_presentation.dart';
import 'expiry_badge.dart';

class PriorityIngredientCard extends ConsumerWidget {
  const PriorityIngredientCard({
    super.key,
    required this.ingredient,
    required this.onTap,
  });

  final Ingredient ingredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ingredient.daysUntilExpiry;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            IngredientPresentation.emoji(
              ingredient,
              ref.watch(canonicalIngredientRegistryProvider),
            ),
          ),
        ),
        title: Text(
          ingredient.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          UnitPresentation.quantity(
            ingredient.quantity,
            ingredient.canonicalUnitId.isEmpty
                ? ingredient.unit
                : ingredient.canonicalUnitId,
            maximumFractionDigits: 2,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExpiryBadge(days: days),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
