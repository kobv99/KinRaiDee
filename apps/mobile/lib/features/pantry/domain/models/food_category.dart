class FoodCategory {
  const FoodCategory({
    required this.name,
    required this.emoji,
    required this.items,
  });

  final String name;
  final String emoji;
  final List<FoodItem> items;
}

class FoodItem {
  const FoodItem({
    required this.name,
    required this.emoji,
    this.aliases = const <String>[],
  });

  final String name;
  final String emoji;
  final List<String> aliases;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    if (name.toLowerCase().contains(normalizedQuery)) {
      return true;
    }

    return aliases.any(
      (alias) => alias.toLowerCase().contains(normalizedQuery),
    );
  }
}

class FoodCatalogItem {
  const FoodCatalogItem({
    required this.category,
    required this.categoryEmoji,
    required this.item,
  });

  final String category;
  final String categoryEmoji;
  final FoodItem item;
}

const foodCategories = <FoodCategory>[
  FoodCategory(
    name: 'เนื้อสัตว์',
    emoji: '🥩',
    items: <FoodItem>[
      FoodItem(name: 'หมูสับ', emoji: '🐷', aliases: ['หมูบด']),
      FoodItem(name: 'หมูสามชั้น', emoji: '🐷'),
      FoodItem(name: 'สันคอหมู', emoji: '🐷'),
      FoodItem(name: 'เนื้อหมู', emoji: '🐷', aliases: ['หมู']),
      FoodItem(name: 'เนื้อวัว', emoji: '🥩', aliases: ['เนื้อ']),
      FoodItem(name: 'เนื้อไก่', emoji: '🐔', aliases: ['ไก่']),
      FoodItem(name: 'อกไก่', emoji: '🐔'),
      FoodItem(name: 'น่องไก่', emoji: '🍗'),
      FoodItem(name: 'ปีกไก่', emoji: '🍗'),
      FoodItem(name: 'เป็ด', emoji: '🦆'),
      FoodItem(name: 'กุ้ง', emoji: '🦐'),
      FoodItem(name: 'ปลาหมึก', emoji: '🦑'),
      FoodItem(name: 'ปลาทับทิม', emoji: '🐟'),
      FoodItem(name: 'ปลากะพง', emoji: '🐟'),
      FoodItem(name: 'ปลาทู', emoji: '🐟'),
      FoodItem(name: 'ปลาแซลมอน', emoji: '🐟', aliases: ['แซลมอน']),
      FoodItem(name: 'ปู', emoji: '🦀'),
      FoodItem(name: 'หอย', emoji: '🦪'),
    ],
  ),
  FoodCategory(
    name: 'ไข่',
    emoji: '🥚',
    items: <FoodItem>[
      FoodItem(name: 'ไข่ไก่', emoji: '🥚', aliases: ['ไข่']),
      FoodItem(name: 'ไข่เป็ด', emoji: '🥚'),
      FoodItem(name: 'ไข่นกกระทา', emoji: '🥚'),
      FoodItem(name: 'ไข่เค็ม', emoji: '🥚'),
      FoodItem(name: 'ไข่เยี่ยวม้า', emoji: '🥚'),
    ],
  ),
  FoodCategory(
    name: 'ผักและสมุนไพร',
    emoji: '🥬',
    items: <FoodItem>[
      FoodItem(name: 'ใบกะเพรา', emoji: '🌿', aliases: ['กะเพรา', 'กระเพรา']),
      FoodItem(name: 'โหระพา', emoji: '🌿'),
      FoodItem(name: 'ใบแมงลัก', emoji: '🌿', aliases: ['แมงลัก']),
      FoodItem(name: 'ผักชี', emoji: '🌿'),
      FoodItem(name: 'ต้นหอม', emoji: '🌱'),
      FoodItem(name: 'ขึ้นฉ่าย', emoji: '🌿'),
      FoodItem(name: 'คะน้า', emoji: '🥬'),
      FoodItem(name: 'ผักบุ้ง', emoji: '🥬'),
      FoodItem(name: 'ผักกาดขาว', emoji: '🥬', aliases: ['ผักกาด']),
      FoodItem(name: 'กะหล่ำปลี', emoji: '🥬'),
      FoodItem(name: 'บรอกโคลี', emoji: '🥦'),
      FoodItem(name: 'แครอท', emoji: '🥕'),
      FoodItem(name: 'มะเขือเทศ', emoji: '🍅'),
      FoodItem(name: 'แตงกวา', emoji: '🥒'),
      FoodItem(name: 'ถั่วฝักยาว', emoji: '🫛'),
      FoodItem(name: 'ข้าวโพดอ่อน', emoji: '🌽'),
      FoodItem(name: 'เห็ดฟาง', emoji: '🍄'),
      FoodItem(name: 'เห็ดนางฟ้า', emoji: '🍄'),
      FoodItem(name: 'เห็ดเข็มทอง', emoji: '🍄'),
      FoodItem(name: 'พริก', emoji: '🌶️', aliases: ['พริกสด']),
      FoodItem(name: 'พริกแห้ง', emoji: '🌶️'),
      FoodItem(name: 'กระเทียม', emoji: '🧄'),
      FoodItem(name: 'หอมแดง', emoji: '🧅'),
      FoodItem(name: 'หอมหัวใหญ่', emoji: '🧅'),
      FoodItem(name: 'ขิง', emoji: '🫚'),
      FoodItem(name: 'ข่า', emoji: '🫚'),
      FoodItem(name: 'ตะไคร้', emoji: '🌿'),
      FoodItem(name: 'ใบมะกรูด', emoji: '🌿'),
      FoodItem(name: 'มะนาว', emoji: '🍋'),
      FoodItem(name: 'มะขามเปียก', emoji: '🫘'),
    ],
  ),
  FoodCategory(
    name: 'เครื่องปรุง',
    emoji: '🧂',
    items: <FoodItem>[
      FoodItem(name: 'น้ำปลา', emoji: '🫙'),
      FoodItem(name: 'ซีอิ๊วขาว', emoji: '🫙', aliases: ['ซีอิ๊ว', 'โชยุ']),
      FoodItem(name: 'ซีอิ๊วดำ', emoji: '🫙'),
      FoodItem(name: 'ซอสปรุงรส', emoji: '🫙'),
      FoodItem(name: 'ซอสหอยนางรม', emoji: '🦪', aliases: ['น้ำมันหอย']),
      FoodItem(name: 'น้ำตาลทราย', emoji: '🧂', aliases: ['น้ำตาล']),
      FoodItem(name: 'น้ำตาลปี๊บ', emoji: '🧂'),
      FoodItem(name: 'เกลือ', emoji: '🧂'),
      FoodItem(name: 'พริกไทย', emoji: '🧂'),
      FoodItem(name: 'ผงปรุงรส', emoji: '🧂'),
      FoodItem(name: 'น้ำส้มสายชู', emoji: '🫙'),
      FoodItem(name: 'เต้าเจี้ยว', emoji: '🫙'),
      FoodItem(name: 'กะปิ', emoji: '🫙'),
      FoodItem(name: 'น้ำพริกเผา', emoji: '🌶️'),
      FoodItem(name: 'ซอสมะเขือเทศ', emoji: '🍅'),
      FoodItem(name: 'มายองเนส', emoji: '🥫'),
    ],
  ),
  FoodCategory(
    name: 'น้ำมันและไขมัน',
    emoji: '🫗',
    items: <FoodItem>[
      FoodItem(name: 'น้ำมันพืช', emoji: '🫗', aliases: ['น้ำมัน']),
      FoodItem(name: 'น้ำมันรำข้าว', emoji: '🫗'),
      FoodItem(name: 'น้ำมันมะกอก', emoji: '🫒'),
      FoodItem(name: 'น้ำมันงา', emoji: '🫗'),
      FoodItem(name: 'เนยสด', emoji: '🧈', aliases: ['เนย']),
      FoodItem(name: 'มาการีน', emoji: '🧈'),
    ],
  ),
  FoodCategory(
    name: 'ข้าว เส้น และแป้ง',
    emoji: '🍚',
    items: <FoodItem>[
      FoodItem(name: 'ข้าวสาร', emoji: '🍚', aliases: ['ข้าว']),
      FoodItem(name: 'ข้าวเหนียว', emoji: '🍚'),
      FoodItem(name: 'เส้นก๋วยเตี๋ยว', emoji: '🍜'),
      FoodItem(name: 'เส้นหมี่', emoji: '🍜'),
      FoodItem(name: 'วุ้นเส้น', emoji: '🍜'),
      FoodItem(name: 'บะหมี่กึ่งสำเร็จรูป', emoji: '🍜', aliases: ['มาม่า']),
      FoodItem(name: 'พาสต้า', emoji: '🍝'),
      FoodItem(name: 'ขนมปัง', emoji: '🍞'),
      FoodItem(name: 'แป้งสาลี', emoji: '🌾'),
      FoodItem(name: 'แป้งทอดกรอบ', emoji: '🌾'),
      FoodItem(name: 'แป้งข้าวเจ้า', emoji: '🌾'),
      FoodItem(name: 'แป้งมัน', emoji: '🌾'),
    ],
  ),
  FoodCategory(
    name: 'นมและกะทิ',
    emoji: '🥛',
    items: <FoodItem>[
      FoodItem(name: 'นมสด', emoji: '🥛'),
      FoodItem(name: 'นมข้นจืด', emoji: '🥛'),
      FoodItem(name: 'นมข้นหวาน', emoji: '🥛'),
      FoodItem(name: 'ชีส', emoji: '🧀'),
      FoodItem(name: 'โยเกิร์ต', emoji: '🥣'),
      FoodItem(name: 'กะทิ', emoji: '🥥'),
      FoodItem(name: 'ครีม', emoji: '🥛'),
    ],
  ),
  FoodCategory(
    name: 'อาหารแปรรูป',
    emoji: '🥫',
    items: <FoodItem>[
      FoodItem(name: 'เต้าหู้', emoji: '◻️'),
      FoodItem(name: 'ลูกชิ้น', emoji: '🍢'),
      FoodItem(name: 'ไส้กรอก', emoji: '🌭'),
      FoodItem(name: 'แฮม', emoji: '🥓'),
      FoodItem(name: 'เบคอน', emoji: '🥓'),
      FoodItem(name: 'หมูยอ', emoji: '🍥'),
      FoodItem(name: 'ปูอัด', emoji: '🍥'),
      FoodItem(name: 'ปลากระป๋อง', emoji: '🥫'),
      FoodItem(name: 'ทูน่ากระป๋อง', emoji: '🥫'),
      FoodItem(name: 'สาหร่าย', emoji: '🌿'),
    ],
  ),
];

List<FoodCatalogItem> get allFoodCatalogItems {
  return foodCategories
      .expand(
        (category) => category.items.map(
          (item) => FoodCatalogItem(
            category: category.name,
            categoryEmoji: category.emoji,
            item: item,
          ),
        ),
      )
      .toList(growable: false);
}
