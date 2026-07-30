import '../domain/entities/recipe.dart';
import '../domain/entities/recipe_ingredient.dart';
import '../domain/entities/recipe_step.dart';
import 'recipe_ingredient_catalog.dart';

class RecipePackParser {
  const RecipePackParser({required this.catalog});

  final RecipeIngredientCatalog catalog;

  List<Recipe> parse(Object? decoded) {
    if (decoded is List<dynamic>) {
      return decoded
          .map(
            (item) => Recipe.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    }

    if (decoded is! Map) {
      throw const FormatException('Invalid Recipe data.');
    }

    return _parsePack(Map<String, dynamic>.from(decoded));
  }

  List<Recipe> _parsePack(Map<String, dynamic> pack) {
    final version = (pack['version'] as num?)?.toInt() ?? 1;
    final hero = Map<String, dynamic>.from(pack['hero'] as Map);
    final heroId = hero['id'] as String;
    final heroName = hero['name'] as String;
    final heroEmoji = hero['emoji'] as String? ?? '🍳';
    final heroQuantity = (hero['quantity'] as num?)?.toDouble() ?? 1;
    final heroUnit = hero['unit'] as String? ?? '';
    final heroAliases = _stringList(hero['aliases']);
    final defaultPrimaryWeight =
        (pack['defaultPrimaryWeight'] as num?)?.toDouble() ?? 40;
    final heroRole =
        recipeIngredientRoleFromJson(hero['role']) ??
        RecipeIngredientRole.primary;
    final heroWeight =
        (hero['weight'] as num?)?.toDouble() ?? defaultPrimaryWeight;
    final rows = pack['recipes'] as List<dynamic>? ?? const <dynamic>[];
    final packSupportsSubstitutions =
        pack['supportsSubstitutions'] as bool? ?? true;

    return rows
        .map((rawRow) {
          final row = Map<String, dynamic>.from(rawRow as Map);
          final method = row['method'] as String? ?? 'ปรุง';
          final name = row['name'] as String;
          final rawIngredients =
              row['ingredients'] as List<dynamic>? ?? const <dynamic>[];
          final ingredients = <RecipeIngredient>[
            RecipeIngredient(
              id: heroId,
              name: heroName,
              quantity: heroQuantity,
              unit: heroUnit,
              aliases: heroAliases,
              role: heroRole,
              weight: heroWeight,
            ),
            ...rawIngredients.map(catalog.build),
          ];
          final authoredSteps = _parseAuthoredSteps(row['steps']);
          final detailedSteps = authoredSteps.isNotEmpty
              ? authoredSteps
              : _buildSteps(method: method, heroId: heroId, heroName: heroName);

          return Recipe(
            version: version,
            id: row['id'] as String,
            name: name,
            category: row['category'] as String? ?? 'อาหารไทย',
            description:
                row['description'] as String? ??
                '$name เมนู$methodทำง่าย เหมาะสำหรับมื้อประจำวัน',
            emoji: row['emoji'] as String? ?? heroEmoji,
            difficulty: row['difficulty'] as String? ?? 'easy',
            cookTimeMinutes: (row['time'] as num?)?.toInt() ?? 0,
            servings: (row['servings'] as num?)?.toInt() ?? 2,
            tags: <String>[heroName, method, 'อาหารไทย'],
            cookingMethods: <String>[method],
            heroIngredientId: heroId,
            heroIngredientName: heroName,
            popularity: (row['popularity'] as num?)?.toInt() ?? 0,
            ingredients: ingredients,
            steps: detailedSteps
                .map((step) => step.instruction)
                .toList(growable: false),
            detailedSteps: detailedSteps,
            supportsSubstitutions:
                row['supportsSubstitutions'] as bool? ??
                packSupportsSubstitutions,
          );
        })
        .toList(growable: false);
  }

  List<RecipeStep> _parseAuthoredSteps(Object? raw) {
    final rows = raw as List<dynamic>? ?? const <dynamic>[];
    return rows.indexed
        .map((entry) => RecipeStep.fromJson(entry.$2, index: entry.$1))
        .toList(growable: false);
  }

  List<RecipeStep> _buildSteps({
    required String method,
    required String heroId,
    required String heroName,
  }) {
    final common = <RecipeStep>[
      RecipeStep(
        title: 'เตรียมวัตถุดิบ',
        instruction:
            'ล้าง หั่น และตวง$heroNameกับวัตถุดิบทุกอย่างตามรายการก่อนเริ่มปรุง',
        ingredientIds: <String>[heroId],
        durationMinutes: 5,
        completionCue: 'วัตถุดิบถูกแบ่งเป็นสัดส่วนและพร้อมลงกระทะ',
      ),
      RecipeStep(
        title: 'ปรุงรสล่วงหน้า',
        instruction:
            'ผสมเครื่องปรุงตามสูตร ชิมเฉพาะส่วนที่ปลอดภัย และพักไว้ให้หยิบใช้ได้ทันที',
        durationMinutes: 2,
        completionCue: 'เครื่องปรุงละลายเข้ากัน ไม่มีน้ำตาลหรือเกลือจับก้อน',
      ),
    ];
    final cooking = switch (method) {
      'ทอด' => <RecipeStep>[
        RecipeStep(
          title: 'ตั้งน้ำมัน',
          instruction: 'ตั้งน้ำมันให้ร้อนสม่ำเสมอก่อนใส่$heroName',
          durationMinutes: 3,
          heatLevel: 'กลาง',
          completionCue: 'น้ำมันร้อนแต่ยังไม่เกิดควัน',
        ),
        RecipeStep(
          title: 'ทอดด้านแรก',
          instruction: 'วาง$heroNameลงทอดโดยไม่วางชิ้นซ้อนกัน',
          ingredientIds: <String>[heroId],
          durationMinutes: 4,
          heatLevel: 'กลาง',
          completionCue: 'ด้านล่างเป็นสีเหลืองทองและหลุดจากกระทะง่าย',
        ),
        RecipeStep(
          title: 'ทอดให้สุกทั่ว',
          instruction: 'กลับด้านแล้วทอดต่อ ลดไฟหากผิวเข้มเร็วเกินไป',
          durationMinutes: 4,
          heatLevel: 'กลาง',
          completionCue: '$heroNameสุกถึงด้านในและผิวกรอบ',
        ),
      ],
      'ต้ม' || 'แกง' => <RecipeStep>[
        RecipeStep(
          title: 'สร้างน้ำซุป',
          instruction: 'ต้มน้ำหรือน้ำซุปกับเครื่องหอมจนเดือดและส่งกลิ่นหอม',
          durationMinutes: 5,
          heatLevel: 'กลางค่อนแรง',
          completionCue: 'น้ำซุปเดือดทั่วและมีกลิ่นเครื่องสมุนไพร',
        ),
        RecipeStep(
          title: 'ทำให้วัตถุดิบหลักสุก',
          instruction: 'ใส่$heroNameลงต้มและช้อนฟองออกเพื่อให้น้ำซุปใส',
          ingredientIds: <String>[heroId],
          durationMinutes: 8,
          heatLevel: 'กลาง',
          completionCue: '$heroNameสุกถึงด้านใน',
        ),
        RecipeStep(
          title: 'เติมผักและปรุงรส',
          instruction:
              'ใส่วัตถุดิบที่สุกง่ายและเครื่องปรุง ชิมแล้วปรับทีละน้อย',
          durationMinutes: 4,
          heatLevel: 'อ่อน',
          completionCue: 'ผักสุกแต่ยังคงเนื้อสัมผัสและรสกลมกล่อม',
        ),
      ],
      'ย่าง' || 'อบ' || 'นึ่ง' => <RecipeStep>[
        RecipeStep(
          title: 'เตรียมความร้อน',
          instruction: 'อุ่นอุปกรณ์ให้ถึงความร้อนที่เหมาะกับการ$method',
          durationMinutes: 5,
          heatLevel: 'กลาง',
          completionCue: 'ความร้อนคงที่ก่อนนำอาหารเข้า',
        ),
        RecipeStep(
          title: '$methodวัตถุดิบหลัก',
          instruction: 'จัด$heroNameให้ได้รับความร้อนทั่วถึงโดยไม่วางซ้อนกัน',
          ingredientIds: <String>[heroId],
          durationMinutes: 10,
          heatLevel: 'กลาง',
          completionCue: '$heroNameสุกถึงด้านในและยังชุ่มฉ่ำ',
        ),
        RecipeStep(
          title: 'พักและตรวจความสุก',
          instruction: 'นำออกจากความร้อน พักสั้น ๆ แล้วตรวจส่วนที่หนาที่สุด',
          durationMinutes: 3,
          completionCue: 'ไม่มีส่วนดิบและน้ำที่ไหลออกมาใส',
        ),
      ],
      _ => <RecipeStep>[
        RecipeStep(
          title: 'ผัดเครื่องหอม',
          instruction: 'ตั้งกระทะ ใส่น้ำมัน แล้วผัดเครื่องหอมให้ส่งกลิ่น',
          durationMinutes: 2,
          heatLevel: 'กลาง',
          completionCue: 'เครื่องหอมนุ่มและไม่ไหม้',
        ),
        RecipeStep(
          title: 'ทำให้วัตถุดิบหลักสุก',
          instruction: 'ใส่$heroName กระจายให้สัมผัสกระทะ และผัดอย่างสม่ำเสมอ',
          ingredientIds: <String>[heroId],
          durationMinutes: 5,
          heatLevel: 'กลางค่อนแรง',
          completionCue: '$heroNameสุกทั่วและไม่มีส่วนดิบ',
        ),
        RecipeStep(
          title: 'รวมรสชาติ',
          instruction: 'ใส่วัตถุดิบที่เหลือและน้ำปรุง คลุกจนเคลือบทั่ว',
          durationMinutes: 3,
          heatLevel: 'กลาง',
          completionCue: 'ซอสเคลือบวัตถุดิบและไม่มีน้ำขังเกินไป',
        ),
      ],
    };
    return <RecipeStep>[
      ...common,
      ...cooking,
      RecipeStep(
        title: 'ชิมและเสิร์ฟ',
        instruction:
            'ปิดไฟ ชิมรสสุดท้าย ปรับเฉพาะที่จำเป็น แล้วตักเสิร์ฟขณะเหมาะสม',
        durationMinutes: 2,
        heatLevel: 'ปิดไฟ',
        completionCue: 'รสชาติสมดุลและอาหารพร้อมรับประทาน',
      ),
    ];
  }
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
