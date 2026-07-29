import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../recipe/domain/entities/recipe_readiness.dart';
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
        return Card(
          key: const ValueKey('recipe-substitution-panel'),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.38).clamp(
                180.0,
                320.0,
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ตัวเลือกวัตถุดิบทดแทน',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'แสดงเมื่อสูตรรองรับ วัตถุดิบจำเป็นขาด '
                      'และมีข้อมูลทดแทนในคลังความรู้',
                    ),
                    const Text('คำแนะนำเป็นทางเลือก คุณยังทำอาหารต่อได้เสมอ'),
                    for (final group in groups.entries) ...[
                      const Divider(),
                      Text('แทน ${displayName(group.key)}'),
                      for (final recommendation in group.value)
                        Builder(
                          builder: (context) {
                            final substituteId = recommendation
                                .substitution
                                .substituteIngredientId;
                            final isAccepted =
                                accepted['$recipeId::${group.key}'] ==
                                substituteId;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(displayName(substituteId)),
                              subtitle: Text(recommendation.reason),
                              leading: recommendation.isAvailableInPantry
                                  ? const Icon(Icons.kitchen_outlined)
                                  : const Icon(Icons.swap_horiz),
                              trailing: FilledButton.tonal(
                                key: ValueKey(
                                  'accept-substitution-${group.key}-$substituteId',
                                ),
                                onPressed:
                                    recommendation.isAvailableInPantry &&
                                        !isAccepted
                                    ? () {
                                        ref
                                            .read(
                                              acceptedSubstitutionsProvider
                                                  .notifier,
                                            )
                                            .accept(
                                              recipeId: recipeId,
                                              originalIngredientId: group.key,
                                              substituteIngredientId:
                                                  substituteId,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'ใช้ ${displayName(substituteId)} '
                                              'แทน ${displayName(group.key)} แล้ว',
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
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
