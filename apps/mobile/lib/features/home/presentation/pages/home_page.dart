import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../widgets/dashboard_summary.dart';
import '../widgets/daily_summary_metrics.dart';
import '../widgets/empty_dashboard.dart';
import '../widgets/expiry_overview.dart';
import '../widgets/no_priority_ingredients.dart';
import '../widgets/priority_ingredient_card.dart';
import '../widgets/top_picks_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onOpenPantry, this.onOpenRecipes});

  final VoidCallback onOpenPantry;

  /// Optional: falls back to [onOpenPantry]'s sibling tab if not provided,
  /// so this widget stays usable in isolation/tests without a full nav
  /// shell wired up.
  final VoidCallback? onOpenRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(pantryProvider);

    // --- Existing pantry-expiry logic, unchanged ---------------------------
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

    // --- New: recipe summary numbers, derived from the EXISTING matcher ----
    final recipeMatches = ref.watch(recipeMatchesProvider);
    final totalRecipes = recipeMatches.maybeWhen(
      data: (matches) => matches.length,
      orElse: () => 0,
    );
    final readyToCookCount = recipeMatches.maybeWhen(
      data: (matches) => matches.where((m) => m.canCook).length,
      orElse: () => 0,
    );
    final quickRecipeCount = recipeMatches.maybeWhen(
      data: (matches) =>
          matches.where((m) => m.recipe.cookTimeMinutes > 0 && m.recipe.cookTimeMinutes <= 30).length,
      orElse: () => 0,
    );

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
                    Text(_greeting(), style: AppTypography.body),
                    const SizedBox(height: 2),
                    Text(
                      'วันนี้อยากกินอะไรดี?',
                      style: AppTypography.headline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildDashboardMessage(
                        expiredCount: expiredIngredients.length,
                        expiringSoonCount: expiringSoonIngredients.length,
                      ),
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DailySummaryMetrics(
                      totalRecipes: totalRecipes,
                      readyToCookCount: readyToCookCount,
                      quickRecipeCount: quickRecipeCount,
                      expiringSoonCount: expiringSoonIngredients.length,
                      onOpenRecipes: onOpenRecipes ?? onOpenPantry,
                      onOpenPantry: onOpenPantry,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const TopPicksSection(),
                    const SizedBox(height: AppSpacing.xxl),
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
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ควรใช้ก่อน 🔥',
                            style: AppTypography.title,
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

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'สวัสดีตอนเช้า 🌤️';
  if (hour < 17) return 'สวัสดีตอนบ่าย ☀️';
  return 'สวัสดีตอนเย็น 🌇';
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

  return 'เราคัดสรรเมนูที่เหมาะกับวัตถุดิบในตู้เย็นให้คุณ';
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
