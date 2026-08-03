/// Localizes a [Recipe.difficulty] data value into user-facing Thai. Never
/// display the raw `easy`/`medium`/`hard` data value directly in the UI.
String recipeDifficultyLabel(String difficulty) {
  return switch (difficulty) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ยาก',
    _ => difficulty,
  };
}
