import 'package:flutter/material.dart';

import 'all_recipes_page.dart';
import 'recipe_page.dart';

class RecipeHubPage extends StatelessWidget {
  const RecipeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: const RecipePage(),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ไม่ถูกใจเมนูไหน? เลือกดูสูตรทั้งหมดได้เลย',
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey<String>('browse-all-recipes-button'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AllRecipesPage(),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('สูตรทั้งหมด'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
