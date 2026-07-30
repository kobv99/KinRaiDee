import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_recommendation.dart';
import 'package:mobile/features/recipe/presentation/widgets/recipe_recommendation_explanation_panel.dart';

void main() {
  testWidgets(
    'expanded explanation scrolls without overflowing a short screen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RecipeRecommendationExplanationPanel(
                  recommendation: _recommendation,
                ),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('ทำไมถึงแนะนำเมนูนี้?'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('คะแนน 62'), findsNothing);
      expect(find.textContaining('ตรงกับ Pantry 65%'), findsOneWidget);
      expect(
        tester
            .getSize(find.byType(RecipeRecommendationExplanationPanel))
            .height,
        lessThanOrEqualTo(420),
      );
    },
  );
}

const _rice = RecipeIngredient(
  id: 'rice',
  name: 'ข้าวสาร',
  quantity: 1,
  unit: 'ถ้วย',
  role: RecipeIngredientRole.primary,
);

const _egg = RecipeIngredient(
  id: 'egg',
  name: 'ไข่',
  quantity: 1,
  unit: 'ฟอง',
  role: RecipeIngredientRole.secondary,
);

const _recipe = Recipe(
  id: 'fried-rice',
  name: 'ข้าวผัด',
  category: 'อาหารจานเดียว',
  servings: 2,
  heroIngredientId: 'rice',
  ingredients: [_rice, _egg],
  steps: ['ผัดส่วนผสมให้เข้ากัน'],
);

const _recommendation = RecipeRecommendation(
  match: RecipeMatch(
    recipe: _recipe,
    matchedIngredients: [_rice],
    missingIngredients: [_egg],
    score: 0.65,
  ),
  score: 62,
  components: [],
  reasons: [
    'มีวัตถุดิบตรงกับสูตร 65%',
    'ขาดวัตถุดิบจำเป็น 1 รายการ',
    'ช่วยใช้วัตถุดิบใกล้หมดอายุ 1 รายการ',
    'ใช้เวลาประมาณ 30 นาที',
    'สูตรใช้วัตถุดิบ 4 รายการ',
    'เหตุผลเพิ่มเติมสำหรับทดสอบพื้นที่แนวตั้ง',
  ],
  badges: [],
  expiringIngredientIds: [],
  availableSubstitutions: {},
  pantryIngredientCount: 4,
  usedPantryIngredientCount: 1,
);
