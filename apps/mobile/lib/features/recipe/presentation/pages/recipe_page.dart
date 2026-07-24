import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recipe_match.dart';
import '../providers/recipe_provider.dart';

class RecipePage extends ConsumerWidget {
  const RecipePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(recipeMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('เมนูแนะนำ 🍳')),
      body: matches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyRecipeView();
          }

          final canCook = items.where((item) => item.canCook).toList();
          final almostReady = items
              .where(
                (item) =>
                    !item.canCook && item.missingRequiredCount <= 2,
              )
              .toList();
          final needMore = items
              .where(
                (item) =>
                    !item.canCook && item.missingRequiredCount > 2,
              )
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recipesProvider);
              await ref.read(recipeMatchesProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  _buildHeadline(canCook.length, almostReady.length),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'เลือกเมนูจากวัตถุดิบที่มี และดูของที่ต้องซื้อเพิ่มได้ทันที',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _RecipeSummary(
                  canCookCount: canCook.length,
                  almostReadyCount: almostReady.length,
                  needMoreCount: needMore.length,
                ),
                const SizedBox(height: 24),
                _RecipeSection(
                  title: 'ทำได้ทันที',
                  icon: Icons.check_circle_outline,
                  emptyMessage: 'ยังไม่มีเมนูที่วัตถุดิบหลักครบ',
                  matches: canCook,
                  status: _RecipeStatus.ready,
                ),
                const SizedBox(height: 24),
                _RecipeSection(
                  title: 'ซื้อเพิ่มนิดเดียว',
                  icon: Icons.shopping_basket_outlined,
                  emptyMessage: 'ยังไม่มีเมนูที่ขาดเพียง 1–2 อย่าง',
                  matches: almostReady,
                  status: _RecipeStatus.almostReady,
                ),
                const SizedBox(height: 24),
                _RecipeSection(
                  title: 'ยังขาดหลายอย่าง',
                  icon: Icons.inventory_2_outlined,
                  emptyMessage: 'ไม่มีรายการเพิ่มเติม',
                  matches: needMore,
                  status: _RecipeStatus.needMore,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('ค้นหาสูตรใหม่ด้วย AI — เร็ว ๆ นี้'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _buildHeadline(int canCookCount, int almostReadyCount) {
  if (canCookCount > 0) {
    return 'วันนี้คุณทำได้ $canCookCount เมนูทันที';
  }

  if (almostReadyCount > 0) {
    return 'ซื้อเพิ่มนิดเดียว ก็ทำได้ $almostReadyCount เมนู';
  }

  return 'มาดูกันว่าวันนี้ทำอะไรกินดี';
}

enum _RecipeStatus { ready, almostReady, needMore }

class _RecipeSummary extends StatelessWidget {
  const _RecipeSummary({
    required this.canCookCount,
    required this.almostReadyCount,
    required this.needMoreCount,
  });

  final int canCookCount;
  final int almostReadyCount;
  final int needMoreCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _SummaryItem(
            icon: Icons.check_circle_outline,
            label: 'พร้อมทำ',
            count: canCookCount,
          ),
          _SummaryItem(
            icon: Icons.shopping_basket_outlined,
            label: 'ซื้อเพิ่ม',
            count: almostReadyCount,
          ),
          _SummaryItem(
            icon: Icons.inventory_2_outlined,
            label: 'ยังขาด',
            count: needMoreCount,
          ),
        ];

        if (constraints.maxWidth < 520) {
          return Row(
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: card,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }

        return Row(
          children: cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: card,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.matches,
    required this.status,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<RecipeMatch> matches;
  final _RecipeStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${matches.length} เมนู',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(emptyMessage),
          )
        else
          ...matches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecipeMatchCard(match: match, status: status),
            ),
          ),
      ],
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({required this.match, required this.status});

  final RecipeMatch match;
  final _RecipeStatus status;

  @override
  Widget build(BuildContext context) {
    final requiredMissing = match.missingRequiredIngredients;
    final optionalMissing = match.missingOptionalIngredients;
    final totalIngredients = match.recipe.ingredients.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(child: Text(match.recipe.emoji)),
        title: Text(
          match.recipe.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(status: status, match: match),
              _InfoChip(
                icon: Icons.restaurant_menu,
                label: '$totalIngredients วัตถุดิบ',
              ),
            ],
          ),
        ),
        trailing: _ScoreBadge(score: match.scorePercent, status: status),
        children: [
          const Divider(height: 20),
          if (match.recipe.description.isNotEmpty) ...[
            Text(match.recipe.description),
            const SizedBox(height: 12),
          ],
          if (requiredMissing.isNotEmpty) ...[
            _IngredientList(
              title: 'วัตถุดิบหลักที่ต้องซื้อ',
              ingredients: requiredMissing,
            ),
            const SizedBox(height: 12),
          ],
          if (optionalMissing.isNotEmpty) ...[
            _IngredientList(
              title: 'วัตถุดิบเสริมที่ยังขาด',
              ingredients: optionalMissing,
            ),
            const SizedBox(height: 12),
          ],
          if (match.missingIngredients.isEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('วัตถุดิบครบทุกอย่าง พร้อมลงมือทำ')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'วิธีทำ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...match.recipe.steps.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${entry.$1 + 1}. ${entry.$2}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.match});

  final _RecipeStatus status;
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      _RecipeStatus.ready => (
          Icons.check_circle_outline,
          match.missingOptionalCount == 0
              ? 'พร้อมทำ วัตถุดิบครบ'
              : 'พร้อมทำ ขาดของเสริม ${match.missingOptionalCount}',
        ),
      _RecipeStatus.almostReady => (
          Icons.shopping_basket_outlined,
          'ซื้อเพิ่ม ${match.missingRequiredCount} อย่าง',
        ),
      _RecipeStatus.needMore => (
          Icons.inventory_2_outlined,
          'ขาด ${match.missingRequiredCount} อย่าง',
        ),
    };

    return _InfoChip(icon: icon, label: label, emphasized: true);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? colors.secondaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.title, required this.ingredients});

  final String title;
  final List<dynamic> ingredients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...ingredients.map(
          (ingredient) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• ${ingredient.name} ${_formatQuantity(ingredient.quantity)} ${ingredient.unit}',
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.status});

  final int score;
  final _RecipeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = switch (status) {
      _RecipeStatus.ready => colors.primaryContainer,
      _RecipeStatus.almostReady => colors.tertiaryContainer,
      _RecipeStatus.needMore => colors.errorContainer,
    };
    final foreground = switch (status) {
      _RecipeStatus.ready => colors.onPrimaryContainer,
      _RecipeStatus.almostReady => colors.onTertiaryContainer,
      _RecipeStatus.needMore => colors.onErrorContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyRecipeView extends StatelessWidget {
  const _EmptyRecipeView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('ยังไม่มีสูตรอาหารในระบบ'),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            const Text('โหลดสูตรอาหารไม่สำเร็จ'),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}
