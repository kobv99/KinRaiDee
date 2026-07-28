import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recipe.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_page.dart';

class AllRecipesPage extends ConsumerWidget {
  const AllRecipesPage({super.key});

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
