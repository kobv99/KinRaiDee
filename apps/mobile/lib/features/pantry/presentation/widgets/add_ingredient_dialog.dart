import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/models/food_category.dart';
import '../widgets/emoji_selector.dart';

class AddIngredientDialog extends ConsumerStatefulWidget {
  const AddIngredientDialog({
    super.key,
    this.ingredient,
    this.initialSearchQuery,
    this.initialCatalogItem,
  });

  final Ingredient? ingredient;
  final String? initialSearchQuery;
  final FoodCatalogItem? initialCatalogItem;

  @override
  ConsumerState<AddIngredientDialog> createState() =>
      _AddIngredientDialogState();
}

class _AddIngredientDialogState extends ConsumerState<AddIngredientDialog> {
  static const String _otherUnitAction = '__other_unit__';
  static const String _legacyUnitValue = '__legacy_unit__';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController quantityController = TextEditingController();
  final FocusNode _quantityFocusNode = FocusNode();

  String unit = 'ชิ้น';
  String? _selectedUnitId;
  String? _canonicalIngredientId;
  List<String> _recommendedUnitIds = const <String>[];
  bool _showOtherUnitPicker = false;
  int _unitSelectorRevision = 0;
  String category = '';
  String name = '';
  String emoji = '';
  DateTime? expiryDate;
  bool _showIngredientError = false;

  @override
  void initState() {
    super.initState();

    final ingredient = widget.ingredient;
    final initialCatalogItem = widget.initialCatalogItem;

    if (ingredient != null) {
      quantityController.text = ingredient.quantity.toString();
      unit = ingredient.unit;
      category = ingredient.category;
      name = ingredient.name;
      emoji = ingredient.emoji;
      expiryDate = ingredient.expiryDate;
    } else if (initialCatalogItem != null) {
      category = initialCatalogItem.category;
      name = initialCatalogItem.item.name;
      emoji = initialCatalogItem.item.emoji;
    }

    _initializeUnitSelection();
  }

  void _initializeUnitSelection() {
    final ingredient = widget.ingredient;
    final canonical = _resolveCanonicalIngredient(
      preferredId: ingredient?.canonicalIngredientId,
    );
    _setRecommendations(canonical);

    if (ingredient == null) {
      _selectUnitId(_preferredUnitId(canonical));
      return;
    }

    final engine = ref.read(unitConversionEngineProvider);
    final savedUnitId =
        engine.resolveUnitId(ingredient.canonicalUnitId) ??
        engine.resolveUnitId(ingredient.unit);
    if (savedUnitId == null) {
      _selectedUnitId = null;
      _showOtherUnitPicker = ingredient.unit.trim().isNotEmpty;
      return;
    }

    _selectedUnitId = savedUnitId;
    _showOtherUnitPicker = !_recommendedUnitIds.contains(savedUnitId);
  }

  CanonicalIngredient? _resolveCanonicalIngredient({String? preferredId}) {
    final registry = ref.read(canonicalIngredientRegistryProvider);
    if (registry == null) {
      return null;
    }
    if (preferredId != null && preferredId.trim().isNotEmpty) {
      final preferred = registry.byId(preferredId);
      if (preferred != null) {
        return preferred;
      }
    }
    return registry.resolve(name).ingredient;
  }

  void _setRecommendations(CanonicalIngredient? canonical) {
    final engine = ref.read(unitConversionEngineProvider);
    final fallback = ref.read(ingredientUnitPolicyProvider).fallback;
    final configured =
        canonical?.recommendedUnitIds ?? fallback.recommendedUnitIds;
    final valid = configured
        .where((unitId) => engine.resolveUnit(unitId) != null)
        .toSet()
        .toList(growable: false);
    _recommendedUnitIds = valid.isEmpty
        ? fallback.recommendedUnitIds
        : List<String>.unmodifiable(valid);
    _canonicalIngredientId = canonical?.id;
  }

  String _preferredUnitId(CanonicalIngredient? canonical) {
    final fallback = ref.read(ingredientUnitPolicyProvider).fallback;
    final preferred = canonical?.preferredUnitId ?? fallback.preferredUnitId;
    return _recommendedUnitIds.contains(preferred)
        ? preferred
        : _recommendedUnitIds.first;
  }

  void _selectUnitId(String unitId, {bool showOther = false}) {
    final definition = ref
        .read(unitConversionEngineProvider)
        .resolveUnit(unitId);
    if (definition == null) {
      return;
    }
    _selectedUnitId = definition.id;
    unit = definition.displayName;
    _showOtherUnitPicker = showOther;
    _unitSelectorRevision++;
  }

  void _ingredientSelected(
    String selectedCategory,
    String selectedName,
    String selectedEmoji,
  ) {
    final previousCanonicalId = _canonicalIngredientId;
    final previousUnitId = _selectedUnitId;

    category = selectedCategory;
    name = selectedName;
    emoji = selectedEmoji;
    _showIngredientError = false;

    final canonical = _resolveCanonicalIngredient();
    _setRecommendations(canonical);
    final ingredientChanged =
        previousCanonicalId == null ||
        previousCanonicalId != _canonicalIngredientId;
    if (!ingredientChanged &&
        previousUnitId != null &&
        _recommendedUnitIds.contains(previousUnitId)) {
      _selectUnitId(previousUnitId);
      return;
    }
    if (previousCanonicalId != null &&
        previousUnitId != null &&
        _recommendedUnitIds.contains(previousUnitId)) {
      _selectUnitId(previousUnitId);
      return;
    }
    _selectUnitId(_preferredUnitId(canonical));
  }

  List<UnitDefinition> get _recommendedUnitDefinitions {
    final engine = ref.read(unitConversionEngineProvider);
    return _recommendedUnitIds
        .map(engine.resolveUnit)
        .whereType<UnitDefinition>()
        .toList(growable: false);
  }

  List<UnitDefinition> get _allUnitDefinitions {
    final definitions = List<UnitDefinition>.of(
      ref.read(unitConversionEngineProvider).definitions,
    )..sort((first, second) => first.displayName.compareTo(second.displayName));
    return definitions;
  }

  @override
  void dispose() {
    quantityController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  Future<void> pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() {
        expiryDate = date;
      });
    }
  }

  void _submit() {
    final hasIngredient = name.isNotEmpty;

    setState(() {
      _showIngredientError = !hasIngredient;
    });

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!hasIngredient) {
      return;
    }

    if (!formIsValid) {
      _quantityFocusNode.requestFocus();
      return;
    }

    final quantity = double.parse(quantityController.text.trim());
    final now = DateTime.now();
    final original = widget.ingredient;
    final sameLegacyIdentity = original != null && original.name == name;
    final submittedCanonicalIngredientId =
        _canonicalIngredientId ??
        (sameLegacyIdentity ? original.canonicalIngredientId : '');
    final submittedCanonicalUnitId =
        _selectedUnitId ??
        (sameLegacyIdentity && original.unit == unit
            ? original.canonicalUnitId
            : '');
    final ingredient = Ingredient(
      id: original?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      category: category,
      emoji: emoji,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
      canonicalIngredientId: submittedCanonicalIngredientId,
      canonicalUnitId: submittedCanonicalUnitId,
      canonicalMappingStatus: _canonicalIngredientId != null
          ? CanonicalMappingStatus.mapped
          : (sameLegacyIdentity
                ? original.canonicalMappingStatus
                : CanonicalMappingStatus.unmapped),
    );

    Navigator.pop(context, ingredient);
  }

  String? _validateQuantity(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'กรุณาใส่จำนวน';
    }

    final quantity = double.tryParse(text);

    if (quantity == null || quantity <= 0) {
      return 'จำนวนต้องมากกว่า 0';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingredient == null ? 'เพิ่มวัตถุดิบ 🥬' : 'แก้ไขวัตถุดิบ ✏️',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiSelector(
                  initialName:
                      widget.ingredient?.name ??
                      widget.initialCatalogItem?.item.name,
                  initialSearchQuery:
                      widget.ingredient == null &&
                          widget.initialCatalogItem == null
                      ? widget.initialSearchQuery
                      : null,
                  onSelected: (selectedCategory, selectedName, selectedEmoji) {
                    setState(() {
                      _ingredientSelected(
                        selectedCategory,
                        selectedName,
                        selectedEmoji,
                      );
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (name.isNotEmpty)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Text(
                        emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text(name),
                      subtitle: Text(category),
                      trailing: const Icon(Icons.check_circle_rounded),
                    ),
                  ),
                if (_showIngredientError) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'กรุณาเลือกวัตถุดิบ',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantityController,
                  focusNode: _quantityFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'),
                    ),
                  ],
                  validator: _validateQuantity,
                  decoration: const InputDecoration(
                    labelText: 'จำนวน',
                    hintText: 'ระบุจำนวน',
                  ),
                  onFieldSubmitted: (_) {
                    _submit();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'ingredient-primary-unit-$_unitSelectorRevision',
                  ),
                  initialValue: _showOtherUnitPicker
                      ? _otherUnitAction
                      : _selectedUnitId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'หน่วยที่แนะนำ'),
                  items: <DropdownMenuItem<String>>[
                    for (final definition in _recommendedUnitDefinitions)
                      DropdownMenuItem<String>(
                        value: definition.id,
                        child: Text(definition.displayName),
                      ),
                    const DropdownMenuItem<String>(
                      value: _otherUnitAction,
                      child: Text('Other unit…'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      if (value == _otherUnitAction) {
                        _showOtherUnitPicker = true;
                        _unitSelectorRevision++;
                      } else {
                        _selectUnitId(value);
                      }
                    });
                  },
                ),
                if (_showOtherUnitPicker) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'ingredient-other-unit-$_unitSelectorRevision',
                    ),
                    initialValue: _selectedUnitId ?? _legacyUnitValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Other unit…',
                      helperText:
                          'ใช้เมื่อหน่วยที่บันทึกไว้หรือกรณีพิเศษไม่อยู่ในรายการแนะนำ',
                    ),
                    items: <DropdownMenuItem<String>>[
                      if (_selectedUnitId == null && unit.trim().isNotEmpty)
                        DropdownMenuItem<String>(
                          value: _legacyUnitValue,
                          child: Text('$unit (หน่วยเดิม)'),
                        ),
                      for (final definition in _allUnitDefinitions)
                        DropdownMenuItem<String>(
                          value: definition.id,
                          child: Text(definition.displayName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _legacyUnitValue) {
                        return;
                      }
                      setState(() {
                        _selectUnitId(value, showOther: true);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(
                    expiryDate == null
                        ? 'เลือกวันหมดอายุ (ไม่บังคับ)'
                        : 'หมดอายุ ${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
                  ),
                  trailing: expiryDate == null
                      ? null
                      : IconButton(
                          tooltip: 'ล้างวันหมดอายุ',
                          onPressed: () {
                            setState(() {
                              expiryDate = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: pickExpiryDate,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            widget.ingredient == null ? 'เพิ่มเข้า Pantry' : 'บันทึก',
          ),
        ),
      ],
    );
  }
}
