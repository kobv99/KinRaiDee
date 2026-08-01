import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/design_system/components/responsive_content.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/recipe_discovery_service.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_page.dart';

const String _allFilterValue = '__all__';

class AllRecipesPage extends ConsumerStatefulWidget {
  const AllRecipesPage({super.key});

  @override
  ConsumerState<AllRecipesPage> createState() => _AllRecipesPageState();
}

class _AllRecipesPageState extends ConsumerState<AllRecipesPage> {
  static const RecipeDiscoveryService _discoveryService =
      RecipeDiscoveryService();

  late final TextEditingController _searchController;
  String _query = '';
  String? _mainIngredientId;
  int? _maxCookTimeMinutes;
  String? _difficulty;
  String? _cookingMethod;
  String? _category;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหาและสำรวจสูตร')),
      body: ResponsiveContent(
        child: recipes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _LoadError(onRetry: () => ref.invalidate(recipesProvider)),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return const _EmptyRecipes();
    }

    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final criteria = RecipeDiscoveryCriteria(
      query: _query,
      mainIngredientId: _mainIngredientId,
      maxCookTimeMinutes: _maxCookTimeMinutes,
      difficulty: _difficulty,
      cookingMethod: _cookingMethod,
      category: _category,
    );
    final results = criteria.hasActiveCriteria
        ? _discoveryService.discover(
            recipes: recipes,
            criteria: criteria,
            registry: registry,
          )
        : const <RecipeDiscoveryResult>[];
    final mainIngredients = _discoveryService.mainIngredients(
      recipes,
      registry: registry,
    );
    final categories = _discoveryService.categories(recipes);
    final difficulties = _discoveryService.difficulties(recipes);
    final methods = _discoveryService.cookingMethods(recipes);

    return CustomScrollView(
      key: const ValueKey<String>('recipe-discovery-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchField(
                  controller: _searchController,
                  query: _query,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                const SizedBox(height: 10),
                _MainIngredientFilter(
                  ingredients: mainIngredients,
                  selectedId: _mainIngredientId,
                  onChanged: (value) => setState(
                    () => _mainIngredientId = _optionalFilterValue(value),
                  ),
                ),
                const SizedBox(height: 10),
                _FilterBar(
                  maxCookTimeMinutes: _maxCookTimeMinutes,
                  difficulty: _difficulty,
                  cookingMethod: _cookingMethod,
                  category: _category,
                  difficulties: difficulties,
                  methods: methods,
                  categories: categories,
                  onMaxCookTimeChanged: (value) => setState(
                    () => _maxCookTimeMinutes = value == _allFilterValue
                        ? null
                        : int.parse(value),
                  ),
                  onDifficultyChanged: (value) =>
                      setState(() => _difficulty = _optionalFilterValue(value)),
                  onMethodChanged: (value) => setState(
                    () => _cookingMethod = _optionalFilterValue(value),
                  ),
                  onCategoryChanged: (value) =>
                      setState(() => _category = _optionalFilterValue(value)),
                  onClearAll: criteria.hasActiveCriteria ? _clearAll : null,
                ),
                const SizedBox(height: 12),
                const _FreedomNotice(),
                const SizedBox(height: 16),
                if (!criteria.hasActiveCriteria)
                  _DiscoveryState(
                    categories: categories,
                    methods: methods,
                    onCategorySelected: (value) =>
                        setState(() => _category = value),
                    onMethodSelected: (value) =>
                        setState(() => _cookingMethod = value),
                  )
                else ...[
                  Text(
                    'พบ ${results.length} สูตร',
                    key: const ValueKey<String>(
                      'recipe-discovery-result-count',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (results.isNotEmpty && results.length <= 2) ...[
                    const SizedBox(height: 10),
                    const _LowResultNotice(),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (criteria.hasActiveCriteria && results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyResults(onClear: _clearAll),
          )
        else if (criteria.hasActiveCriteria)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              key: const ValueKey<String>('all-recipes-list'),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecipeResultTile(
                    result: result,
                    onOpen: () => _openRecipe(context, result.recipe),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _query = '';
      _mainIngredientId = null;
      _maxCookTimeMinutes = null;
      _difficulty = null;
      _cookingMethod = null;
      _category = null;
    });
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey<String>('recipe-discovery-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อเมนูหรือวัตถุดิบ',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.trim().isEmpty
            ? null
            : IconButton(
                key: const ValueKey<String>('recipe-discovery-clear-search'),
                tooltip: 'ล้างคำค้นหา',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _MainIngredientFilter extends StatelessWidget {
  const _MainIngredientFilter({
    required this.ingredients,
    required this.selectedId,
    required this.onChanged,
  });

  final List<RecipeDiscoveryMainIngredient> ingredients;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    RecipeDiscoveryMainIngredient? selected;
    for (final ingredient in ingredients) {
      if (ingredient.id == selectedId) {
        selected = ingredient;
        break;
      }
    }
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        key: const ValueKey<String>('recipe-filter-main-ingredient'),
        enabled: ingredients.isNotEmpty,
        initialValue: selectedId,
        onSelected: onChanged,
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: _allFilterValue,
            child: Text('วัตถุดิบหลักทั้งหมด'),
          ),
          ...ingredients.map(
            (ingredient) => PopupMenuItem<String>(
              value: ingredient.id,
              child: Row(
                children: [
                  Text(ingredient.emoji),
                  const SizedBox(width: 10),
                  Expanded(child: Text(ingredient.name)),
                  Text(
                    '${ingredient.recipeCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: Chip(
          avatar: Text(selected?.emoji ?? '🍳'),
          label: Text(
            selected == null
                ? 'วัตถุดิบหลัก'
                : 'วัตถุดิบหลัก: ${selected.name}',
          ),
          backgroundColor: selected == null ? null : colors.primaryContainer,
          side: BorderSide(
            color: selected == null ? colors.outlineVariant : colors.primary,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.maxCookTimeMinutes,
    required this.difficulty,
    required this.cookingMethod,
    required this.category,
    required this.difficulties,
    required this.methods,
    required this.categories,
    required this.onMaxCookTimeChanged,
    required this.onDifficultyChanged,
    required this.onMethodChanged,
    required this.onCategoryChanged,
    required this.onClearAll,
  });

  final int? maxCookTimeMinutes;
  final String? difficulty;
  final String? cookingMethod;
  final String? category;
  final List<String> difficulties;
  final List<String> methods;
  final List<String> categories;
  final ValueChanged<String> onMaxCookTimeChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<String> onMethodChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterMenuChip(
            menuKey: const ValueKey<String>('recipe-filter-time'),
            icon: Icons.schedule_outlined,
            label: maxCookTimeMinutes == null
                ? 'เวลา'
                : '≤ $maxCookTimeMinutes นาที',
            active: maxCookTimeMinutes != null,
            selectedValue: maxCookTimeMinutes?.toString(),
            options: const <String, String>{
              _allFilterValue: 'ทุกช่วงเวลา',
              '20': 'ไม่เกิน 20 นาที',
              '30': 'ไม่เกิน 30 นาที',
              '45': 'ไม่เกิน 45 นาที',
            },
            onSelected: onMaxCookTimeChanged,
          ),
          const SizedBox(width: 8),
          _FilterMenuChip(
            menuKey: const ValueKey<String>('recipe-filter-difficulty'),
            icon: Icons.signal_cellular_alt_rounded,
            label: difficulty == null
                ? 'ความยาก'
                : _difficultyLabel(difficulty!),
            active: difficulty != null,
            selectedValue: difficulty,
            options: <String, String>{
              _allFilterValue: 'ทุกระดับ',
              for (final value in difficulties) value: _difficultyLabel(value),
            },
            onSelected: onDifficultyChanged,
          ),
          if (methods.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterMenuChip(
              menuKey: const ValueKey<String>('recipe-filter-method'),
              icon: Icons.soup_kitchen_outlined,
              label: cookingMethod ?? 'วิธีทำ',
              active: cookingMethod != null,
              selectedValue: cookingMethod,
              options: <String, String>{
                _allFilterValue: 'ทุกวิธีทำ',
                for (final value in methods) value: value,
              },
              onSelected: onMethodChanged,
            ),
          ],
          if (categories.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterMenuChip(
              menuKey: const ValueKey<String>('recipe-filter-category'),
              icon: Icons.category_outlined,
              label: category ?? 'หมวดหมู่',
              active: category != null,
              selectedValue: category,
              options: <String, String>{
                _allFilterValue: 'ทุกหมวดหมู่',
                for (final value in categories) value: value,
              },
              onSelected: onCategoryChanged,
            ),
          ],
          if (onClearAll != null) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              key: const ValueKey<String>('recipe-discovery-clear-all'),
              onPressed: onClearAll,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('ล้าง'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterMenuChip extends StatelessWidget {
  const _FilterMenuChip({
    required this.menuKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  final Key menuKey;
  final IconData icon;
  final String label;
  final bool active;
  final String? selectedValue;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      key: menuKey,
      initialValue: selectedValue,
      onSelected: onSelected,
      itemBuilder: (context) => options.entries
          .map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(growable: false),
      child: Chip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        backgroundColor: active ? colors.secondaryContainer : null,
        side: BorderSide(
          color: active ? colors.secondary : colors.outlineVariant,
        ),
      ),
    );
  }
}

class _DiscoveryState extends StatelessWidget {
  const _DiscoveryState({
    required this.categories,
    required this.methods,
    required this.onCategorySelected,
    required this.onMethodSelected,
  });

  final List<String> categories;
  final List<String> methods;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onMethodSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('recipe-discovery-idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'อยากกินอะไรวันนี้?',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'พิมพ์ชื่อเมนูหรือวัตถุดิบด้านบน หรือเลือกหัวข้อเพื่อเริ่มสำรวจ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'หมวดหมู่ยอดนิยม',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .take(6)
                .map(
                  (value) => ActionChip(
                    key: ValueKey<String>('recipe-discovery-category-$value'),
                    avatar: const Icon(Icons.category_outlined, size: 17),
                    label: Text(value),
                    onPressed: () => onCategorySelected(value),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (methods.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'สำรวจตามวิธีทำ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: methods
                .take(8)
                .map(
                  (value) => ActionChip(
                    key: ValueKey<String>('recipe-discovery-method-$value'),
                    avatar: const Icon(Icons.soup_kitchen_outlined, size: 17),
                    label: Text(value),
                    onPressed: () => onMethodSelected(value),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _RecipeResultTile extends StatelessWidget {
  const _RecipeResultTile({required this.result, required this.onOpen});

  final RecipeDiscoveryResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final recipe = result.recipe;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey<String>('all-recipe-${recipe.id}'),
        onTap: onOpen,
        leading: CircleAvatar(child: Text(recipe.emoji)),
        title: Text(
          recipe.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_recipeSubtitle(result)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FreedomNotice extends StatelessWidget {
  const _FreedomNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('all-recipes-freedom-notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.search_rounded, color: colors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ค้นหาและสำรวจได้ทุกสูตร ไม่จำกัดเฉพาะคำแนะนำจาก Pantry คุณเลือกเมนูก่อนแล้วค่อยเตรียมวัตถุดิบได้',
            ),
          ),
        ],
      ),
    );
  }
}

class _LowResultNotice extends StatelessWidget {
  const _LowResultNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('recipe-discovery-low-results'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.tune_rounded, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text('พบเมนูน้อย ลองใช้คำค้นที่กว้างขึ้นหรือลดตัวกรอง'),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('recipe-discovery-empty-results'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 52),
            const SizedBox(height: 12),
            Text(
              'ยังไม่พบสูตรที่ตรงกัน',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'ลองเปลี่ยนคำค้นหา หรือล้างตัวกรองบางส่วน',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('เริ่มค้นหาใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecipes extends StatelessWidget {
  const _EmptyRecipes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('ยังไม่มีข้อมูลสูตรอาหารในอุปกรณ์นี้'),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            const Text(
              'โหลดสูตรอาหารไม่สำเร็จ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'ข้อมูลเดิมยังคงปลอดภัย กรุณาลองอีกครั้ง',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}

String _recipeSubtitle(RecipeDiscoveryResult result) {
  final recipe = result.recipe;
  final parts = <String>[];
  final reason = switch (result.matchType) {
    RecipeDiscoveryMatchType.exactTitle => 'ตรงชื่อเมนู',
    RecipeDiscoveryMatchType.exactHeroIngredient ||
    RecipeDiscoveryMatchType.exactIngredient => 'ตรงวัตถุดิบ',
    _ => null,
  };
  if (reason != null) {
    parts.add(reason);
  }
  if (recipe.category.trim().isNotEmpty) {
    parts.add(recipe.category);
  }
  if (recipe.cookTimeMinutes > 0) {
    parts.add('${recipe.cookTimeMinutes} นาที');
  }
  return parts.isEmpty ? 'เปิดสูตรและตัดสินใจได้ตามต้องการ' : parts.join(' · ');
}

String _difficultyLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ยาก',
    _ => value,
  };
}

String? _optionalFilterValue(String value) {
  return value == _allFilterValue ? null : value;
}
