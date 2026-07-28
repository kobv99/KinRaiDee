enum ShoppingCategory {
  produce,
  protein,
  seafood,
  dairyAndEggs,
  grains,
  seasonings,
  beverages,
  frozen,
  household,
  other;

  static ShoppingCategory fromCanonicalCategory(String value) {
    return switch (value.trim().toLowerCase()) {
      'vegetable' || 'fruit' || 'produce' => ShoppingCategory.produce,
      'protein' || 'meat' => ShoppingCategory.protein,
      'seafood' => ShoppingCategory.seafood,
      'dairy' || 'egg' || 'dairy_and_eggs' => ShoppingCategory.dairyAndEggs,
      'grain' || 'grains' || 'rice' || 'noodle' => ShoppingCategory.grains,
      'seasoning' ||
      'spice' ||
      'condiment' ||
      'sauce' => ShoppingCategory.seasonings,
      'beverage' || 'drink' => ShoppingCategory.beverages,
      'frozen' => ShoppingCategory.frozen,
      'household' => ShoppingCategory.household,
      _ => ShoppingCategory.other,
    };
  }
}
