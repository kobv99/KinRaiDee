import '../domain/entities/recipe.dart';
import '../domain/entities/recipe_ingredient.dart';
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
            steps: _buildSteps(method: method, heroName: heroName),
            supportsSubstitutions:
                row['supportsSubstitutions'] as bool? ??
                packSupportsSubstitutions,
          );
        })
        .toList(growable: false);
  }

  List<String> _buildSteps({required String method, required String heroName}) {
    final preparation = 'เตรียม$heroNameและวัตถุดิบทั้งหมดให้พร้อม';

    return switch (method) {
      'ผัด' => <String>[
        preparation,
        'ตั้งกระทะ ใส่น้ำมัน แล้วผัดเครื่องหอมให้มีกลิ่นหอม',
        'ใส่$heroNameและวัตถุดิบที่เหลือ ผัดจนสุก แล้วปรุงรส',
      ],
      'ทอด' => <String>[
        preparation,
        'ปรุงรสหรือคลุก$heroNameกับส่วนผสมตามสูตร',
        'ตั้งน้ำมันให้ร้อน ทอดจนสุกเหลือง แล้วพักให้สะเด็ดน้ำมัน',
      ],
      'ต้ม' => <String>[
        preparation,
        'ต้มน้ำหรือน้ำซุปกับเครื่องสมุนไพรจนเดือดและมีกลิ่นหอม',
        'ใส่$heroName ต้มจนสุก ปรุงรส แล้วปิดไฟ',
      ],
      'แกง' => <String>[
        preparation,
        'ผัดหรือละลายพริกแกงกับน้ำหรือกะทิจนหอม',
        'ใส่$heroNameและผัก ต้มจนสุก แล้วปรุงรสให้กลมกล่อม',
      ],
      'ยำ' => <String>[
        preparation,
        'ทำ$heroNameให้สุก แล้วพักไว้ให้คลายร้อนเล็กน้อย',
        'ผสมน้ำยำ ใส่$heroNameและผัก คลุกเบา ๆ แล้วเสิร์ฟ',
      ],
      'นึ่ง' => <String>[
        preparation,
        'จัด$heroNameและเครื่องปรุงลงจานสำหรับนึ่ง',
        'นึ่งจน$heroNameสุก ราดน้ำปรุง แล้วเสิร์ฟขณะร้อน',
      ],
      'ย่าง' => <String>[
        preparation,
        'หมัก$heroNameกับเครื่องปรุงให้เข้าเนื้อ',
        'ย่างด้วยไฟปานกลางจนสุกหอม พลิกเป็นระยะ แล้วเสิร์ฟ',
      ],
      'อบ' => <String>[
        preparation,
        'จัด$heroNameและวัตถุดิบลงภาชนะ ปรุงรสให้ทั่ว',
        'อบจนทุกอย่างสุกและน้ำซอสเข้าเนื้อ แล้วเสิร์ฟ',
      ],
      'คั่ว' => <String>[
        preparation,
        'ผัดเครื่องหอมด้วยไฟกลางจนมีกลิ่นหอม',
        'ใส่$heroName คั่วจนสุกและแห้งกำลังดี แล้วปรุงรส',
      ],
      _ => <String>[
        preparation,
        'ปรุง$heroNameกับวัตถุดิบตามสูตรจนสุกและเข้ากัน',
        'ชิมรส ตักใส่จาน และเสิร์ฟขณะร้อน',
      ],
    };
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
