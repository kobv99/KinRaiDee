import 'package:flutter/material.dart';

class RecipePage extends StatelessWidget {
  const RecipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe AI 🍳')),
      body: const Center(
        child: Text('AI Recipe Assistant', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
