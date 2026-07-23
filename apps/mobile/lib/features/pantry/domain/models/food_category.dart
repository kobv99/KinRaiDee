class FoodCategory {
  final String name;

  final String emoji;

  final List<FoodItem> items;

  const FoodCategory({
    required this.name,

    required this.emoji,

    required this.items,
  });
}

class FoodItem {
  final String name;

  final String emoji;

  const FoodItem({required this.name, required this.emoji});
}

const foodCategories = [
  FoodCategory(
    name: 'เนื้อสัตว์',

    emoji: '🥩',

    items: [
      FoodItem(name: 'หมูสามชั้น', emoji: '🐷'),

      FoodItem(name: 'หมูบด', emoji: '🐷'),

      FoodItem(name: 'สันคอหมู', emoji: '🐷'),

      FoodItem(name: 'อกไก่', emoji: '🐔'),

      FoodItem(name: 'น่องไก่', emoji: '🐔'),

      FoodItem(name: 'ปลาทับทิม', emoji: '🐟'),

      FoodItem(name: 'กุ้ง', emoji: '🦐'),

      FoodItem(name: 'ปลาหมึก', emoji: '🦑'),
    ],
  ),

  FoodCategory(
    name: 'ไข่',

    emoji: '🥚',

    items: [
      FoodItem(name: 'ไข่ไก่', emoji: '🥚'),

      FoodItem(name: 'ไข่เป็ด', emoji: '🥚'),

      FoodItem(name: 'ไข่นกกระทา', emoji: '🥚'),
    ],
  ),

  FoodCategory(
    name: 'ผัก',

    emoji: '🥬',

    items: [
      FoodItem(name: 'คะน้า', emoji: '🥬'),

      FoodItem(name: 'ผักกาด', emoji: '🥬'),

      FoodItem(name: 'แครอท', emoji: '🥕'),
    ],
  ),

  FoodCategory(
    name: 'ข้าวและแป้ง',

    emoji: '🍚',

    items: [
      FoodItem(name: 'ข้าวสาร', emoji: '🍚'),

      FoodItem(name: 'เส้นก๋วยเตี๋ยว', emoji: '🍜'),

      FoodItem(name: 'ขนมปัง', emoji: '🍞'),
    ],
  ),

  FoodCategory(
    name: 'นม',

    emoji: '🥛',

    items: [
      FoodItem(name: 'นมสด', emoji: '🥛'),

      FoodItem(name: 'ชีส', emoji: '🧀'),

      FoodItem(name: 'โยเกิร์ต', emoji: '🥣'),
    ],
  ),
];
