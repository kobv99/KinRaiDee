import 'package:flutter/material.dart';

import '../../domain/models/food_category.dart';

class EmojiSelector extends StatefulWidget {
  final Function(String category, String name, String emoji) onSelected;

  const EmojiSelector({super.key, required this.onSelected});

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector> {
  FoodCategory? selectedCategory;

  FoodItem? selectedItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'ประเภทอาหาร',

          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 10,

          runSpacing: 10,

          children: foodCategories.map((category) {
            final selected = selectedCategory == category;

            return InkWell(
              borderRadius: BorderRadius.circular(12),

              onTap: () {
                setState(() {
                  selectedCategory = category;

                  selectedItem = null;
                });
              },

              child: Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: selected
                      ? Colors.orange.shade100
                      : Colors.grey.shade100,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(
                    color: selected ? Colors.orange : Colors.transparent,
                  ),
                ),

                child: Column(
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 30)),

                    Text(category.name),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        if (selectedCategory != null) ...[
          const SizedBox(height: 20),

          const Text(
            'เลือกวัตถุดิบ',

            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,

            runSpacing: 10,

            children: selectedCategory!.items.map((item) {
              final selected = selectedItem == item;

              return InkWell(
                borderRadius: BorderRadius.circular(20),

                onTap: () {
                  setState(() {
                    selectedItem = item;
                  });

                  widget.onSelected(
                    selectedCategory!.name,

                    item.name,

                    item.emoji,
                  );
                },

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,

                    vertical: 8,
                  ),

                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.orange.shade100
                        : Colors.grey.shade200,

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 20)),

                      const SizedBox(width: 5),

                      Text(item.name),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
