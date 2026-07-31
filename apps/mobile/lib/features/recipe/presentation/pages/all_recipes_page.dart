import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recipe.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_page.dart';

class AllRecipesPage extends ConsumerStatefulWidget {
  const AllRecipesPage({super.key});

  @override
  ConsumerState<AllRecipesPage> createState() => _AllRecipesPageState();
}

class _AllRecipesPageState extends ConsumerState<AllRecipesPage> {
  static const _resultLimit = 30;
  final _searchController = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหาสูตรอาหาร')),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _LoadError(onRetry: () => ref.invalidate(recipesProvider)),
        data: (items) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey<String>('recipe-catalog-search-field'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อเมนู วัตถุดิบ หรือประเภทอาหาร',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        onPressed: _searchController.text.isEmpty
                            ? null
                            : _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submitSearch(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey<String>('recipe-catalog-search'),
                      onPressed: _searchController.text.trim().isEmpty
                          ? null
                          : _submitSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหาสูตร'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(items)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<Recipe> recipes) {
    if (_submittedQuery.isEmpty) {
      return const _SearchPrompt();
    }
    final matches = _search(recipes, _submittedQuery);
    if (matches.isEmpty) {
      return _NoSearchResults(query: _submittedQuery);
    }
    final visible = matches.take(_resultLimit).toList(growable: false);
    return ListView.builder(
      key: const ValueKey<String>('recipe-search-results'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              matches.length > _resultLimit
                  ? 'พบ ${matches.length} สูตร • แสดง $_resultLimit รายการแรก'
                  : 'พบ ${matches.length} สูตร',
            ),
          );
        }
        final recipe = visible[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: ValueKey<String>('recipe-search-result-${recipe.id}'),
              onTap: () => _openRecipe(context, recipe),
              leading: CircleAvatar(child: Text(recipe.emoji)),
              title: Text(
                recipe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_subtitle(recipe)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        );
      },
    );
  }

  List<Recipe> _search(List<Recipe> recipes, String query) {
    final normalized = _normalize(query);
    final matches =
        recipes
            .where((recipe) {
              final searchable = <String>[
                recipe.name,
                recipe.category,
                recipe.description,
                ...recipe.tags,
                ...recipe.ingredients.map((item) => item.name),
                ...recipe.ingredients.map((item) => item.canonicalIngredientId),
              ].map(_normalize);
              return searchable.any((value) => value.contains(normalized));
            })
            .toList(growable: false)
          ..sort((first, second) {
            final firstName = _normalize(first.name);
            final secondName = _normalize(second.name);
            if ((firstName == normalized) != (secondName == normalized)) {
              return firstName == normalized ? -1 : 1;
            }
            if (firstName.startsWith(normalized) !=
                secondName.startsWith(normalized)) {
              return firstName.startsWith(normalized) ? -1 : 1;
            }
            return first.name.compareTo(second.name);
          });
    return matches;
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() => _submittedQuery = query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _submittedQuery = '');
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }

  String _subtitle(Recipe recipe) {
    final parts = <String>[
      if (recipe.category.trim().isNotEmpty) recipe.category,
      if (recipe.cookTimeMinutes > 0) '${recipe.cookTimeMinutes} นาที',
    ];
    return parts.isEmpty ? 'เปิดดูรายละเอียดสูตรอาหาร' : parts.join(' • ');
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search, size: 64),
            SizedBox(height: 12),
            Text(
              'ค้นหาสูตรที่ต้องการ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'ระบบจะไม่แสดงสูตรทั้งหมดพร้อมกัน เพื่อลดความรกและการใช้ทรัพยากร',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'ไม่พบสูตรสำหรับ “$query”\nลองค้นหาด้วยชื่อเมนูหรือวัตถุดิบอื่น',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

// Kept temporarily for compatibility with older widget snapshots.
// ignore: unused_element
class _LegacyAllRecipesPage extends ConsumerWidget {
  const _LegacyAllRecipesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('สูตรทั้งหมด')),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _LoadError(onRetry: () => ref.invalidate(recipesProvider)),
        data: (items) {
          final sorted = List<Recipe>.of(items)
            ..sort((first, second) => first.name.compareTo(second.name));
          if (sorted.isEmpty) {
            return const _EmptyRecipes();
          }
          return ListView(
            key: const ValueKey<String>('all-recipes-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const _FreedomNotice(),
              const SizedBox(height: 12),
              ...sorted.map(
                (recipe) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: ValueKey<String>('all-recipe-${recipe.id}'),
                      onTap: () => _openRecipe(context, recipe),
                      leading: CircleAvatar(child: Text(recipe.emoji)),
                      title: Text(
                        recipe.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_subtitle(recipe)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }

  String _subtitle(Recipe recipe) {
    final parts = <String>[];
    if (recipe.category.trim().isNotEmpty) {
      parts.add(recipe.category);
    }
    if (recipe.cookTimeMinutes > 0) {
      parts.add('${recipe.cookTimeMinutes} นาที');
    }
    return parts.isEmpty
        ? 'เปิดสูตรและตัดสินใจได้ตามต้องการ'
        : parts.join(' · ');
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
          Icon(Icons.menu_book_outlined, color: colors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'รายการนี้ไม่จำกัดตามคำแนะนำจาก Pantry คุณเลือกเปิดสูตรใดก็ได้ และเริ่มทำอาหารได้ตามต้องการ',
            ),
          ),
        ],
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
              'โหลดสูตรทั้งหมดไม่สำเร็จ',
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
