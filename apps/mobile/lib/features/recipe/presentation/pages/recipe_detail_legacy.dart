import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_step.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import '../widgets/pantry_deduction_sheet.dart';
import 'cooking_mode_page.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  late int _selectedServings;

  @override
  void initState() {
    super.initState();
    final baseServings = widget.recipe.servings > 0
        ? widget.recipe.servings
        : 2;
    _selectedServings = baseServings.clamp(1, 12).toInt();
  }

  void _setServings(int servings) {
    final safeServings = servings.clamp(1, 12).toInt();
    if (safeServings == _selectedServings) {
      return;
    }

    setState(() {
      _selectedServings = safeServings;
    });
  }

  Future<void> _openCookingMode() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            CookingModePage(recipe: widget.recipe, servings: _selectedServings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: widget.recipe,
      pantry: pantry,
      servings: _selectedServings,
      registry: ref.watch(canonicalIngredientRegistryProvider),
    );
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('สูตรอาหาร')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          key: const ValueKey<String>('start-cooking-button'),
          onPressed: _openCookingMode,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('เริ่มทำอาหารสำหรับ $_selectedServings คน'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _RecipeHeader(recipe: widget.recipe),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.groups_2_outlined,
            title: 'เลือกจำนวนคน',
            subtitle: 'ระบบจะคำนวณปริมาณวัตถุดิบให้ใหม่ทันที',
          ),
          const SizedBox(height: 12),
          _ServingSelector(
            servings: _selectedServings,
            onChanged: _setServings,
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.inventory_2_outlined,
            title: 'วัตถุดิบสำหรับ $_selectedServings คน',
            subtitle: servingPlan.hasEnoughRequiredIngredients
                ? 'วัตถุดิบหลักใน Pantry เพียงพอสำหรับสูตรนี้'
                : 'ยังขาดวัตถุดิบหลัก ${servingPlan.missingRequiredCount} รายการ',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < servingPlan.ingredients.length;
                  index++
                ) ...[
                  _ScaledIngredientTile(item: servingPlan.ingredients[index]),
                  if (index < servingPlan.ingredients.length - 1)
                    Divider(height: 1, color: colors.outlineVariant),
                ],
              ],
            ),
          ),
          if (!servingPlan.hasEnoughRequiredIngredients) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'คุณยังเปิดดูสูตรและเริ่มทำได้ แต่ควรตรวจวัตถุดิบที่ขาดก่อนลงมือ',
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.menu_book_outlined,
            title: 'วิธีทำ',
            subtitle: '${widget.recipe.instructions.length} ขั้นตอน',
          ),
          const SizedBox(height: 12),
          _RecipeSteps(steps: widget.recipe.instructions),
          const SizedBox(height: 24),
          _RecipeMetadata(recipe: widget.recipe),
        ],
      ),
    );
  }
}

class _RecipeHeader extends StatelessWidget {
  const _RecipeHeader({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: Text(recipe.emoji, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    recipe.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (recipe.cookTimeMinutes > 0)
                      _HeaderChip(
                        icon: Icons.schedule,
                        label: '${recipe.cookTimeMinutes} นาที',
                      ),
                    _HeaderChip(
                      icon: Icons.restaurant_menu,
                      label: _difficultyLabel(recipe.difficulty),
                    ),
                    _HeaderChip(
                      icon: Icons.groups_2_outlined,
                      label: 'สูตรตั้งต้น ${recipe.servings} คน',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServingSelector extends StatelessWidget {
  const _ServingSelector({required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ServingRangeChip(
                label: '1–2 คน',
                selected: servings <= 2,
                onSelected: () => onChanged(2),
              ),
              _ServingRangeChip(
                label: '3–4 คน',
                selected: servings >= 3 && servings <= 4,
                onSelected: () => onChanged(4),
              ),
              _ServingRangeChip(
                label: '5–6 คน',
                selected: servings >= 5 && servings <= 6,
                onSelected: () => onChanged(6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'ลดจำนวนคน',
                onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 130,
                child: Column(
                  children: [
                    Text(
                      '$servings คน',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ปรับได้ 1–12 คน',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'เพิ่มจำนวนคน',
                onPressed: servings < 12 ? () => onChanged(servings + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServingRangeChip extends StatelessWidget {
  const _ServingRangeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ScaledIngredientTile extends StatelessWidget {
  const _ScaledIngredientTile({required this.item});

  final ScaledRecipeIngredient item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusStyle = _statusStyle(item.status, colors);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: statusStyle.backgroundColor,
        foregroundColor: statusStyle.foregroundColor,
        child: Icon(statusStyle.icon, size: 21),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!item.ingredient.required)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text('เสริม'),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(_pantryStatusLabel(item)),
      ),
      trailing: Text(
        formatRecipeQuantity(item.requiredQuantity, item.ingredient.unit),
        textAlign: TextAlign.end,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _RecipeSteps extends StatelessWidget {
  const _RecipeSteps({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const _EmptySteps();
    }

    return Column(
      children: steps.indexed
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 16, child: Text('${entry.$1 + 1}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$2.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(entry.$2.accessibleInstruction),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptySteps extends StatelessWidget {
  const _EmptySteps();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('สูตรนี้ยังไม่มีข้อมูลขั้นตอนการทำ'),
      ),
    );
  }
}

class _RecipeMetadata extends StatelessWidget {
  const _RecipeMetadata({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text(recipe.category)),
        ...recipe.cookingMethods.map((method) => Chip(label: Text(method))),
        ...recipe.tags.take(3).map((tag) => Chip(label: Text(tag))),
      ],
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

_StatusStyle _statusStyle(PantryQuantityStatus status, ColorScheme colors) {
  switch (status) {
    case PantryQuantityStatus.enough:
      return _StatusStyle(
        icon: Icons.check_rounded,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      );
    case PantryQuantityStatus.insufficient:
      return _StatusStyle(
        icon: Icons.warning_amber_rounded,
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
      );
    case PantryQuantityStatus.missing:
      return _StatusStyle(
        icon: Icons.shopping_basket_outlined,
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      );
    case PantryQuantityStatus.incompatibleUnit:
      return _StatusStyle(
        icon: Icons.compare_arrows_rounded,
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
      );
  }
}

String _pantryStatusLabel(ScaledRecipeIngredient item) {
  switch (item.status) {
    case PantryQuantityStatus.enough:
      return 'มี ${formatRecipeQuantity(item.pantryQuantityInRecipeUnit ?? 0, item.ingredient.unit)} • เพียงพอ';
    case PantryQuantityStatus.insufficient:
      return 'มี ${formatRecipeQuantity(item.pantryQuantityInRecipeUnit ?? 0, item.ingredient.unit)} • ขาด ${formatRecipeQuantity(item.shortageQuantity, item.ingredient.unit)}';
    case PantryQuantityStatus.missing:
      return item.ingredient.required
          ? 'ยังไม่มีใน Pantry'
          : 'ยังไม่มีใน Pantry • ไม่ใส่ก็ได้';
    case PantryQuantityStatus.incompatibleUnit:
      final pantryQuantity = item.pantryDisplayQuantity ?? 0;
      final pantryUnit = UnitPresentation.label(item.pantryDisplayUnit ?? '');
      return 'มี ${formatRecipeNumber(pantryQuantity)} $pantryUnit • หน่วยไม่ตรง กรุณาตรวจจำนวนเอง';
  }
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ยาก',
    _ => difficulty,
  };
}
