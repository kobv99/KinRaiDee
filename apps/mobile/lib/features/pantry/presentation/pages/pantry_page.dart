import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../widgets/add_ingredient_dialog.dart';
import '../widgets/ingredient_card.dart';

class PantryPage extends ConsumerWidget {
  const PantryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(pantryProvider);

    Future<void> addIngredient() async {
      final ingredient = await showDialog<Ingredient>(
        context: context,
        builder: (context) {
          return const AddIngredientDialog();
        },
      );

      if (ingredient == null) {
        return;
      }

      ref.read(pantryProvider.notifier).addIngredient(ingredient);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('คลังวัตถุดิบ')),
      body: SafeArea(
        child: ingredients.isEmpty
            ? EmptyState(
                icon: Icons.kitchen_outlined,
                title: 'ยังไม่มีวัตถุดิบ',
                description:
                    'เพิ่มวัตถุดิบที่มีอยู่ในบ้าน เพื่อให้ KinRaiDee ช่วยแนะนำเมนูได้แม่นยำขึ้น',
                actionLabel: 'เพิ่มวัตถุดิบ',
                onActionPressed: addIngredient,
              )
            : _PantryContent(
                ingredients: ingredients,
                onDelete: (ingredient) {
                  ref
                      .read(pantryProvider.notifier)
                      .removeIngredient(ingredient.id);
                },
              ),
      ),
      floatingActionButton: ingredients.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: addIngredient,
              icon: const Icon(Icons.add_rounded),
              label: const Text('เพิ่มวัตถุดิบ'),
            ),
    );
  }
}

class _PantryContent extends StatelessWidget {
  const _PantryContent({required this.ingredients, required this.onDelete});

  final List<Ingredient> ingredients;
  final ValueChanged<Ingredient> onDelete;

  @override
  Widget build(BuildContext context) {
    final expiringCount = ingredients.where((ingredient) {
      final days = ingredient.daysUntilExpiry;

      return days != null && days <= 7;
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? AppSpacing.xl
            : AppSpacing.screenHorizontal;

        final contentWidth = constraints.maxWidth >= 1100
            ? 1000.0
            : double.infinity;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'วัตถุดิบของคุณ',
                      subtitle: _buildSubtitle(
                        totalCount: ingredients.length,
                        expiringCount: expiringCount,
                      ),
                      icon: Icons.kitchen_outlined,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.sm,
                    horizontalPadding,
                    112,
                  ),
                  sliver: SliverList.separated(
                    itemCount: ingredients.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: AppSpacing.sm);
                    },
                    itemBuilder: (context, index) {
                      final ingredient = ingredients[index];

                      return IngredientCard(
                        ingredient: ingredient,
                        onDelete: () {
                          _confirmDelete(
                            context: context,
                            ingredient: ingredient,
                            onConfirmed: () {
                              onDelete(ingredient);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildSubtitle({required int totalCount, required int expiringCount}) {
    if (expiringCount == 0) {
      return 'ทั้งหมด $totalCount รายการ';
    }

    return 'ทั้งหมด $totalCount รายการ • ใกล้หมดอายุ $expiringCount รายการ';
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required Ingredient ingredient,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ลบวัตถุดิบ'),
          content: Text('ต้องการลบ "${ingredient.name}" ออกจากคลังหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirmed();
    }
  }
}
