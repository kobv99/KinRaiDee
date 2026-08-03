import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../providers/recipe_provider.dart';
import '../widgets/main_ingredient_picker_sheet.dart';
import 'recipe_detail_page.dart';

enum _QuickFilter { ready, lowMissing, quick }

class RecipePage extends ConsumerStatefulWidget {
  const RecipePage({super.key});

  @override
  ConsumerState<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends ConsumerState<RecipePage> {
  final Set<_QuickFilter> _activeFilters = <_QuickFilter>{};

  bool _passesFilters(RecipeMatch match) {
    if (_activeFilters.contains(_QuickFilter.ready) && !match.canCook) {
      return false;
    }
    if (_activeFilters.contains(_QuickFilter.lowMissing) &&
        match.missingRequiredCount > 1) {
      return false;
    }
    if (_activeFilters.contains(_QuickFilter.quick) &&
        (match.recipe.cookTimeMinutes <= 0 ||
            match.recipe.cookTimeMinutes > 20)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = ref.watch(smartRecommendationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('ทำอะไรกินดี', style: AppTypography.title),
      ),
      body: ResponsiveContent(
        child: recommendation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorView(onRetry: () => ref.invalidate(recipesProvider)),
          data: _buildRecommendation,
        ),
      ),
    );
  }

  Widget _buildRecommendation(SmartRecommendation result) {
    if (!result.requestedSelectionAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final selection = ref.read(heroSelectionProvider);
        if (!selection.isAutomatic) {
          ref.read(heroSelectionProvider.notifier).useAutomatic();
          ref.read(recommendationSessionProvider.notifier).reset();
        }
      });
    }

    if (!result.hasHero) {
      return RefreshIndicator(
        onRefresh: () => _reload(ref),
        child: _NoHeroView(
          canChooseManually: result.heroOptions.isNotEmpty,
          onChooseManually: () => _showHeroPicker(
            context,
            ref,
            result.heroOptions,
            null,
            result.heroSelectionMode,
          ),
        ),
      );
    }

    final hero = result.hero!;
    final quickOptions = result.heroOptions
        .where((option) => option.isInPantry || option.key == hero.key)
        .take(8)
        .toList(growable: false);
    final filteredPrimary = result.primaryMatches
        .where(_passesFilters)
        .toList(growable: false);
    final filteredAdaptable = result.adaptableMatches
        .where(_passesFilters)
        .toList(growable: false);
    final filteredMore = result.moreMatches
        .where(_passesFilters)
        .toList(growable: false);
    final filtersHideEverything =
        _activeFilters.isNotEmpty &&
        filteredPrimary.isEmpty &&
        filteredAdaptable.isEmpty &&
        filteredMore.isEmpty;

    return RefreshIndicator(
      onRefresh: () => _reload(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeroIngredientCard(
            hero: hero,
            selectionMode: result.heroSelectionMode,
            reason: result.heroReason,
            onChange: () => _showHeroPicker(
              context,
              ref,
              result.heroOptions,
              hero,
              result.heroSelectionMode,
            ),
            onTogglePin: () async {
              final notifier = ref.read(heroSelectionProvider.notifier);
              if (result.isPinned) {
                await notifier.useAutomatic();
              } else {
                await notifier.pin(hero.key);
              }
              ref.read(recommendationSessionProvider.notifier).reset();
            },
          ),
          if (quickOptions.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            _HeroQuickSelectRow(
              options: quickOptions,
              activeKey: hero.key,
              onSelect: (option) async {
                await ref
                    .read(heroSelectionProvider.notifier)
                    .selectForSession(option.key);
                ref.read(recommendationSessionProvider.notifier).reset();
              },
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _QuickFilterChips(
            active: _activeFilters,
            onToggle: (filter) => setState(() {
              if (!_activeFilters.remove(filter)) {
                _activeFilters.add(filter);
              }
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Top Picks สำหรับ ${hero.name}',
                  key: const ValueKey<String>('top-picks-heading'),
                  style: AppTypography.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (result.canRefresh)
                TextButton.icon(
                  onPressed: () => ref
                      .read(recommendationSessionProvider.notifier)
                      .showNext(result.totalHeroRecipes),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('เปลี่ยนชุด'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.totalHeroRecipes == 0
                ? 'ยังไม่มีเมนูที่ยืนยันความเข้ากันได้โดยตรง'
                : 'พบ ${result.totalHeroRecipes} เมนูที่ยืนยันความเข้ากันได้',
            key: const ValueKey<String>('top-picks-summary'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtersHideEverything)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'ไม่มีเมนูที่ตรงกับตัวกรองที่เลือก ลองเอาตัวกรองออกบางส่วน',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            )
          else ...[
            if (filteredPrimary.isEmpty)
              const Padding(
                key: ValueKey<String>('top-picks-empty-state'),
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'ยังไม่พบเมนูที่เข้ากันโดยตรง ลองเลือกวัตถุดิบหลักอื่น',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
              ),
            ...filteredPrimary.map(
              (match) => Padding(
                key: ValueKey<String>('top-pick-${match.recipe.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecipeMatchCard(
                  match: match,
                  onOpen: () => _openRecipeDetail(context, match),
                ),
              ),
            ),
            if (filteredAdaptable.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _AdaptableRecipesSection(
                matches: filteredAdaptable,
                onOpen: (match) => _openRecipeDetail(context, match),
              ),
            ],
            if (filteredMore.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _MoreRecipesSection(
                matches: filteredMore,
                onOpen: (match) => _openRecipeDetail(context, match),
              ),
            ],
          ],
        ],
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
    HeroIngredientOption? activeHero,
    HeroSelectionMode activeMode,
  ) async {
    final result = await showMainIngredientPickerSheet(
      context: context,
      options: options
          .map(
            (option) => MainIngredientPickerOption(
              canonicalId: option.canonicalIngredientId,
              name: option.name,
              emoji: option.emoji,
              categoryLabel: option.categoryLabel,
              isInPantry: option.isInPantry,
              supportedRecipeCount: option.supportedRecipeCount,
              searchTerms: <String>{
                option.key,
                option.name,
                ...option.searchTerms,
              }.toList(growable: false),
            ),
          )
          .toList(growable: false),
      initialMode: activeMode == HeroSelectionMode.automatic
          ? MainIngredientSelectionMode.automatic
          : MainIngredientSelectionMode.manual,
      selectedIngredientId: activeMode == HeroSelectionMode.automatic
          ? null
          : activeHero?.key,
      recentIngredientIds: options
          .where((option) => option.isRecent)
          .map((option) => option.key)
          .toList(growable: false),
      showPinAction: true,
      pinnedIngredientId: activeMode == HeroSelectionMode.pinned
          ? activeHero?.key
          : null,
    );

    if (result == null || !mounted) {
      return;
    }

    final selection = ref.read(heroSelectionProvider.notifier);
    if (result.mode == MainIngredientSelectionMode.automatic) {
      await selection.useAutomatic();
    } else {
      final ingredientId = result.canonicalIngredientId!;
      if (result.pinAction == MainIngredientPinAction.pin) {
        await selection.pin(ingredientId);
      } else {
        await selection.selectForSession(ingredientId);
      }
    }
    ref.read(recommendationSessionProvider.notifier).reset();
  }
}

class _HeroQuickSelectRow extends StatelessWidget {
  const _HeroQuickSelectRow({
    required this.options,
    required this.activeKey,
    required this.onSelect,
  });

  final List<HeroIngredientOption> options;
  final String activeKey;
  final ValueChanged<HeroIngredientOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final option = options[index];
          return ChoiceChip(
            key: ValueKey<String>('hero-quick-select-${option.key}'),
            label: Text('${option.emoji} ${option.name}'),
            selected: option.key == activeKey,
            onSelected: (_) => onSelect(option),
          );
        },
      ),
    );
  }
}

class _QuickFilterChips extends StatelessWidget {
  const _QuickFilterChips({required this.active, required this.onToggle});

  final Set<_QuickFilter> active;
  final ValueChanged<_QuickFilter> onToggle;

  @override
  Widget build(BuildContext context) {
    const labels = <_QuickFilter, (String, IconData)>{
      _QuickFilter.ready: ('พร้อมทำ', Icons.check_circle_outline),
      _QuickFilter.lowMissing: ('ขาดน้อย', Icons.shopping_basket_outlined),
      _QuickFilter.quick: ('เมนูด่วน', Icons.bolt_outlined),
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _QuickFilter.values
          .map((filter) {
            final (label, icon) = labels[filter]!;
            return FilterChip(
              key: ValueKey<String>('recipe-quick-filter-${filter.name}'),
              avatar: Icon(icon, size: 16),
              label: Text(label),
              selected: active.contains(filter),
              onSelected: (_) => onToggle(filter),
            );
          })
          .toList(growable: false),
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
    final isPinned = selectionMode == HeroSelectionMode.pinned;
    final modeLabel = switch (selectionMode) {
      HeroSelectionMode.automatic => 'ระบบเลือกอัตโนมัติ',
      HeroSelectionMode.manual => 'เลือกด้วยตนเอง',
      HeroSelectionMode.pinned => 'ปักหมุดไว้',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.largeRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(hero.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${hero.name} · ${hero.recipeCount} เมนู',
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(modeLabel, style: AppTypography.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: isPinned ? 'กลับไปให้ระบบเลือก' : 'ปักหมุดวัตถุดิบนี้',
                onPressed: onTogglePin,
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('เปลี่ยน'),
              ),
            ],
          ),
          if (reason.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(reason, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

class _AdaptableRecipesSection extends StatelessWidget {
  const _AdaptableRecipesSection({required this.matches, required this.onOpen});

  final List<RecipeMatch> matches;
  final ValueChanged<RecipeMatch> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('adaptable-recipes-section'),
        leading: const Icon(Icons.tune_outlined),
        title: const Text(
          'เมนูที่อาจปรับใช้ได้',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${matches.length} เมนูจากกลุ่มวัตถุดิบเดียวกัน ตรวจสูตรก่อนตัดสินใจ',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: matches
            .map((match) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _RecipeMatchCard(
                  match: match,
                  compact: true,
                  onOpen: () => onOpen(match),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _MoreRecipesSection extends StatelessWidget {
  const _MoreRecipesSection({required this.matches, required this.onOpen});

  final List<RecipeMatch> matches;
  final ValueChanged<RecipeMatch> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('more-recipes-section'),
        leading: const Icon(Icons.add_circle_outline),
        title: const Text(
          'เมนูเพิ่มเติมจากวัตถุดิบที่มี',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${matches.length} เมนู · เรียงตามความพร้อม'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: matches
            .map((match) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _RecipeMatchCard(
                  match: match,
                  compact: true,
                  onOpen: () => onOpen(match),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({
    required this.match,
    required this.onOpen,
    this.compact = false,
  });

  final RecipeMatch match;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reason = match.matchReason.trim();
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
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        key: ValueKey<String>(
                          'match-reason-${match.recipe.id}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
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
                        if (!compact)
                          const _InfoChip(
                            icon: Icons.groups_2_outlined,
                            label: 'เลือกจำนวนคน',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ScoreBadge(score: match.scorePercent),
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

class _NoHeroView extends StatelessWidget {
  const _NoHeroView({
    required this.canChooseManually,
    required this.onChooseManually,
  });

  final bool canChooseManually;
  final VoidCallback onChooseManually;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
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
          canChooseManually
              ? 'เลือกวัตถุดิบที่ต้องการสำรวจได้ แม้ยังไม่มีอยู่ใน Pantry'
              : 'ลองเพิ่มวัตถุดิบใน Pantry แล้วกลับมาหน้านี้อีกครั้ง',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (canChooseManually) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: FilledButton.icon(
              key: const ValueKey<String>('choose-main-ingredient-manually'),
              onPressed: onChooseManually,
              icon: const Icon(Icons.search),
              label: const Text('เลือกวัตถุดิบหลัก'),
            ),
          ),
        ],
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
