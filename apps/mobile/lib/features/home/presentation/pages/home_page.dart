import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../shopping/presentation/widgets/recommended_purchases_section.dart';
import '../widgets/dashboard_summary.dart';
import '../widgets/empty_dashboard.dart';
import '../widgets/expiry_overview.dart';
import '../widgets/no_priority_ingredients.dart';
import '../widgets/priority_ingredient_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onOpenPantry});

  final VoidCallback onOpenPantry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(pantryProvider);

    final expiredIngredients = ingredients
        .where((ingredient) => ingredient.isExpired)
        .toList(growable: false);

    final expiringSoonIngredients =
        ingredients
            .where((ingredient) {
              final days = ingredient.daysUntilExpiry;

              if (days == null || ingredient.isExpired) {
                return false;
              }

              return days <= 7;
            })
            .toList(growable: false)
          ..sort(_compareExpiryDate);

    final expiringWithinThreeDays = expiringSoonIngredients.where((ingredient) {
      final days = ingredient.daysUntilExpiry;
      return days != null && days <= 3;
    }).length;

    final expiringWithinSevenDays =
        expiringSoonIngredients.length - expiringWithinThreeDays;

    final safeIngredients = ingredients.where((ingredient) {
      if (ingredient.isExpired) {
        return false;
      }

      final days = ingredient.daysUntilExpiry;
      return days == null || days > 7;
    }).length;

    final categories = ingredients
        .map((ingredient) => ingredient.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet();

    final priorityIngredients = expiringSoonIngredients
        .take(3)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('KinRaiDee 🍳')),
      body: SafeArea(
        child: ingredients.isEmpty
            ? EmptyDashboard(onOpenPantry: onOpenPantry)
            : RefreshIndicator(
                onRefresh: () {
                  return ref.read(pantryProvider.notifier).reload();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      'สวัสดี 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildDashboardMessage(
                        expiredCount: expiredIngredients.length,
                        expiringSoonCount: expiringSoonIngredients.length,
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DashboardSummary(
                      totalIngredients: ingredients.length,
                      expiringSoonIngredients: expiringSoonIngredients.length,
                      expiredIngredients: expiredIngredients.length,
                      categories: categories.length,
                    ),
                    const SizedBox(height: 20),
                    ExpiryOverview(
                      expired: expiredIngredients.length,
                      withinThreeDays: expiringWithinThreeDays,
                      withinSevenDays: expiringWithinSevenDays,
                      safe: safeIngredients,
                    ),
                    const RecommendedPurchasesSection(),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ควรใช้ก่อน 🔥',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: onOpenPantry,
                          child: const Text('เปิด Pantry →'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (priorityIngredients.isEmpty)
                      const NoPriorityIngredients()
                    else
                      ...priorityIngredients.map(
                        (ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PriorityIngredientCard(
                            ingredient: ingredient,
                            onTap: onOpenPantry,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onOpenPantry,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('เปิดคลังวัตถุดิบ'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

String _buildDashboardMessage({
  required int expiredCount,
  required int expiringSoonCount,
}) {
  if (expiredCount > 0) {
    return 'มีวัตถุดิบหมดอายุแล้ว $expiredCount รายการ ควรตรวจสอบก่อนใช้งาน';
  }

  if (expiringSoonCount > 0) {
    return 'วันนี้มีวัตถุดิบใกล้หมดอายุ $expiringSoonCount รายการ';
  }

  return 'วัตถุดิบของคุณยังอยู่ในสถานะที่ดี';
}

int _compareExpiryDate(Ingredient first, Ingredient second) {
  final firstExpiry = first.expiryDate;
  final secondExpiry = second.expiryDate;

  if (firstExpiry == null && secondExpiry == null) {
    return first.name.compareTo(second.name);
  }

  if (firstExpiry == null) {
    return 1;
  }

  if (secondExpiry == null) {
    return -1;
  }

  return firstExpiry.compareTo(secondExpiry);
}
