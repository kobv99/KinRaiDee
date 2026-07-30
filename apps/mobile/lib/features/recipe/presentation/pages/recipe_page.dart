import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/recipe_recommendation.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_page.dart';
import 'recommendation_qa_page.dart';

class RecipePage extends ConsumerWidget {
  const RecipePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(smartRecommendationProvider);
    final recommendationDetails = switch (ref.watch(
      recipeRecommendationResultsProvider,
    )) {
      AsyncData(:final value) => value,
      _ => const <RecipeRecommendation>[],
    };
    final detailsByRecipeId = <String, RecipeRecommendation>{
      for (final item in recommendationDetails) item.match.recipe.id: item,
    };
    ref.listen(recipeRecommendationResultsProvider, (previous, next) {
      final items = switch (next) {
        AsyncData(:final value) => value,
        _ => const <RecipeRecommendation>[],
      };
      final affected = items
          .where((item) => item.expiringIngredientIds.isNotEmpty)
          .length;
      final previousAffected = switch (previous) {
        AsyncData(:final value) =>
          value.where((item) => item.expiringIngredientIds.isNotEmpty).length,
        _ => 0,
      };
      if (affected <= 0 || affected == previousAffected) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'มีวัตถุดิบใกล้หมดอายุ อัปเดตคำแนะนำ $affected เมนูแล้ว',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ทำอะไรกินดี 🍳'),
        actions: [
          IconButton(
            tooltip: 'Recommendation QA',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RecommendationQaPage(),
              ),
            ),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      body: recommendation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorView(onRetry: () => ref.invalidate(recipesProvider)),
        data: (result) {
          final query = ref.watch(recipeRecommendationQueryProvider);
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
                _RecommendationDashboardCard(
                  dashboard: RecommendationDashboard.from(
                    recommendationDetails,
                  ),
                  activeFilter: query.filter,
                  onSelected: (filter) {
                    ref
                        .read(recipeRecommendationQueryProvider.notifier)
                        .update(filter: filter);
                    ref.read(recommendationSessionProvider.notifier).reset();
                  },
                ),
                const SizedBox(height: 12),
                _RecommendationControls(
                  query: query,
                  onSort: (sort) {
                    ref
                        .read(recipeRecommendationQueryProvider.notifier)
                        .update(sort: sort);
                    ref.read(recommendationSessionProvider.notifier).reset();
                  },
                  onFilter: (filter) {
                    ref
                        .read(recipeRecommendationQueryProvider.notifier)
                        .update(filter: filter);
                    ref.read(recommendationSessionProvider.notifier).reset();
                  },
                ),
                const SizedBox(height: 12),
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
                  'แตะเมนูเพื่อเลือกจำนวนคน ดูปริมาณวัตถุดิบ และเปิดสูตรอาหาร',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...result.primaryMatches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecipeMatchCard(
                      match: match,
                      recommendation: detailsByRecipeId[match.recipe.id],
                      rankedAbove: recommendationDetails.firstOrNull,
                      onOpen: () => _openRecipeDetail(context, match),
                    ),
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
                  _MoreRecipesSection(
                    matches: result.moreMatches,
                    detailsByRecipeId: detailsByRecipeId,
                    rankedAbove: recommendationDetails.firstOrNull,
                    onOpen: (match) => _openRecipeDetail(context, match),
                  ),
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

  Future<void> _openRecipeDetail(
    BuildContext context,
    RecipeMatch match,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailPage(recipe: match.recipe),
      ),
    );
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
        final sheetHeight = (MediaQuery.sizeOf(sheetContext).height * 0.72)
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
                        'เลือกวัตถุดิบหลัก',
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
                  'วัตถุดิบหลักวันนี้: ${hero.name}',
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onPrimaryContainer),
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

class _RecommendationControls extends StatelessWidget {
  const _RecommendationControls({
    required this.query,
    required this.onSort,
    required this.onFilter,
  });

  final RecipeRecommendationQuery query;
  final ValueChanged<RecommendationSort> onSort;
  final ValueChanged<RecommendationFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final minimumMatch = query.filter.minimumMatchPercent;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('ทั้งหมด'),
          selected: minimumMatch == null,
          onSelected: (_) => onFilter(const RecommendationFilter()),
        ),
        ChoiceChip(
          label: const Text('ตรง ≥ 75%'),
          selected: minimumMatch == 75,
          onSelected: (_) =>
              onFilter(const RecommendationFilter(minimumMatchPercent: 75)),
        ),
        ChoiceChip(
          label: const Text('พร้อมครบ 100%'),
          selected: minimumMatch == 100,
          onSelected: (_) =>
              onFilter(const RecommendationFilter(minimumMatchPercent: 100)),
        ),
        PopupMenuButton<RecommendationSort>(
          initialValue: query.sort,
          onSelected: onSort,
          itemBuilder: (context) => RecommendationSort.values
              .map(
                (sort) => PopupMenuItem<RecommendationSort>(
                  value: sort,
                  child: Text(_sortLabel(sort)),
                ),
              )
              .toList(growable: false),
          child: Chip(
            avatar: const Icon(Icons.sort, size: 18),
            label: Text(_sortLabel(query.sort)),
          ),
        ),
      ],
    );
  }
}

class _RecommendationDashboardCard extends StatelessWidget {
  const _RecommendationDashboardCard({
    required this.dashboard,
    required this.activeFilter,
    required this.onSelected,
  });

  final RecommendationDashboard dashboard;
  final RecommendationFilter activeFilter;
  final ValueChanged<RecommendationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คำแนะนำวันนี้',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  key: const ValueKey<String>('dashboard-filter-all'),
                  label: 'สูตรทั้งหมด',
                  value: dashboard.totalRecipes,
                  selected: _isAll,
                  onTap: () => onSelected(const RecommendationFilter()),
                ),
                _SummaryChip(
                  key: const ValueKey<String>('dashboard-filter-ready'),
                  label: 'พร้อมครบ',
                  value: dashboard.perfectMatches,
                  selected: activeFilter.minimumMatchPercent == 100,
                  onTap: () => onSelected(
                    const RecommendationFilter(minimumMatchPercent: 100),
                  ),
                ),
                _SummaryChip(
                  key: const ValueKey<String>(
                    'dashboard-filter-pantry-friendly',
                  ),
                  label: 'Pantry Friendly',
                  value: dashboard.pantryFriendly,
                  selected: activeFilter.pantryFriendlyOnly,
                  onTap: () => onSelected(
                    const RecommendationFilter(pantryFriendlyOnly: true),
                  ),
                ),
                _SummaryChip(
                  key: const ValueKey<String>('dashboard-filter-quick'),
                  label: 'เมนูด่วน',
                  value: dashboard.quickMeals,
                  selected: activeFilter.maximumCookTimeMinutes == 30,
                  onTap: () => onSelected(
                    const RecommendationFilter(maximumCookTimeMinutes: 30),
                  ),
                ),
                _SummaryChip(
                  key: const ValueKey<String>('dashboard-filter-expiring'),
                  label: 'ใช้ของใกล้หมดอายุ',
                  value: dashboard.usingExpiringIngredients,
                  selected: activeFilter.usesExpiringIngredientsOnly,
                  onTap: () => onSelected(
                    const RecommendationFilter(
                      usesExpiringIngredientsOnly: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isAll =>
      activeFilter.minimumMatchPercent == null &&
      activeFilter.maximumCookTimeMinutes == null &&
      !activeFilter.pantryFriendlyOnly &&
      !activeFilter.healthyOnly &&
      !activeFilter.usesExpiringIngredientsOnly;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: CircleAvatar(
        child: selected ? const Icon(Icons.check, size: 16) : Text('$value'),
      ),
      label: Text(selected ? '$label ($value)' : label),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
    );
  }
}

class _MoreRecipesSection extends StatelessWidget {
  const _MoreRecipesSection({
    required this.matches,
    required this.detailsByRecipeId,
    required this.rankedAbove,
    required this.onOpen,
  });

  final List<RecipeMatch> matches;
  final Map<String, RecipeRecommendation> detailsByRecipeId;
  final RecipeRecommendation? rankedAbove;
  final ValueChanged<RecipeMatch> onOpen;

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
                child: _RecipeMatchCard(
                  match: match,
                  recommendation: detailsByRecipeId[match.recipe.id],
                  rankedAbove: rankedAbove,
                  compact: true,
                  onOpen: () => onOpen(match),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({
    required this.match,
    required this.onOpen,
    this.recommendation,
    this.rankedAbove,
    this.compact = false,
  });

  final RecipeMatch match;
  final RecipeRecommendation? recommendation;
  final RecipeRecommendation? rankedAbove;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(child: Text(match.recipe.emoji)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 7),
                    if (recommendation != null) ...[
                      Text(
                        'ใช้ของใน Pantry '
                        '${recommendation!.usedPantryIngredientCount} / '
                        '${recommendation!.pantryIngredientCount} • '
                        'ขาด ${recommendation!.missingIngredientCount} รายการ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                    ],
                    Wrap(
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
                        _InfoChip(
                          icon: Icons.signal_cellular_alt,
                          label: _difficultyLabel(match.recipe.difficulty),
                        ),
                        if (!compact)
                          _InfoChip(
                            icon: Icons.groups_2_outlined,
                            label: 'เลือกจำนวนคน',
                          ),
                        ...?recommendation?.badges
                            .take(2)
                            .map(
                              (badge) => _InfoChip(
                                icon: _badgeIcon(badge),
                                label: _badgeLabel(badge),
                              ),
                            ),
                      ],
                    ),
                    if (recommendation != null &&
                        recommendation!.reasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '✓ ${recommendation!.reasons.take(2).join(' • ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recommendation != null &&
                        rankedAbove != null &&
                        recommendation!.match.recipe.id !=
                            rankedAbove!.match.recipe.id) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ทำไมไม่อันดับ 1: '
                        '${rankedAbove!.whyRankedHigherThan(recommendation!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MatchBadge(
                matchPercent: match.scorePercent,
                missingCount: match.missingRequiredCount,
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.matchPercent, required this.missingCount});

  final int matchPercent;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 54, minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$matchPercent%',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            missingCount == 0 ? 'พร้อมทำ' : 'Pantry',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
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
          'ลองเพิ่มกุ้ง หมู ไก่ เนื้อวัว ปลาหมึก หรือไข่ใน Pantry แล้วกลับมาหน้านี้อีกครั้ง',
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
  const _ErrorView({required this.onRetry});

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
            const Text(
              'กรุณาลองใหม่อีกครั้ง ข้อมูลใน Pantry ของคุณยังปลอดภัย',
              textAlign: TextAlign.center,
            ),
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

String _sortLabel(RecommendationSort sort) {
  return switch (sort) {
    RecommendationSort.bestMatch => 'ตรงกับ Pantry มากที่สุด',
    RecommendationSort.highestScore => 'คะแนนแนะนำสูงสุด',
    RecommendationSort.fastest => 'ทำเร็วที่สุด',
    RecommendationSort.leastMissing => 'ขาดน้อยที่สุด',
    RecommendationSort.mostPantryUsed => 'ใช้ของใน Pantry มากที่สุด',
    RecommendationSort.newest => 'สูตรใหม่ที่สุด',
  };
}

String _badgeLabel(RecommendationBadge badge) {
  return switch (badge) {
    RecommendationBadge.perfectMatch => 'พร้อมครบ',
    RecommendationBadge.pantryFriendly => 'Pantry Friendly',
    RecommendationBadge.quickMeal => 'เมนูด่วน',
    RecommendationBadge.fewMissing => 'ขาดเพียงเล็กน้อย',
    RecommendationBadge.usesExpiringIngredients => 'ใช้ของใกล้หมดอายุ',
    RecommendationBadge.healthyChoice => 'ทางเลือกสุขภาพ',
  };
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ยาก',
    _ => difficulty,
  };
}

IconData _badgeIcon(RecommendationBadge badge) {
  return switch (badge) {
    RecommendationBadge.perfectMatch => Icons.verified_outlined,
    RecommendationBadge.pantryFriendly => Icons.kitchen_outlined,
    RecommendationBadge.quickMeal => Icons.bolt_outlined,
    RecommendationBadge.fewMissing => Icons.shopping_basket_outlined,
    RecommendationBadge.usesExpiringIngredients => Icons.event_outlined,
    RecommendationBadge.healthyChoice => Icons.eco_outlined,
  };
}
