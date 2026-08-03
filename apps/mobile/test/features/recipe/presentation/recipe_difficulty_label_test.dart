import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/presentation/recipe_difficulty_label.dart';

void main() {
  test('translates the known difficulty values into Thai', () {
    expect(recipeDifficultyLabel('easy'), 'ง่าย');
    expect(recipeDifficultyLabel('medium'), 'ปานกลาง');
    expect(recipeDifficultyLabel('hard'), 'ยาก');
  });

  test(
    'never returns a raw English data value the UI would otherwise leak',
    () {
      for (final difficulty in ['easy', 'medium', 'hard']) {
        expect(recipeDifficultyLabel(difficulty), isNot(difficulty));
      }
    },
  );

  test('falls back to the raw value only for an unrecognized difficulty', () {
    expect(recipeDifficultyLabel('exotic'), 'exotic');
  });
}
