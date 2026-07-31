import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/knowledge_base_health.dart';
import '../../domain/entities/qa_pantry_profile.dart';
import '../../domain/entities/recipe_recommendation.dart';
import '../providers/recipe_provider.dart';

class RecommendationQaPage extends ConsumerWidget {
  const RecommendationQaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(knowledgeBaseHealthProvider);
    final recommendations = ref.watch(recipeRecommendationResultsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recommendation QA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'สำหรับนักพัฒนาและ QA เท่านั้น',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          health.when(
            data: (value) => _HealthCard(health: value),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Text('โหลดรายงาน Knowledge Base ไม่สำเร็จ'),
          ),
          const SizedBox(height: 12),
          _QaProfilesCard(profiles: qaPantryProfiles),
          const SizedBox(height: 12),
          recommendations.when(
            data: (items) => _DebugCard(recommendations: items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Text('โหลด Recommendation Debug View ไม่สำเร็จ'),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});

  final KnowledgeBaseHealth health;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Knowledge Base Health'),
        subtitle: Text(
          '${health.canonicalIngredientCount} วัตถุดิบ • '
          '${health.recipeCount} สูตร • ${health.issueCount} จุดที่ต้องตรวจ',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _IssueRow(
            label: 'Recipes without Ingredients',
            values: health.recipesWithoutIngredients,
          ),
          _IssueRow(
            label: 'Ingredients without Recipes',
            values: health.ingredientsWithoutRecipes,
          ),
          _IssueRow(
            label: 'Missing Substitutions',
            values: health.ingredientsWithoutSubstitutions,
          ),
          _IssueRow(
            label: 'Duplicate Aliases',
            values: health.duplicateAliases,
          ),
          _IssueRow(
            label: 'Broken References',
            values: health.brokenIngredientReferences,
          ),
          _IssueRow(
            label: 'Broken Recipe Mapping',
            values: health.brokenRecipeMappings,
          ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label),
      trailing: CircleAvatar(child: Text('${values.length}')),
      children: values
          .take(50)
          .map(
            (value) => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText('• $value'),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _QaProfilesCard extends StatelessWidget {
  const _QaProfilesCard({required this.profiles});

  final List<QaPantryProfile> profiles;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Test Pantry Profiles'),
        subtitle: Text('${profiles.length} โปรไฟล์ที่ใช้ซ้ำได้'),
        children: profiles
            .map(
              (profile) => ListTile(
                title: Text(profile.name),
                subtitle: Text(
                  profile.items.isEmpty
                      ? 'ไม่มีวัตถุดิบ'
                      : profile.items
                            .map(
                              (item) => item.expiresInDays == null
                                  ? item.canonicalIngredientId
                                  : '${item.canonicalIngredientId} '
                                        '(หมดอายุใน ${item.expiresInDays} วัน)',
                            )
                            .join(', '),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.recommendations});

  final List<RecipeRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Recommendation Debug View'),
        subtitle: Text('${recommendations.length} ผลลัพธ์'),
        children: recommendations
            .map(
              (item) => ExpansionTile(
                title: Text(item.match.recipe.name),
                subtitle: Text('Final Score ${item.scorePercent}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final component in item.components)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${component.points >= 0 ? '+' : ''}'
                        '${component.points.toStringAsFixed(1)} '
                        '${component.id} — ${component.explanation}',
                      ),
                    ),
                  if (recommendations.isNotEmpty &&
                      recommendations.first.match.recipe.id !=
                          item.match.recipe.id)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Why Not: ${recommendations.first.match.recipe.name} '
                          'สูงกว่า เพราะ '
                          '${recommendations.first.whyRankedHigherThan(item)}',
                        ),
                      ),
                    ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
