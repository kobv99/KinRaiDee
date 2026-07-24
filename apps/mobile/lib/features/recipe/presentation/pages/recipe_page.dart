import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recipe_ingredient.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../providers/recipe_provider.dart';

class RecipePage extends ConsumerWidget {
  const RecipePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(smartRecommendationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ทำอะไรกินดี 🍳')),
      body: recommendation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (result) {
          if (!result.requestedSelectionAvailable) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(heroSelectionProvider.notifier).useAutomatic();
            });
          }

          if (!result.hasHero) {
            return RefreshIndicator(
              onRefresh: () => _reload(ref),
              child: const _NoHeroView(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _reload(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _HeroIngredientCard(
                  hero: result.hero!,
                  selectionMode: result.heroSelectionMode,
                  reason: result.heroReason,
                  onChange: () => _showHeroPicker(
                    context,
                    ref,
                    result.heroOptions,
                    result.hero!,
                    result.heroSelectionMode,
                  ),
                  onTogglePin: () async {
                    final notifier = ref.read(heroSelectionProvider.notifier);
                    if (result.isPinned) {
                      await notifier.useAutomatic();
                    } else {
                      await notifier.pin(result.hero!.key);
                    }
                    ref.read(recommendationSessionProvider.notifier).reset();
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${result.primaryMatches.length} เมนูที่น่าลองจาก${result.hero!.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${result.totalHeroRecipes} เมนู',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'สุ่มเป็นชุดไม่ซ้ำ และเรียงในแต่ละชุดจากเปอร์เซ็นต์สูงไปต่ำ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...result.primaryMatches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecipeMatchCard(match: match),
                  ),
                ),
                if (result.canRefresh) ...[
                  const SizedBox(height: 4),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      ref
                          .read(recommendationSessionProvider.notifier)
                          .showNext(result.totalHeroRecipes);
                    },
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(
                      result.pageIndex + 1 >= result.pageCount
                          ? 'แนะนำใหม่อีกชุด'
                          : 'แนะนำใหม่ ไม่ซ้ำชุดเดิม',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'ชุด ${result.pageIndex + 1} จาก ${result.pageCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (result.moreMatches.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _MoreRecipesSection(matches: result.moreMatches),
                ],
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

  Future<void> _reload(WidgetRef ref) async {
    ref.read(recommendationSessionProvider.notifier).reset();
    ref.invalidate(recipesProvider);
    await ref.read(recipeMatchesProvider.future);
  }

  Future<void> _showHeroPicker(
    BuildContext context,
    WidgetRef ref,
    List<HeroIngredientOption> options,
    HeroIngredientOption activeHero,
    HeroSelectionMode activeMode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetHeight =
            (MediaQuery.sizeOf(sheetContext).height * 0.72)
                .clamp(360.0, 640.0)
                .toDouble();

        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'วันนี้อยากเน้นวัตถุดิบอะไร?',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'แตะเพื่อใช้ครั้งนี้ หรือกดหมุดเพื่อจำไว้ครั้งต่อไป',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.auto_awesome_outlined),
                        ),
                        title: const Text('ให้ระบบเลือกอัตโนมัติ'),
                        subtitle: const Text(
                          'ดูของใกล้หมดอายุ ความพร้อม และเมนูที่ทำได้',
                        ),
                        trailing: activeMode == HeroSelectionMode.automatic
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () async {
                          await ref
                              .read(heroSelectionProvider.notifier)
                              .useAutomatic();
                          ref
                              .read(recommendationSessionProvider.notifier)
                              .reset();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                      const Divider(),
                      ...options.map(
                        (option) => ListTile(
                          leading: CircleAvatar(child: Text(option.emoji)),
                          title: Text(option.name),
                          subtitle: Text(_heroOptionSubtitle(option)),
                          selected:
                              activeMode != HeroSelectionMode.automatic &&
                              activeHero.key == option.key,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (activeMode != HeroSelectionMode.automatic &&
                                  activeHero.key == option.key)
                                const Icon(Icons.check_circle_outline),
                              IconButton(
                                tooltip: 'ปักหมุดเป็นวัตถุดิบหลัก',
                                onPressed: () async {
                                  await ref
                                      .read(heroSelectionProvider.notifier)
                                      .pin(option.key);
                                  ref
                                      .read(
                                        recommendationSessionProvider.notifier,
                                      )
                                      .reset();
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                                icon: Icon(
                                  activeMode == HeroSelectionMode.pinned &&
                                          activeHero.key == option.key
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await ref
                                .read(heroSelectionProvider.notifier)
                                .selectForSession(option.key);
                            ref
                                .read(recommendationSessionProvider.notifier)
                                .reset();
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroIngredientCard extends StatelessWidget {
  const _HeroIngredientCard({
    required this.hero,
    required this.selectionMode,
    required this.reason,
    required this.onChange,
    required this.onTogglePin,
  });

  final HeroIngredientOption hero;
  final HeroSelectionMode selectionMode;
  final String reason;
  final VoidCallback onChange;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPinned = selectionMode == HeroSelectionMode.pinned;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Text(hero.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วันนี้ ${hero.name} เป็นพระเอก!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'พบ ${hero.recipeCount} เมนูที่เกี่ยวข้องโดยตรง',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _selectionIcon(selectionMode),
                        size: 16,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              TextButton(onPressed: onChange, child: const Text('เปลี่ยน')),
              IconButton(
                tooltip: isPinned ? 'กลับไปให้ระบบเลือก' : 'ปักหมุดวัตถุดิบนี้',
                onPressed: onTogglePin,
                icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreRecipesSection extends StatelessWidget {
  const _MoreRecipesSection({required this.matches});

  final List<RecipeMatch> matches;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.add_circle_outline),
        title: const Text(
          'เมนูเพิ่มเติมจากวัตถุดิบที่มี',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${matches.length} เมนู — เรียงตามเปอร์เซ็นต์'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: matches
            .map(
              (match) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _RecipeMatchCard(match: match, compact: true),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({required this.match, this.compact = false});

  final RecipeMatch match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final requiredMissing = match.missingRequiredIngredients;
    final optionalMissing = match.missingOptionalIngredients;

    return Card(
      margin: EdgeInsets.zero,
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
            children: [
              _InfoChip(
                icon: match.canCook
                    ? Icons.check_circle_outline
                    : Icons.shopping_basket_outlined,
                label: match.canCook
                    ? 'พร้อมทำ'
                    : 'ขาด ${match.missingRequiredCount} อย่าง',
                emphasized: true,
              ),
              if (match.recipe.cookTimeMinutes > 0)
                _InfoChip(
                  icon: Icons.schedule,
                  label: '${match.recipe.cookTimeMinutes} นาที',
                ),
              if (!compact)
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'ครบ ${match.scorePercent}%',
                ),
            ],
          ),
        ),
        trailing: _ScoreBadge(score: match.scorePercent),
        children: [
          const Divider(height: 20),
          Text(
            _recommendationReason(match),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (match.recipe.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(match.recipe.description),
          ],
          if (requiredMissing.isNotEmpty) ...[
            const SizedBox(height: 14),
            _IngredientList(
              title: 'วัตถุดิบหลักที่ต้องซื้อ',
              ingredients: requiredMissing,
            ),
          ],
          if (optionalMissing.isNotEmpty) ...[
            const SizedBox(height: 14),
            _IngredientList(
              title: 'วัตถุดิบเสริมที่ยังขาด',
              ingredients: optionalMissing,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'วิธีทำ',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
        color: emphasized ? colors.secondaryContainer : colors.surfaceContainer,
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$score%',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.title, required this.ingredients});

  final String title;
  final List<RecipeIngredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...ingredients.map(
          (ingredient) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• ${ingredient.name} ${_formatQuantity(ingredient.quantity)} ${ingredient.unit}'
                  .trim(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoHeroView extends StatelessWidget {
  const _NoHeroView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.kitchen_outlined, size: 72),
        const SizedBox(height: 18),
        Text(
          'ยังไม่พบเมนูจากวัตถุดิบหลักของคุณ',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'ลองเพิ่มกุ้ง หมู ไก่ ปลาหมึก หรือไข่ใน Pantry แล้วกลับมาหน้านี้อีกครั้ง',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
            const Text(
              'โหลดเมนูไม่สำเร็จ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}

String _heroOptionSubtitle(HeroIngredientOption option) {
  final parts = <String>['${option.recipeCount} เมนู'];
  if (option.readyCount > 0) {
    parts.add('พร้อมทำ ${option.readyCount}');
  } else {
    parts.add('ดีที่สุด ${option.bestScorePercent}%');
  }
  final days = option.daysUntilExpiry;
  if (days != null && days <= 7) {
    parts.add(days <= 0 ? 'ควรใช้วันนี้' : 'หมดอายุใน $days วัน');
  }
  return parts.join(' · ');
}

IconData _selectionIcon(HeroSelectionMode mode) {
  switch (mode) {
    case HeroSelectionMode.automatic:
      return Icons.auto_awesome_outlined;
    case HeroSelectionMode.manual:
      return Icons.touch_app_outlined;
    case HeroSelectionMode.pinned:
      return Icons.push_pin;
  }
}

String _recommendationReason(RecipeMatch match) {
  if (match.canCook && match.missingOptionalCount == 0) {
    return 'แนะนำเพราะคุณมีวัตถุดิบครบ พร้อมลงมือทำได้เลย';
  }
  if (match.canCook) {
    return 'วัตถุดิบหลักครบแล้ว ขาดเพียงของเสริม ${match.missingOptionalCount} อย่าง';
  }
  if (match.missingRequiredCount == 1) {
    return 'มีวัตถุดิบเกือบครบ ซื้อเพิ่มอีกเพียง 1 อย่าง';
  }
  return 'ใช้วัตถุดิบหลักที่คุณมี และต้องซื้อเพิ่ม ${match.missingRequiredCount} อย่าง';
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}