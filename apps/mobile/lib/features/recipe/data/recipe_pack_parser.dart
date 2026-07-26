import '../domain/entities/recipe.dart';
import '../domain/entities/recipe_ingredient.dart';

class RecipePackParser {
  const RecipePackParser();

  List<Recipe> parse(Object? decoded) {
    if (decoded is List<dynamic>) {
      return decoded
          .map(
            (item) => Recipe.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    }

    if (decoded is! Map) {
      throw const FormatException('Recipe asset must be a list or recipe pack');
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
    final rows = pack['recipes'] as List<dynamic>? ?? const <dynamic>[];

    return rows
        .map((rawRow) {
          final row = Map<String, dynamic>.from(rawRow as Map);
          final method = row['method'] as String? ?? 'ปรุง';
          final name = row['name'] as String;
          final ingredientIds = _stringList(row['ingredients']);
          final ingredients = <RecipeIngredient>[
            RecipeIngredient(
              id: heroId,
              name: heroName,
              quantity: heroQuantity,
              unit: heroUnit,
              aliases: heroAliases,
            ),
            ...ingredientIds.map(_buildIngredient),
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

  RecipeIngredient _buildIngredient(String id) {
    final template = _ingredientTemplates[id];
    if (template == null) {
      throw FormatException('Unknown recipe ingredient template: $id');
    }

    return RecipeIngredient(
      id: id,
      name: template.name,
      quantity: template.quantity,
      unit: template.unit,
      required: template.required,
      aliases: template.aliases,
    );
  }
}

class _IngredientTemplate {
  const _IngredientTemplate(
    this.name,
    this.quantity,
    this.unit, {
    this.required = true,
    this.aliases = const <String>[],
  });

  final String name;
  final double quantity;
  final String unit;
  final bool required;
  final List<String> aliases;
}

const Map<String, _IngredientTemplate> _ingredientTemplates = {
  'garlic': _IngredientTemplate(
    'กระเทียม',
    4,
    'กลีบ',
    aliases: <String>['กระเทียมสด'],
  ),
  'chili': _IngredientTemplate(
    'พริก',
    4,
    'เม็ด',
    required: false,
    aliases: <String>['พริกสด', 'พริกขี้หนู'],
  ),
  'holy_basil': _IngredientTemplate(
    'ใบกะเพรา',
    1,
    'กำ',
    aliases: <String>['กะเพรา', 'กระเพรา'],
  ),
  'fish_sauce': _IngredientTemplate('น้ำปลา', 1, 'ช้อนโต๊ะ'),
  'soy_sauce': _IngredientTemplate(
    'ซีอิ๊วขาว',
    1,
    'ช้อนโต๊ะ',
    aliases: <String>['ซีอิ๊ว', 'โชยุ'],
  ),
  'dark_soy_sauce': _IngredientTemplate('ซีอิ๊วดำ', 1, 'ช้อนชา'),
  'oyster_sauce': _IngredientTemplate(
    'น้ำมันหอย',
    1,
    'ช้อนโต๊ะ',
    aliases: <String>['ซอสหอยนางรม'],
  ),
  'cooking_oil': _IngredientTemplate(
    'น้ำมันพืช',
    2,
    'ช้อนโต๊ะ',
    aliases: <String>['น้ำมัน'],
  ),
  'sugar': _IngredientTemplate(
    'น้ำตาล',
    1,
    'ช้อนชา',
    required: false,
    aliases: <String>['น้ำตาลทราย'],
  ),
  'salt': _IngredientTemplate(
    'เกลือ',
    0.5,
    'ช้อนชา',
    aliases: <String>['เกลือป่น'],
  ),
  'pepper': _IngredientTemplate(
    'พริกไทย',
    0.5,
    'ช้อนชา',
    required: false,
    aliases: <String>['พริกไทยดำ'],
  ),
  'rice': _IngredientTemplate('ข้าวสวย', 1, 'ถ้วย', aliases: <String>['ข้าว']),
  'egg': _IngredientTemplate('ไข่ไก่', 1, 'ฟอง', aliases: <String>['ไข่']),
  'pork': _IngredientTemplate(
    'หมูสับ',
    100,
    'กรัม',
    aliases: <String>['หมู', 'เนื้อหมู'],
  ),
  'shrimp': _IngredientTemplate(
    'กุ้ง',
    100,
    'กรัม',
    aliases: <String>['กุ้งสด', 'กุ้งขาว'],
  ),
  'onion': _IngredientTemplate(
    'หอมหัวใหญ่',
    0.5,
    'หัว',
    required: false,
    aliases: <String>['หัวหอมใหญ่'],
  ),
  'spring_onion': _IngredientTemplate(
    'ต้นหอม',
    1,
    'ต้น',
    required: false,
    aliases: <String>['ต้นหอมซอย'],
  ),
  'lime': _IngredientTemplate('มะนาว', 1, 'ลูก', aliases: <String>['น้ำมะนาว']),
  'lemongrass': _IngredientTemplate('ตะไคร้', 2, 'ต้น'),
  'kaffir_lime_leaf': _IngredientTemplate('ใบมะกรูด', 4, 'ใบ'),
  'galangal': _IngredientTemplate('ข่า', 5, 'แว่น'),
  'mushroom': _IngredientTemplate(
    'เห็ด',
    100,
    'กรัม',
    required: false,
    aliases: <String>['เห็ดฟาง', 'เห็ดนางฟ้า'],
  ),
  'broccoli': _IngredientTemplate(
    'บรอกโคลี',
    150,
    'กรัม',
    aliases: <String>['บร็อคโคลี่'],
  ),
  'kale': _IngredientTemplate(
    'คะน้า',
    150,
    'กรัม',
    aliases: <String>['ผักคะน้า'],
  ),
  'celery': _IngredientTemplate(
    'ขึ้นฉ่าย',
    2,
    'ต้น',
    aliases: <String>['คื่นฉ่าย'],
  ),
  'corn': _IngredientTemplate(
    'ข้าวโพดอ่อน',
    100,
    'กรัม',
    aliases: <String>['ข้าวโพด'],
  ),
  'green_pea': _IngredientTemplate('ถั่วลันเตา', 100, 'กรัม'),
  'mixed_vegetables': _IngredientTemplate(
    'ผักรวม',
    150,
    'กรัม',
    aliases: <String>['แครอท', 'บรอกโคลี'],
  ),
  'chili_paste': _IngredientTemplate(
    'น้ำพริกเผา',
    1,
    'ช้อนโต๊ะ',
    aliases: <String>['พริกเผา'],
  ),
  'salted_egg': _IngredientTemplate('ไข่เค็ม', 1, 'ฟอง'),
  'glass_noodle': _IngredientTemplate(
    'วุ้นเส้น',
    80,
    'กรัม',
    aliases: <String>['วุ้นเส้นแห้ง'],
  ),
  'tamarind_sauce': _IngredientTemplate(
    'น้ำมะขามเปียก',
    2,
    'ช้อนโต๊ะ',
    aliases: <String>['ซอสมะขาม'],
  ),
  'coconut_milk': _IngredientTemplate('กะทิ', 250, 'มิลลิลิตร'),
  'red_curry_paste': _IngredientTemplate(
    'พริกแกงแดง',
    1,
    'ช้อนโต๊ะ',
    aliases: <String>['พริกแกง'],
  ),
  'sour_curry_paste': _IngredientTemplate('พริกแกงส้ม', 1, 'ช้อนโต๊ะ'),
  'breadcrumbs': _IngredientTemplate('เกล็ดขนมปัง', 100, 'กรัม'),
  'flour': _IngredientTemplate(
    'แป้งทอดกรอบ',
    100,
    'กรัม',
    aliases: <String>['แป้ง'],
  ),
  'ginger': _IngredientTemplate('ขิง', 20, 'กรัม', aliases: <String>['ขิงซอย']),
  'cabbage': _IngredientTemplate(
    'กะหล่ำปลี',
    150,
    'กรัม',
    aliases: <String>['กะหล่ำ'],
  ),
  'tofu': _IngredientTemplate('เต้าหู้', 1, 'ก้อน'),
  'potato': _IngredientTemplate('มันฝรั่ง', 1, 'หัว'),
  'cashew': _IngredientTemplate('เม็ดมะม่วงหิมพานต์', 50, 'กรัม'),
  'tomato': _IngredientTemplate('มะเขือเทศ', 1, 'ลูก'),
};

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
