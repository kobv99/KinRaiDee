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
                    !item.canCook &&
                    item.missingIngredients.where((e) => e.required).length <=
                        2,
              )
              .toList();
          final needMore = items
              .where(
                (item) =>
                    !canCook.contains(item) && !almostReady.contains(item),
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
                  'เลือกจากวัตถุดิบที่มีอยู่',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ระบบจะจัดอันดับเมนู และบอกว่ายังขาดวัตถุดิบอะไร',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _RecipeSection(
                  title: 'ทำได้ทันที',
                  icon: Icons.check_circle_outline,
                  emptyMessage: 'ยังไม่มีเมนูที่วัตถุดิบครบ',
                  matches: canCook,
                ),
                const SizedBox(height: 24),
                _RecipeSection(
                  title: 'ซื้อเพิ่มนิดเดียว',
                  icon: Icons.shopping_basket_outlined,
                  emptyMessage: 'ยังไม่มีเมนูที่ขาดเพียง 1–2 อย่าง',
                  matches: almostReady,
                ),
                const SizedBox(height: 24),
                _RecipeSection(
                  title: 'ยังขาดหลายอย่าง',
                  icon: Icons.inventory_2_outlined,
                  emptyMessage: 'ไม่มีรายการเพิ่มเติม',
                  matches: needMore,
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

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.matches,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<RecipeMatch> matches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              child: _RecipeMatchCard(match: match),
            ),
          ),
      ],
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final requiredMissing = match.missingIngredients
        .where((ingredient) => ingredient.required)
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(match.recipe.emoji)),
        title: Text(
          match.recipe.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          requiredMissing.isEmpty
              ? 'วัตถุดิบหลักครบแล้ว'
              : 'ขาด ${requiredMissing.length} อย่าง',
        ),
        trailing: _ScoreBadge(score: match.scorePercent),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (match.recipe.description.isNotEmpty) ...[
            Text(match.recipe.description),
            const SizedBox(height: 12),
          ],
          if (requiredMissing.isNotEmpty) ...[
            Text(
              'วัตถุดิบที่ขาด',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...requiredMissing.map(
              (ingredient) => Text(
                '• ${ingredient.name} ${_formatQuantity(ingredient.quantity)} ${ingredient.unit}',
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'วิธีทำ',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...match.recipe.steps.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.$1 + 1}. ${entry.$2}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
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
