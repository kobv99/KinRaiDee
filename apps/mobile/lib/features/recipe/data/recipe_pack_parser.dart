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
            steps: _buildSteps(
              method: method,
              heroName: heroName,
              difficulty: row['difficulty'] as String? ?? 'easy',
              cookTimeMinutes: (row['time'] as num?)?.toInt() ?? 0,
            ),
          );
        })
        .toList(growable: false);
  }

  /// Builds a step list whose length reflects the recipe's actual
  /// complexity (declared difficulty plus cook time) instead of a fixed
  /// count: ~4-5 granular steps for a quick "easy" recipe, ~6-8 for a
  /// "medium" one, and one extra refinement step on top of that for a
  /// "hard" or unusually long-cooking recipe. Method-specific actions are
  /// decomposed into individual steps (heat pan, add oil, aromatics,
  /// protein, ...) rather than merged into one vague combined instruction.
  List<String> _buildSteps({
    required String method,
    required String heroName,
    required String difficulty,
    required int cookTimeMinutes,
  }) {
    final template = _stepTemplates[method] ?? _stepTemplates[_defaultMethod]!;
    final isComplex =
        difficulty == 'hard' ||
        (difficulty == 'medium' && cookTimeMinutes >= 30);
    final isSimple = difficulty == 'easy' && cookTimeMinutes < 30;

    final steps = isComplex
        ? <String>[...template.normal, template.complexTail]
        : (isSimple ? template.simple : template.normal);

    return steps
        .map((step) => step.replaceAll('{hero}', heroName))
        .toList(growable: false);
  }
}

const String _defaultMethod = 'ปรุง';

/// Two hand-authored step decompositions per cooking method (a compact one
/// for quick/easy recipes, a fuller one for everything else) plus one extra
/// closing step appended for recipes complex enough to warrant it. `{hero}`
/// is substituted with the recipe's hero ingredient name.
class _MethodStepTemplate {
  const _MethodStepTemplate({
    required this.simple,
    required this.normal,
    required this.complexTail,
  });

  final List<String> simple;
  final List<String> normal;
  final String complexTail;
}

final Map<String, _MethodStepTemplate> _stepTemplates =
    <String, _MethodStepTemplate>{
      'ผัด': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ตั้งกระทะ ใส่น้ำมัน แล้วผัดเครื่องหอมให้มีกลิ่นหอม',
          'ใส่{hero}ลงผัดจนเกือบสุก',
          'ใส่วัตถุดิบที่เหลือ แล้วปรุงรส',
          'ตรวจความสุกและตักเสิร์ฟ',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ตั้งกระทะให้ร้อน',
          'ใส่น้ำมันลงกระทะ',
          'ผัดกระเทียมหรือเครื่องหอมให้มีกลิ่นหอม',
          'ใส่{hero}ลงผัด',
          'ผัดจนเกือบสุก',
          'ใส่วัตถุดิบที่เหลือ แล้วปรุงรส',
          'ตรวจความสุกและตักเสิร์ฟ',
        ],
        complexTail: 'พักให้รสชาติเข้าเนื้อสักครู่ก่อนตักเสิร์ฟ',
      ),
      'ทอด': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ปรุงรสหรือคลุก{hero}กับส่วนผสมตามสูตร',
          'ตั้งน้ำมันให้ร้อนได้ที่',
          'ทอด{hero}จนสุกเหลือง',
          'พักให้สะเด็ดน้ำมันแล้วเสิร์ฟ',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'หมักหรือคลุก{hero}กับเครื่องปรุงให้ทั่ว',
          'เตรียมแป้งชุบหรือส่วนผสมตามสูตร',
          'ตั้งน้ำมันให้ร้อนได้ที่',
          'ทอด{hero}จนสุกเหลืองกรอบ',
          'พักบนตะแกรงให้สะเด็ดน้ำมัน',
          'จัดใส่จานและเสิร์ฟขณะร้อน',
        ],
        complexTail: 'เตรียมน้ำจิ้มหรือเครื่องเคียงเสิร์ฟคู่กัน',
      ),
      'ต้ม': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ต้มน้ำหรือน้ำซุปให้เดือด',
          'ใส่{hero}ลงต้มจนสุก',
          'ปรุงรสตามชอบ',
          'ตักเสิร์ฟขณะร้อน',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ต้มน้ำหรือน้ำซุปกับเครื่องสมุนไพรจนเดือด',
          'ปรับไฟให้พอเดือดเบา ๆ ให้กลิ่นหอมออก',
          'ใส่{hero}ลงต้ม',
          'ต้มจนสุกทั่วถึง',
          'ปรุงรสให้กลมกล่อม',
          'ตักเสิร์ฟพร้อมเครื่องเคียง',
        ],
        complexTail: 'ชิมและปรับรสอีกครั้งก่อนปิดไฟ',
      ),
      'แกง': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ผัดหรือละลายพริกแกงกับน้ำหรือกะทิจนหอม',
          'ใส่{hero}ลงผัดให้เข้าเครื่องแกง',
          'เติมน้ำหรือกะทิ ต้มจนสุก แล้วปรุงรส',
          'ตักเสิร์ฟพร้อมข้าวสวย',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ตั้งกะทิหรือน้ำมันให้ร้อน',
          'ผัดพริกแกงจนหอมและแตกมัน',
          'ใส่{hero}ลงผัดให้เข้าเครื่องแกง',
          'เติมน้ำหรือกะทิ แล้วต้มจนเดือด',
          'ใส่ผัก ต้มจนสุก แล้วปรุงรสให้กลมกล่อม',
          'ตักเสิร์ฟพร้อมข้าวสวย',
        ],
        complexTail: 'พักให้รสชาติเข้ากันก่อนเสิร์ฟ',
      ),
      'ยำ': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ทำ{hero}ให้สุกแล้วพักให้คลายร้อน',
          'ผสมน้ำยำ ใส่{hero}และผัก คลุกให้เข้ากัน',
          'จัดใส่จานแล้วเสิร์ฟทันที',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ทำ{hero}ให้สุก',
          'พักให้{hero}คลายร้อนเล็กน้อย',
          'ปรุงน้ำยำให้รสจัดจ้าน',
          'ใส่{hero}และผักลงคลุกเบา ๆ',
          'จัดใส่จานแล้วเสิร์ฟทันทีขณะยังกรอบ',
        ],
        complexTail: 'โรยเครื่องเคียงหรือถั่วคั่วเพิ่มความหอมก่อนเสิร์ฟ',
      ),
      'นึ่ง': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และเครื่องปรุงให้พร้อม',
          'จัด{hero}ลงจานสำหรับนึ่ง',
          'นึ่งจนสุกดี',
          'ราดน้ำปรุงแล้วเสิร์ฟขณะร้อน',
        ],
        normal: <String>[
          'เตรียม{hero}และเครื่องปรุงให้พร้อม',
          'จัด{hero}และเครื่องปรุงลงจานสำหรับนึ่ง',
          'ตั้งน้ำในลังถึงให้เดือดจัด',
          'นึ่ง{hero}จนสุกทั่วถึง',
          'เตรียมน้ำปรุงหรือน้ำจิ้มคู่กัน',
          'ราดน้ำปรุงแล้วเสิร์ฟขณะร้อน',
        ],
        complexTail: 'โรยผักชีหรือเครื่องหอมตกแต่งก่อนเสิร์ฟ',
      ),
      'ย่าง': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}ให้พร้อม',
          'หมัก{hero}กับเครื่องปรุงให้เข้าเนื้อ',
          'ย่างด้วยไฟปานกลางจนสุกหอม',
          'พลิกให้สุกทั่วแล้วเสิร์ฟ',
        ],
        normal: <String>[
          'เตรียม{hero}ให้พร้อม',
          'หมัก{hero}กับเครื่องปรุงให้เข้าเนื้อ',
          'พักให้เครื่องปรุงซึมเข้าเนื้ออย่างน้อยสักครู่',
          'ตั้งเตาย่างด้วยไฟปานกลาง',
          'ย่าง{hero} พลิกกลับด้านเป็นระยะจนสุกหอม',
          'พักเนื้อสักครู่ก่อนหั่นเสิร์ฟ',
        ],
        complexTail: 'เตรียมน้ำจิ้มรสจัดจ้านเสิร์ฟคู่กัน',
      ),
      'อบ': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'จัด{hero}ลงภาชนะ ปรุงรสให้ทั่ว',
          'อบจนสุกและน้ำซอสเข้าเนื้อ',
          'พักสักครู่แล้วเสิร์ฟ',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'อุ่นเตาอบให้ได้อุณหภูมิ',
          'จัด{hero}และวัตถุดิบลงภาชนะ ปรุงรสให้ทั่ว',
          'นำเข้าอบจนสุก',
          'ตรวจดูให้น้ำซอสเข้าเนื้อและผิวสวย',
          'พักสักครู่ก่อนเสิร์ฟ',
        ],
        complexTail: 'โรยเครื่องหอมหรือชีสเพิ่มรสชาติก่อนเสิร์ฟ',
      ),
      'คั่ว': const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และเครื่องปรุงให้พร้อม',
          'ผัดเครื่องหอมด้วยไฟกลางจนหอม',
          'ใส่{hero}คั่วจนสุกแห้งกำลังดี',
          'ปรุงรสแล้วเสิร์ฟ',
        ],
        normal: <String>[
          'เตรียม{hero}และเครื่องปรุงให้พร้อม',
          'ตั้งกระทะไฟกลาง',
          'ผัดเครื่องหอมจนมีกลิ่นหอม',
          'ใส่{hero}ลงคั่ว',
          'คั่วจนสุกแห้งกำลังดี',
          'ปรุงรสให้กลมกล่อมแล้วเสิร์ฟ',
        ],
        complexTail: 'ชิมรสและปรับเครื่องปรุงอีกครั้งก่อนเสิร์ฟ',
      ),
      _defaultMethod: const _MethodStepTemplate(
        simple: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'ปรุง{hero}กับวัตถุดิบตามสูตรจนสุก',
          'ชิมรสและปรับให้กลมกล่อม',
          'ตักใส่จานและเสิร์ฟขณะร้อน',
        ],
        normal: <String>[
          'เตรียม{hero}และวัตถุดิบให้พร้อม',
          'เตรียมเครื่องปรุงตามสูตร',
          'ปรุง{hero}กับวัตถุดิบตามขั้นตอนจนเกือบสุก',
          'ใส่วัตถุดิบที่เหลือให้เข้ากัน',
          'ชิมรสและปรับให้กลมกล่อม',
          'ตักใส่จานและเสิร์ฟขณะร้อน',
        ],
        complexTail: 'จัดตกแต่งจานให้น่ารับประทานก่อนเสิร์ฟ',
      ),
    };

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
