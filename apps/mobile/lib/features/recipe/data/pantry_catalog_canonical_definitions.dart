import '../../../core/domain/ingredients/canonical_ingredient.dart';

List<CanonicalIngredient> applyPantryCatalogCanonicalCoverage(
  List<CanonicalIngredient> base,
) {
  final byId = <String, CanonicalIngredient>{
    for (final ingredient in base) ingredient.id: ingredient,
  };

  void addAliases(String id, List<String> aliases) {
    final current = byId[id];
    if (current == null) {
      return;
    }
    byId[id] = CanonicalIngredient(
      id: current.id,
      canonicalName: current.canonicalName,
      localizedNames: current.localizedNames,
      aliases: <String>{...current.aliases, ...aliases}.toList(growable: false),
      searchKeywords: current.searchKeywords,
      category: current.category,
      defaultStorageType: current.defaultStorageType,
      defaultPurchaseUnitId: current.defaultPurchaseUnitId,
      defaultInventoryUnitId: current.defaultInventoryUnitId,
      emoji: current.emoji,
      preferredUnitId: current.preferredUnitId,
      recommendedUnitIds: current.recommendedUnitIds,
      unitFamily: current.unitFamily,
      parentId: current.parentId,
      nodeType: current.nodeType,
      taxonomyType: current.taxonomyType,
      selectableAsMainIngredient: current.selectableAsMainIngredient,
      ingredientForms: current.ingredientForms,
      textures: current.textures,
      supportedCookingMethods: current.supportedCookingMethods,
      metadata: current.metadata,
      defaultPantryQuantity: current.defaultPantryQuantity,
    );
  }

  // 'ปลาทับทิม' (red tilapia) is deliberately not an alias here — the Full
  // Animal & Seafood Taxonomy manifest gives it its own canonical id,
  // red_tilapia, under freshwater_fish_family (see
  // assets/ingredients/thai_ingredients.json). See the matching semantic
  // migration rule for records that predate this split.
  addAliases('tilapia', const <String>['Tilapia', 'tilapia']);
  addAliases('corn', const <String>['ข้าวโพดอ่อน']);
  addAliases('tamarind_sauce', const <String>['มะขามเปียก']);

  for (final seed in _seeds) {
    byId.putIfAbsent(seed.id, seed.build);
  }

  final result = byId.values.toList(growable: false)
    ..sort((first, second) => first.id.compareTo(second.id));
  return List<CanonicalIngredient>.unmodifiable(result);
}

enum _UnitProfile { mass, volume, count, egg }

class _DefinitionSeed {
  const _DefinitionSeed(
    this.id,
    this.canonicalName,
    this.thaiName,
    this.category,
    this.emoji, {
    this.aliases = const <String>[],
    this.profile = _UnitProfile.mass,
    this.parentId,
    this.pantryStable = false,
    this.unitFamily = IngredientUnitFamily.generic,
    this.nodeType = CanonicalIngredientNodeType.ingredient,
    this.selectableAsMainIngredient = true,
    this.ingredientForms = const <String>[],
    this.textures = const <String>[],
    this.supportedCookingMethods = const <String>[],
  });

  final String id;
  final String canonicalName;
  final String thaiName;
  final String category;
  final String emoji;
  final List<String> aliases;
  final _UnitProfile profile;
  final String? parentId;
  final bool pantryStable;
  final IngredientUnitFamily unitFamily;
  final CanonicalIngredientNodeType nodeType;
  final bool selectableAsMainIngredient;
  final List<String> ingredientForms;
  final List<String> textures;
  final List<String> supportedCookingMethods;

  CanonicalIngredient build() {
    final units = switch (profile) {
      _UnitProfile.mass => (
        purchase: 'kilogram',
        inventory: 'gram',
        recommended: const <String>['kilogram', 'gram'],
      ),
      _UnitProfile.volume => (
        purchase: 'liter',
        inventory: 'milliliter',
        recommended: const <String>['liter', 'milliliter'],
      ),
      _UnitProfile.count => (
        purchase: 'piece',
        inventory: 'piece',
        recommended: const <String>['piece'],
      ),
      _UnitProfile.egg => (
        purchase: 'egg',
        inventory: 'egg',
        recommended: const <String>['egg'],
      ),
    };
    final refrigerated =
        category == 'protein' ||
        category == 'seafood' ||
        category == 'vegetable' ||
        category == 'herb';
    final storage = pantryStable
        ? IngredientStorageType.pantry
        : refrigerated
        ? IngredientStorageType.refrigerated
        : IngredientStorageType.pantry;

    return CanonicalIngredient(
      id: id,
      canonicalName: canonicalName,
      localizedNames: <String, String>{'th': thaiName},
      aliases: aliases,
      searchKeywords: <String>[thaiName, category],
      category: category,
      defaultStorageType: storage,
      defaultPurchaseUnitId: units.purchase,
      defaultInventoryUnitId: units.inventory,
      emoji: emoji,
      preferredUnitId: units.purchase,
      recommendedUnitIds: units.recommended,
      unitFamily: profile == _UnitProfile.volume
          ? IngredientUnitFamily.liquid
          : unitFamily,
      parentId: parentId,
      nodeType: nodeType,
      selectableAsMainIngredient: selectableAsMainIngredient,
      ingredientForms: ingredientForms,
      textures: textures,
      supportedCookingMethods: supportedCookingMethods,
      metadata: const IngredientMetadata(
        schemaVersion: 1,
        revision: 1,
        source: 'pantry_catalog_coverage_v1',
      ),
    );
  }
}

const List<_DefinitionSeed> _seeds = <_DefinitionSeed>[
  _DefinitionSeed(
    'quail_egg',
    'Quail Egg',
    'ไข่นกกระทา',
    'protein',
    '🥚',
    aliases: <String>['quail egg', 'quail eggs'],
    profile: _UnitProfile.egg,
    unitFamily: IngredientUnitFamily.egg,
  ),
  _DefinitionSeed(
    'century_egg',
    'Century Egg',
    'ไข่เยี่ยวม้า',
    'protein',
    '🥚',
    aliases: <String>['century egg', 'preserved egg'],
    profile: _UnitProfile.egg,
    unitFamily: IngredientUnitFamily.egg,
  ),
  _DefinitionSeed(
    'lemon_basil',
    'Lemon Basil',
    'ใบแมงลัก',
    'herb',
    '🌿',
    aliases: <String>['แมงลัก', 'lemon basil'],
    unitFamily: IngredientUnitFamily.vegetable,
  ),
  _DefinitionSeed(
    'coriander',
    'Coriander',
    'ผักชี',
    'herb',
    '🌿',
    aliases: <String>['coriander', 'cilantro'],
    unitFamily: IngredientUnitFamily.vegetable,
  ),
  _DefinitionSeed(
    'shallot',
    'Shallot',
    'หอมแดง',
    'herb',
    '🧅',
    aliases: <String>['shallot', 'shallots'],
    unitFamily: IngredientUnitFamily.vegetable,
  ),
  _DefinitionSeed(
    'dried_chili',
    'Dried Chili',
    'พริกแห้ง',
    'herb',
    '🌶️',
    aliases: <String>['dried chili', 'dried chillies'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'palm_sugar',
    'Palm Sugar',
    'น้ำตาลปี๊บ',
    'seasoning',
    '🧂',
    aliases: <String>['palm sugar', 'coconut sugar'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'seasoning_powder',
    'Seasoning Powder',
    'ผงปรุงรส',
    'seasoning',
    '🧂',
    aliases: <String>['seasoning powder'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'vinegar',
    'Vinegar',
    'น้ำส้มสายชู',
    'seasoning',
    '🫙',
    aliases: <String>['vinegar'],
    profile: _UnitProfile.volume,
    pantryStable: true,
  ),
  _DefinitionSeed(
    'fermented_soybean_paste',
    'Fermented Soybean Paste',
    'เต้าเจี้ยว',
    'seasoning',
    '🫙',
    aliases: <String>['soybean paste', 'fermented soybean paste'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'shrimp_paste',
    'Shrimp Paste',
    'กะปิ',
    'seasoning',
    '🫙',
    aliases: <String>['shrimp paste'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'ketchup',
    'Ketchup',
    'ซอสมะเขือเทศ',
    'seasoning',
    '🍅',
    aliases: <String>['ketchup', 'tomato sauce'],
    profile: _UnitProfile.volume,
    pantryStable: true,
  ),
  _DefinitionSeed(
    'mayonnaise',
    'Mayonnaise',
    'มายองเนส',
    'seasoning',
    '🥫',
    aliases: <String>['mayonnaise', 'mayo'],
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'rice_bran_oil',
    'Rice Bran Oil',
    'น้ำมันรำข้าว',
    'seasoning',
    '🫗',
    aliases: <String>['rice bran oil'],
    profile: _UnitProfile.volume,
    pantryStable: true,
  ),
  _DefinitionSeed(
    'olive_oil',
    'Olive Oil',
    'น้ำมันมะกอก',
    'seasoning',
    '🫒',
    aliases: <String>['olive oil'],
    profile: _UnitProfile.volume,
    pantryStable: true,
  ),
  _DefinitionSeed(
    'sesame_oil',
    'Sesame Oil',
    'น้ำมันงา',
    'seasoning',
    '🫗',
    aliases: <String>['sesame oil'],
    profile: _UnitProfile.volume,
    pantryStable: true,
  ),
  _DefinitionSeed(
    'butter',
    'Butter',
    'เนยสด',
    'seasoning',
    '🧈',
    aliases: <String>['เนย', 'butter'],
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'margarine',
    'Margarine',
    'มาการีน',
    'seasoning',
    '🧈',
    aliases: <String>['margarine'],
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'raw_rice',
    'Uncooked Rice',
    'ข้าวสาร',
    'staple',
    '🍚',
    aliases: <String>['uncooked rice', 'raw rice'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'sticky_rice',
    'Sticky Rice',
    'ข้าวเหนียว',
    'staple',
    '🍚',
    aliases: <String>['sticky rice', 'glutinous rice'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'rice_noodle',
    'Rice Noodle',
    'เส้นก๋วยเตี๋ยว',
    'staple',
    '🍜',
    aliases: <String>['rice noodle', 'rice noodles'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'rice_vermicelli',
    'Rice Vermicelli',
    'เส้นหมี่',
    'staple',
    '🍜',
    aliases: <String>['rice vermicelli'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'instant_noodle',
    'Instant Noodle',
    'บะหมี่กึ่งสำเร็จรูป',
    'staple',
    '🍜',
    aliases: <String>['มาม่า', 'instant noodle', 'instant noodles'],
    profile: _UnitProfile.count,
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'pasta',
    'Pasta',
    'พาสต้า',
    'staple',
    '🍝',
    aliases: <String>['pasta'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'bread',
    'Bread',
    'ขนมปัง',
    'staple',
    '🍞',
    aliases: <String>['bread'],
    profile: _UnitProfile.count,
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'crispy_flour',
    'Crispy Flour',
    'แป้งทอดกรอบ',
    'staple',
    '🌾',
    aliases: <String>['crispy flour', 'frying flour'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'rice_flour',
    'Rice Flour',
    'แป้งข้าวเจ้า',
    'staple',
    '🌾',
    aliases: <String>['rice flour'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'tapioca_starch',
    'Tapioca Starch',
    'แป้งมัน',
    'staple',
    '🌾',
    aliases: <String>['tapioca starch', 'tapioca flour'],
    pantryStable: true,
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'milk',
    'Milk',
    'นมสด',
    'protein',
    '🥛',
    aliases: <String>['milk', 'fresh milk'],
    profile: _UnitProfile.volume,
  ),
  _DefinitionSeed(
    'evaporated_milk',
    'Evaporated Milk',
    'นมข้นจืด',
    'protein',
    '🥛',
    aliases: <String>['evaporated milk'],
    profile: _UnitProfile.volume,
  ),
  _DefinitionSeed(
    'condensed_milk',
    'Condensed Milk',
    'นมข้นหวาน',
    'protein',
    '🥛',
    aliases: <String>['condensed milk', 'sweetened condensed milk'],
    profile: _UnitProfile.volume,
  ),
  _DefinitionSeed(
    'cheese',
    'Cheese',
    'ชีส',
    'protein',
    '🧀',
    aliases: <String>['cheese'],
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'yogurt',
    'Yogurt',
    'โยเกิร์ต',
    'protein',
    '🥣',
    aliases: <String>['yogurt', 'yoghurt'],
    unitFamily: IngredientUnitFamily.dryIngredient,
  ),
  _DefinitionSeed(
    'cream',
    'Cream',
    'ครีม',
    'protein',
    '🥛',
    aliases: <String>['cream', 'cooking cream'],
    profile: _UnitProfile.volume,
  ),
];

/// Read-only ids covered by the code-seeded fallback definitions above, for
/// authoring-source audits that must confirm no id is authored in both this
/// file and `assets/ingredients/thai_ingredients.json`. Exposed instead of
/// the private [_seeds] list itself, which stays an implementation detail.
List<String> fallbackDefinitionIds() {
  return List<String>.unmodifiable(_seeds.map((seed) => seed.id));
}
