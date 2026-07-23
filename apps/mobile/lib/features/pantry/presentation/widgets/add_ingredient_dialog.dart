import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/ingredient.dart';
import '../widgets/emoji_selector.dart';

class AddIngredientDialog extends StatefulWidget {
  const AddIngredientDialog({
    super.key,
    this.ingredient,
    this.initialSearchQuery,
  });

  final Ingredient? ingredient;
  final String? initialSearchQuery;

  @override
  State<AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<AddIngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController quantityController = TextEditingController();
  final FocusNode _quantityFocusNode = FocusNode();

  String unit = 'ชิ้น';
  String category = '';
  String name = '';
  String emoji = '';
  DateTime? expiryDate;
  bool _showIngredientError = false;

  @override
  void initState() {
    super.initState();

    final ingredient = widget.ingredient;

    if (ingredient != null) {
      quantityController.text = ingredient.quantity.toString();
      unit = ingredient.unit;
      category = ingredient.category;
      name = ingredient.name;
      emoji = ingredient.emoji;
      expiryDate = ingredient.expiryDate;
    }
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
    final ingredient = Ingredient(
      id: widget.ingredient?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      category: category,
      emoji: emoji,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      createdAt: widget.ingredient?.createdAt ?? now,
      updatedAt: now,
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
                  initialName: widget.ingredient?.name,
                  initialSearchQuery: widget.ingredient == null
                      ? widget.initialSearchQuery
                      : null,
                  onSelected: (selectedCategory, selectedName, selectedEmoji) {
                    setState(() {
                      category = selectedCategory;
                      name = selectedName;
                      emoji = selectedEmoji;
                      _showIngredientError = false;
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (name.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: Text(emoji, style: const TextStyle(fontSize: 30)),
                      title: Text(name),
                      subtitle: Text(category),
                      trailing: const Icon(Icons.check_circle_rounded),
                    ),
                  ),
                if (_showIngredientError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'กรุณาเลือกวัตถุดิบ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
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
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'หน่วย'),
                  items: const [
                    DropdownMenuItem(value: 'ชิ้น', child: Text('ชิ้น')),
                    DropdownMenuItem(value: 'ฟอง', child: Text('ฟอง')),
                    DropdownMenuItem(value: 'กรัม', child: Text('กรัม')),
                    DropdownMenuItem(value: 'กิโลกรัม', child: Text('กิโลกรัม')),
                    DropdownMenuItem(value: 'มิลลิลิตร', child: Text('มิลลิลิตร')),
                    DropdownMenuItem(value: 'ลิตร', child: Text('ลิตร')),
                    DropdownMenuItem(value: 'ช้อนชา', child: Text('ช้อนชา')),
                    DropdownMenuItem(value: 'ช้อนโต๊ะ', child: Text('ช้อนโต๊ะ')),
                    DropdownMenuItem(value: 'ขวด', child: Text('ขวด')),
                    DropdownMenuItem(value: 'ถุง', child: Text('ถุง')),
                    DropdownMenuItem(value: 'แพ็ก', child: Text('แพ็ก')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      unit = value;
                    });
                  },
                ),
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
          child: Text(widget.ingredient == null ? 'เพิ่มเข้า Pantry' : 'บันทึก'),
        ),
      ],
    );
  }
}
