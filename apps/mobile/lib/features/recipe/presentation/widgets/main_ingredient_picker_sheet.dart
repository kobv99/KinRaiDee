import 'package:flutter/material.dart';

/// The two product modes exposed by the main-ingredient picker.
enum MainIngredientSelectionMode { automatic, manual }

/// A persistence request emitted separately from the selection mode.
///
/// Pinning is an optional affordance for a manual selection, not a third
/// selection mode.
enum MainIngredientPinAction { none, pin, unpin }

/// Immutable, presentation-ready input for one selectable main ingredient.
///
/// The upstream catalog owns eligibility. It must create this view model only
/// for canonical ingredient value nodes that are supported by at least one
/// verified Recipe. Category/family nodes and unverified ingredients are not
/// valid picker inputs.
@immutable
class MainIngredientPickerOption {
  MainIngredientPickerOption({
    required this.canonicalId,
    required this.name,
    required this.emoji,
    required this.categoryLabel,
    required this.isInPantry,
    required this.supportedRecipeCount,
    List<String> searchTerms = const <String>[],
  }) : searchTerms = List<String>.unmodifiable(searchTerms),
       assert(canonicalId != ''),
       assert(name != ''),
       assert(supportedRecipeCount > 0);

  final String canonicalId;
  final String name;
  final String emoji;
  final String categoryLabel;
  final bool isInPantry;
  final int supportedRecipeCount;
  final List<String> searchTerms;
}

/// The user intent returned by [MainIngredientPickerSheet].
@immutable
class MainIngredientPickerResult {
  const MainIngredientPickerResult._({
    required this.mode,
    this.canonicalIngredientId,
    this.pinAction = MainIngredientPinAction.none,
  }) : assert(
         mode == MainIngredientSelectionMode.automatic
             ? canonicalIngredientId == null &&
                   pinAction == MainIngredientPinAction.none
             : canonicalIngredientId != null && canonicalIngredientId != '',
       );

  const MainIngredientPickerResult.automatic()
    : this._(mode: MainIngredientSelectionMode.automatic);

  const MainIngredientPickerResult.manual(
    String canonicalIngredientId, {
    MainIngredientPinAction pinAction = MainIngredientPinAction.none,
  }) : this._(
         mode: MainIngredientSelectionMode.manual,
         canonicalIngredientId: canonicalIngredientId,
         pinAction: pinAction,
       );

  final MainIngredientSelectionMode mode;
  final String? canonicalIngredientId;
  final MainIngredientPinAction pinAction;
}

/// Opens the reusable picker as a modal sheet and returns the user's intent.
Future<MainIngredientPickerResult?> showMainIngredientPickerSheet({
  required BuildContext context,
  required List<MainIngredientPickerOption> options,
  required MainIngredientSelectionMode initialMode,
  String? selectedIngredientId,
  List<String> recentIngredientIds = const <String>[],
  bool showPinAction = false,
  String? pinnedIngredientId,
}) {
  return showModalBottomSheet<MainIngredientPickerResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: MainIngredientPickerSheet(
          options: options,
          initialMode: initialMode,
          selectedIngredientId: selectedIngredientId,
          recentIngredientIds: recentIngredientIds,
          showPinAction: showPinAction,
          pinnedIngredientId: pinnedIngredientId,
          onResult: (result) => Navigator.of(sheetContext).pop(result),
        ),
      );
    },
  );
}

/// Searchable picker content that can also be embedded outside a modal route.
class MainIngredientPickerSheet extends StatefulWidget {
  const MainIngredientPickerSheet({
    required this.options,
    required this.initialMode,
    required this.onResult,
    this.selectedIngredientId,
    this.recentIngredientIds = const <String>[],
    this.showPinAction = false,
    this.pinnedIngredientId,
    super.key,
  });

  final List<MainIngredientPickerOption> options;
  final MainIngredientSelectionMode initialMode;
  final String? selectedIngredientId;
  final List<String> recentIngredientIds;
  final bool showPinAction;
  final String? pinnedIngredientId;
  final ValueChanged<MainIngredientPickerResult> onResult;

  @override
  State<MainIngredientPickerSheet> createState() =>
      _MainIngredientPickerSheetState();
}

class _MainIngredientPickerSheetState
    extends State<MainIngredientPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAutomatic =
        widget.initialMode == MainIngredientSelectionMode.automatic;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลือกวัตถุดิบหลัก',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'ให้ระบบช่วยเลือก หรือค้นหาวัตถุดิบที่สูตรรองรับได้เอง',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey<String>('main-ingredient-auto-option'),
            leading: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: const Icon(Icons.auto_awesome_outlined),
            ),
            title: const Text('ให้ระบบเลือกอัตโนมัติ'),
            subtitle: const Text(
              'ดูของในคลัง ความพร้อม และเมนูที่ทำได้',
            ),
            selected: isAutomatic,
            trailing: isAutomatic
                ? const Icon(
                    Icons.check_circle,
                    key: ValueKey<String>(
                      'main-ingredient-automatic-selected',
                    ),
                  )
                : null,
            onTap: () => widget.onResult(
              const MainIngredientPickerResult.automatic(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลือกวัตถุดิบเอง',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey<String>(
                    'main-ingredient-search-field',
                  ),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อวัตถุดิบ',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey<String>(
                              'main-ingredient-clear-search',
                            ),
                            tooltip: 'ล้างคำค้นหา',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(child: _buildOptions(context)),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    final optionsById = <String, MainIngredientPickerOption>{
      for (final option in widget.options) option.canonicalId: option,
    };
    final normalizedQuery = _normalize(_query);
    final recent = <MainIngredientPickerOption>[];
    final recentIds = <String>{};

    if (normalizedQuery.isEmpty) {
      for (final id in widget.recentIngredientIds) {
        final option = optionsById[id];
        if (option != null && recentIds.add(id)) {
          recent.add(option);
        }
      }
    }

    final scored = widget.options
        .where((option) => !recentIds.contains(option.canonicalId))
        .map(
          (option) => (
            option: option,
            score: _searchScore(option, normalizedQuery),
          ),
        )
        .where((entry) => normalizedQuery.isEmpty || entry.score > 0)
        .toList(growable: false);

    int compareEntries(
      ({MainIngredientPickerOption option, int score}) first,
      ({MainIngredientPickerOption option, int score}) second,
    ) {
      final scoreComparison = second.score.compareTo(first.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      final nameComparison = first.option.name.compareTo(second.option.name);
      if (nameComparison != 0) {
        return nameComparison;
      }
      return first.option.canonicalId.compareTo(second.option.canonicalId);
    }

    final pantry = scored.where((entry) => entry.option.isInPantry).toList()
      ..sort(compareEntries);
    final exploration = scored
        .where((entry) => !entry.option.isInPantry)
        .toList()
      ..sort(compareEntries);

    if (recent.isEmpty && pantry.isEmpty && exploration.isEmpty) {
      return _EmptyOptions(query: _query);
    }

    return ListView(
      key: const ValueKey<String>('main-ingredient-options-list'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (recent.isNotEmpty) ...[
          const _SectionHeader(
            key: ValueKey<String>('main-ingredient-recent-section'),
            icon: Icons.history,
            title: 'เลือกล่าสุด',
            subtitle: 'กลับไปเลือกวัตถุดิบที่เพิ่งใช้',
          ),
          ...recent.map(_buildOptionTile),
        ],
        if (pantry.isNotEmpty) ...[
          const _SectionHeader(
            key: ValueKey<String>('main-ingredient-pantry-section'),
            icon: Icons.kitchen_outlined,
            title: 'มีใน Pantry',
            subtitle: 'เรียงไว้ก่อนเพื่อเลือกของที่มีอยู่ได้เร็ว',
          ),
          ...pantry.map((entry) => _buildOptionTile(entry.option)),
        ],
        if (exploration.isNotEmpty) ...[
          const _SectionHeader(
            key: ValueKey<String>('main-ingredient-explore-section'),
            icon: Icons.explore_outlined,
            title: 'สำรวจเมนูอื่น',
            subtitle: 'ดูสูตรก่อนได้ แม้วัตถุดิบยังไม่มีใน Pantry',
          ),
          ...exploration.map((entry) => _buildOptionTile(entry.option)),
        ],
      ],
    );
  }

  Widget _buildOptionTile(MainIngredientPickerOption option) {
    final selected =
        widget.initialMode == MainIngredientSelectionMode.manual &&
        widget.selectedIngredientId == option.canonicalId;
    final pinned = widget.pinnedIngredientId == option.canonicalId;
    final status = option.isInPantry ? 'มีใน Pantry' : 'ยังไม่มีใน Pantry';
    final subtitle = <String>[
      if (selected) 'เลือกด้วยตนเองอยู่',
      status,
      'รองรับ ${option.supportedRecipeCount} เมนู',
      if (option.categoryLabel.trim().isNotEmpty) option.categoryLabel,
    ].join(' · ');

    return ListTile(
      key: ValueKey<String>(
        'main-ingredient-option-${option.canonicalId}',
      ),
      leading: CircleAvatar(child: Text(option.emoji)),
      title: Text(option.name),
      subtitle: Text(subtitle),
      selected: selected,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(
              Icons.check_circle_outline,
              key: ValueKey<String>('main-ingredient-manual-selected'),
            ),
          if (widget.showPinAction)
            IconButton(
              key: ValueKey<String>(
                'main-ingredient-pin-${option.canonicalId}',
              ),
              tooltip: pinned ? 'ยกเลิกปักหมุด' : 'ปักหมุดวัตถุดิบนี้',
              onPressed: () => widget.onResult(
                MainIngredientPickerResult.manual(
                  option.canonicalId,
                  pinAction: pinned
                      ? MainIngredientPinAction.unpin
                      : MainIngredientPinAction.pin,
                ),
              ),
              icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
            ),
        ],
      ),
      onTap: () => widget.onResult(
        MainIngredientPickerResult.manual(option.canonicalId),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOptions extends StatelessWidget {
  const _EmptyOptions({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasQuery ? Icons.search_off : Icons.restaurant_menu, size: 48),
            const SizedBox(height: 10),
            Text(
              hasQuery
                  ? 'ไม่พบวัตถุดิบที่สูตรรองรับ'
                  : 'ยังไม่มีวัตถุดิบหลักที่สูตรรองรับ',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (hasQuery) ...[
              const SizedBox(height: 6),
              const Text(
                'ลองค้นหาด้วยชื่ออื่นหรือคำใกล้เคียง',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _searchScore(
  MainIngredientPickerOption option,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) {
    return 1;
  }

  final name = _normalize(option.name);
  final terms = <String>{
    name,
    _normalize(option.canonicalId),
    _normalize(option.categoryLabel),
    ...option.searchTerms.map(_normalize),
  }..remove('');

  if (name == normalizedQuery) {
    return 1000;
  }
  if (terms.contains(normalizedQuery)) {
    return 900;
  }
  if (name.startsWith(normalizedQuery)) {
    return 800;
  }
  if (terms.any((term) => term.startsWith(normalizedQuery))) {
    return 700;
  }
  final nameIndex = name.indexOf(normalizedQuery);
  if (nameIndex >= 0) {
    return 600 - nameIndex;
  }
  for (final term in terms) {
    final index = term.indexOf(normalizedQuery);
    if (index >= 0) {
      return 500 - index;
    }
  }
  return 0;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_.\/]+'), '');
}
