import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../recipe/domain/entities/recipe_readiness.dart';
import '../../domain/entities/ingredient_substitution.dart';
import '../providers/substitution_provider.dart';

class RecipeSubstitutionPanel extends ConsumerWidget {
  const RecipeSubstitutionPanel({
    super.key,
    required this.recipeId,
    required this.readiness,
  });

  final String recipeId;
  final RecipeReadiness readiness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = RecipeSubstitutionRequest(
      recipeId: recipeId,
      candidates: readiness.substitutionCandidates,
      recipeSupportsSubstitutions: readiness.recipe.supportsSubstitutions,
    );
    final suggestions = ref.watch(recipeSubstitutionsProvider(request));
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final accepted = ref.watch(acceptedSubstitutionsProvider);
    String displayName(String id) => registry?.byId(id)?.displayName() ?? id;

    return suggestions.when(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        final recommendationSignature = _recommendationSignature(groups);
        final preference = ref.watch(
          recipeSubstitutionPanelPreferenceProvider.select(
            (preferences) => preferences[recipeId],
          ),
        );
        final preferenceMatches =
            preference?.recommendationSignature == recommendationSignature;
        if (!preferenceMatches) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final currentPreference = ref.read(
              recipeSubstitutionPanelPreferenceProvider.select(
                (preferences) => preferences[recipeId],
              ),
            );
            if (currentPreference?.recommendationSignature ==
                recommendationSignature) {
              return;
            }
            ref
                .read(recipeSubstitutionPanelPreferenceProvider.notifier)
                .setMode(
                  recipeId: recipeId,
                  recommendationSignature: recommendationSignature,
                  mode: RecipeSubstitutionPanelMode.collapsed,
                );
          });
        }
        final mode = preferenceMatches
            ? preference!.mode
            : RecipeSubstitutionPanelMode.collapsed;
        final recommendationCount = groups.values.fold<int>(
          0,
          (total, recommendations) => total + recommendations.length,
        );

        void setMode(RecipeSubstitutionPanelMode nextMode) {
          ref
              .read(recipeSubstitutionPanelPreferenceProvider.notifier)
              .setMode(
                recipeId: recipeId,
                recommendationSignature: recommendationSignature,
                mode: nextMode,
              );
        }

        return switch (mode) {
          RecipeSubstitutionPanelMode.hidden => _HiddenSubstitutionChip(
            recommendationCount: recommendationCount,
            onReopen: () => setMode(RecipeSubstitutionPanelMode.expanded),
          ),
          RecipeSubstitutionPanelMode.collapsed => _CollapsedSubstitutionCard(
            recommendationCount: recommendationCount,
            onExpand: () => setMode(RecipeSubstitutionPanelMode.expanded),
            onHide: () => setMode(RecipeSubstitutionPanelMode.hidden),
          ),
          RecipeSubstitutionPanelMode.expanded => _ExpandedSubstitutionCard(
            recipeId: recipeId,
            groups: groups,
            accepted: accepted,
            displayName: displayName,
            onIgnore: () => setMode(RecipeSubstitutionPanelMode.collapsed),
            onHide: () => setMode(RecipeSubstitutionPanelMode.hidden),
          ),
        };
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HiddenSubstitutionChip extends StatelessWidget {
  const _HiddenSubstitutionChip({
    required this.recommendationCount,
    required this.onReopen,
  });

  final int recommendationCount;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        key: const ValueKey<String>('recipe-substitution-reopen-chip'),
        avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: Text('วัตถุดิบทดแทน ($recommendationCount)'),
        tooltip: 'เปิดคำแนะนำวัตถุดิบทดแทนอีกครั้ง',
        onPressed: onReopen,
      ),
    );
  }
}

class _CollapsedSubstitutionCard extends StatelessWidget {
  const _CollapsedSubstitutionCard({
    required this.recommendationCount,
    required this.onExpand,
    required this.onHide,
  });

  final int recommendationCount;
  final VoidCallback onExpand;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey<String>('recipe-substitution-collapsed'),
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        leading: Icon(Icons.swap_horiz_rounded, color: colors.primary),
        title: Text(
          'วัตถุดิบทดแทนที่แนะนำ ($recommendationCount)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('▼ ขยายเมื่อพร้อม — คุณยังทำอาหารต่อได้'),
        onTap: onExpand,
        trailing: IconButton(
          key: const ValueKey<String>('recipe-substitution-hide-collapsed'),
          tooltip: 'ซ่อนคำแนะนำ',
          visualDensity: VisualDensity.compact,
          onPressed: onHide,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _ExpandedSubstitutionCard extends StatelessWidget {
  const _ExpandedSubstitutionCard({
    required this.recipeId,
    required this.groups,
    required this.accepted,
    required this.displayName,
    required this.onIgnore,
    required this.onHide,
  });

  final String recipeId;
  final Map<String, List<IngredientSubstitutionRecommendation>> groups;
  final Map<String, String> accepted;
  final String Function(String id) displayName;
  final VoidCallback onIgnore;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(
      180.0,
      280.0,
    );

    return Card(
      key: const ValueKey<String>('recipe-substitution-panel'),
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'วัตถุดิบทดแทนที่แนะนำ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'คำแนะนำเหล่านี้เป็นทางเลือก คุณข้ามหรือซ่อนได้ '
                'และยังเริ่มทำอาหารต่อได้โดยไม่ต้องยอมรับ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      key: const ValueKey<String>(
                        'recipe-substitution-ignore',
                      ),
                      onPressed: onIgnore,
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      label: const Text('ไว้ทีหลัง'),
                    ),
                    TextButton.icon(
                      key: const ValueKey<String>('recipe-substitution-hide'),
                      onPressed: onHide,
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('ซ่อน'),
                    ),
                  ],
                ),
              ),
              for (final group in groups.entries) ...[
                const Divider(),
                Text(
                  displayName(group.key),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Icon(Icons.arrow_downward_rounded, size: 18),
                  ),
                ),
                for (final recommendation in group.value)
                  _SubstitutionOption(
                    recipeId: recipeId,
                    originalIngredientId: group.key,
                    recommendation: recommendation,
                    accepted: accepted,
                    displayName: displayName,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubstitutionOption extends ConsumerWidget {
  const _SubstitutionOption({
    required this.recipeId,
    required this.originalIngredientId,
    required this.recommendation,
    required this.accepted,
    required this.displayName,
  });

  final String recipeId;
  final String originalIngredientId;
  final IngredientSubstitutionRecommendation recommendation;
  final Map<String, String> accepted;
  final String Function(String id) displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final substituteId = recommendation.substitution.substituteIngredientId;
    final isAccepted =
        accepted['$recipeId::$originalIngredientId'] == substituteId;
    final canAccept = recommendation.isAvailableInPantry && !isAccepted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                recommendation.isAvailableInPantry
                    ? Icons.kitchen_outlined
                    : Icons.swap_horiz_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName(substituteId),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: ValueKey<String>(
                'accept-substitution-$originalIngredientId-$substituteId',
              ),
              onPressed: canAccept
                  ? () {
                      ref
                          .read(acceptedSubstitutionsProvider.notifier)
                          .accept(
                            recipeId: recipeId,
                            originalIngredientId: originalIngredientId,
                            substituteIngredientId: substituteId,
                          );
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'เลือกใช้ ${displayName(substituteId)} '
                            'แทน ${displayName(originalIngredientId)}',
                          ),
                        ),
                      );
                    }
                  : null,
              child: Text(
                isAccepted
                    ? 'ใช้ตัวเลือกนี้แล้ว'
                    : recommendation.isAvailableInPantry
                    ? 'ยอมรับตัวเลือกแทน'
                    : 'ไม่มีใน Pantry',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _recommendationSignature(
  Map<String, List<IngredientSubstitutionRecommendation>> groups,
) {
  final buffer = StringBuffer();
  for (final group in groups.entries) {
    buffer
      ..write(group.key)
      ..write(':');
    for (final recommendation in group.value) {
      buffer
        ..write(recommendation.substitution.substituteIngredientId)
        ..write('/')
        ..write(recommendation.isAvailableInPantry)
        ..write('/')
        ..write(recommendation.compatibilityScore.toStringAsFixed(4))
        ..write('/')
        ..write(recommendation.reason)
        ..write(';');
    }
    buffer.write('|');
  }
  return buffer.toString();
}
