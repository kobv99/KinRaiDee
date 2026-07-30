class RecipeStep {
  const RecipeStep({
    required this.title,
    required this.instruction,
    this.ingredientIds = const <String>[],
    this.quantities = const <String, String>{},
    this.durationMinutes,
    this.heatLevel,
    this.completionCue,
    this.tip,
  });

  final String title;
  final String instruction;
  final List<String> ingredientIds;
  final Map<String, String> quantities;
  final int? durationMinutes;
  final String? heatLevel;
  final String? completionCue;
  final String? tip;

  String get accessibleInstruction {
    final details = <String>[
      instruction,
      if (durationMinutes != null) 'ใช้เวลาประมาณ $durationMinutes นาที',
      if (heatLevel?.trim().isNotEmpty == true) 'ระดับไฟ $heatLevel',
      if (completionCue?.trim().isNotEmpty == true) 'สังเกตว่า $completionCue',
      if (tip?.trim().isNotEmpty == true) 'เคล็ดลับ: $tip',
    ];
    return details.join(' · ');
  }

  factory RecipeStep.fromJson(Object? raw, {required int index}) {
    if (raw is String) {
      return RecipeStep(title: 'ขั้นตอน ${index + 1}', instruction: raw);
    }
    if (raw is! Map) {
      throw const FormatException('Invalid Recipe step.');
    }
    final json = Map<String, dynamic>.from(raw);
    final instruction = json['instruction']?.toString().trim() ?? '';
    if (instruction.isEmpty) {
      throw const FormatException('Recipe step instruction is required.');
    }
    return RecipeStep(
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'ขั้นตอน ${index + 1}',
      instruction: instruction,
      ingredientIds: _stringList(json['ingredientIds']),
      quantities:
          (json['quantities'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const <String, String>{},
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      heatLevel: json['heatLevel']?.toString(),
      completionCue: json['completionCue']?.toString(),
      tip: json['tip']?.toString(),
    );
  }
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
