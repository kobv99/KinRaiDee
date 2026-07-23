import 'package:flutter/material.dart';

import '../../../../core/models/ingredient.dart';
import 'expiry_badge.dart';

class PriorityIngredientCard extends StatelessWidget {
  const PriorityIngredientCard({
    super.key,
    required this.ingredient,
    required this.onTap,
  });

  final Ingredient ingredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = ingredient.daysUntilExpiry;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            ingredient.emoji.trim().isEmpty ? '🥣' : ingredient.emoji,
          ),
        ),
        title: Text(
          ingredient.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_formatQuantity(ingredient.quantity)} ${ingredient.unit}',
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

String _formatQuantity(double quantity) {
  if (quantity == quantity.roundToDouble()) {
    return quantity.toInt().toString();
  }

  return quantity
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
