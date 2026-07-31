import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../shopping/presentation/widgets/recommended_purchases_section.dart';
import 'pantry_insights_card.dart';

/// Composes the two reusable, provider-backed intelligence surfaces
/// (Pantry Insights + Recommended Purchases) for the Pantry screen. Both
/// widgets own no local state — everything lives in their respective
/// Riverpod providers, so the same widgets can also be embedded on Shopping.
class PantryIntelligenceSection extends StatelessWidget {
  const PantryIntelligenceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PantryInsightsCard(),
        SizedBox(height: AppSpacing.md),
        RecommendedPurchasesSection(),
      ],
    );
  }
}
