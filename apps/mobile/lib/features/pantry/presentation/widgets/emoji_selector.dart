import 'package:flutter/material.dart';

import '../../domain/models/food_category.dart';

class EmojiSelector extends StatefulWidget {
  const EmojiSelector({
    super.key,
    required this.onSelected,
    this.initialName,
  });

  final void Function(String category, String name, String emoji) onSelected;
  final String? initialName;

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector> {
  final TextEditingController _searchController = TextEditingController();

  FoodCategory? selectedCategory;
  FoodItem? selectedItem;
  String query = '';

  @override
  void initState() {
    super.initState();

    final initialName = widget.initialName?.trim();

    if (initialName == null || initialName.isEmpty) {
      return;
    }

    for (final category in foodCategories) {
      for (final item in category.items) {
        if (item.name == initialName) {
          selectedCategory = category;
          selectedItem = item;
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FoodCatalogItem> get _searchResults {
    if (query.trim().isEmpty) {
      return const <FoodCatalogItem>[];
    }

    return allFoodCatalogItems
        .where((entry) {
          return entry.item.matches(query) ||
              entry.category.toLowerCase().contains(query.trim().toLowerCase());
        })
        .take(12)
        .toList(growable: false);
  }

  void _selectCatalogItem(FoodCatalogItem entry) {
    final category = foodCategories.firstWhere(
      (candidate) => candidate.name == entry.category,
    );

    setState(() {
      selectedCategory = category;
      selectedItem = entry.item;
      query = '';
      _searchController.clear();
    });

    widget.onSelected(entry.category, entry.item.name, entry.item.emoji);
  }

  void _selectItem(FoodCategory category, FoodItem item) {
    setState(() {
      selectedCategory = category;
      selectedItem = item;
    });

    widget.onSelected(category.name, item.name, item.emoji);
  }

  @override
  Widget build(BuildContext context) {
    final results = _searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: true,
          onChanged: (value) {
            setState(() {
              query = value;
            });
          },
          decoration: InputDecoration(
            labelText: 'ค้นหาวัตถุดิบ',
            hintText: 'เช่น น้ำมัน น้ำปลา กะเพรา',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'ล้างคำค้นหา',
                    onPressed: () {
                      setState(() {
                        query = '';
                        _searchController.clear();
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        if (query.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          if (results.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ไม่พบ "$query" ในรายการวัตถุดิบ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1);
                  },
                  itemBuilder: (context, index) {
                    final entry = results[index];

                    return ListTile(
                      dense: true,
                      leading: Text(
                        entry.item.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(entry.item.name),
                      subtitle: Text(entry.category),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () {
                        _selectCatalogItem(entry);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const Text(
          'เลือกจากหมวดหมู่',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: foodCategories.map((category) {
            final selected = selectedCategory == category;

            return ChoiceChip(
              avatar: Text(category.emoji),
              label: Text(category.name),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedCategory = category;
                  selectedItem = null;
                });
              },
            );
          }).toList(growable: false),
        ),
        if (selectedCategory != null) ...[
          const SizedBox(height: 20),
          Text(
            'เลือกวัตถุดิบในหมวด ${selectedCategory!.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedCategory!.items.map((item) {
              final selected = selectedItem == item;

              return FilterChip(
                avatar: Text(item.emoji),
                label: Text(item.name),
                selected: selected,
                onSelected: (_) {
                  _selectItem(selectedCategory!, item);
                },
              );
            }).toList(growable: false),
          ),
        ],
      ],
    );
  }
}
