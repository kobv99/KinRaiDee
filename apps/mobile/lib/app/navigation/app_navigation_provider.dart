import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNavigationNotifier extends Notifier<int> {
  static const int homeTab = 0;
  static const int pantryTab = 1;
  static const int recipeTab = 2;
  static const int shoppingTab = 3;
  static const int profileTab = 4;

  @override
  int build() => homeTab;

  void selectTab(int index) {
    if (index < homeTab || index > profileTab || index == state) {
      return;
    }

    state = index;
  }

  void openPantry() => selectTab(pantryTab);

  void openRecipes() => selectTab(recipeTab);
}

final appNavigationProvider = NotifierProvider<AppNavigationNotifier, int>(
  AppNavigationNotifier.new,
);