import 'package:flutter/material.dart';

class NoPriorityIngredients extends StatelessWidget {
  const NoPriorityIngredients({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('ยังไม่มีวัตถุดิบที่ใกล้หมดอายุภายใน 7 วัน'),
            ),
          ],
        ),
      ),
    );
  }
}
