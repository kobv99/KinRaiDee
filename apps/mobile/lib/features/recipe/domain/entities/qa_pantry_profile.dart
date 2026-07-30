class QaPantryItem {
  const QaPantryItem({required this.canonicalIngredientId, this.expiresInDays});

  final String canonicalIngredientId;
  final int? expiresInDays;
}

class QaPantryProfile {
  const QaPantryProfile({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<QaPantryItem> items;
}

const qaPantryProfiles = <QaPantryProfile>[
  QaPantryProfile(
    id: 'perfect_match',
    name: 'Perfect Match',
    items: <QaPantryItem>[
      QaPantryItem(canonicalIngredientId: 'pork'),
      QaPantryItem(canonicalIngredientId: 'holy_basil'),
      QaPantryItem(canonicalIngredientId: 'garlic'),
      QaPantryItem(canonicalIngredientId: 'chili'),
      QaPantryItem(canonicalIngredientId: 'fish_sauce'),
    ],
  ),
  QaPantryProfile(
    id: 'almost_ready',
    name: 'Almost Ready',
    items: <QaPantryItem>[
      QaPantryItem(canonicalIngredientId: 'pork'),
      QaPantryItem(canonicalIngredientId: 'garlic'),
      QaPantryItem(canonicalIngredientId: 'chili'),
    ],
  ),
  QaPantryProfile(id: 'empty', name: 'Empty Pantry', items: <QaPantryItem>[]),
  QaPantryProfile(
    id: 'expiring',
    name: 'Expiring Ingredients',
    items: <QaPantryItem>[
      QaPantryItem(canonicalIngredientId: 'chicken_breast', expiresInDays: 1),
      QaPantryItem(canonicalIngredientId: 'tomato', expiresInDays: 2),
    ],
  ),
  QaPantryProfile(
    id: 'vegetarian',
    name: 'Vegetarian',
    items: <QaPantryItem>[
      QaPantryItem(canonicalIngredientId: 'tofu'),
      QaPantryItem(canonicalIngredientId: 'egg'),
      QaPantryItem(canonicalIngredientId: 'tomato'),
      QaPantryItem(canonicalIngredientId: 'onion'),
    ],
  ),
  QaPantryProfile(
    id: 'substitution',
    name: 'Substitution Test',
    items: <QaPantryItem>[
      QaPantryItem(canonicalIngredientId: 'chicken_thigh'),
      QaPantryItem(canonicalIngredientId: 'garlic'),
    ],
  ),
];
