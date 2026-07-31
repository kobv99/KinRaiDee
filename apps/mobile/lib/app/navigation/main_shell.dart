import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/pantry/presentation/pages/pantry_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/recipe/presentation/pages/recipe_hub_page.dart';
import '../../features/shopping/presentation/pages/shopping_page.dart';
import 'app_navigation_provider.dart';
import 'cooking_completion_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(appNavigationProvider, (previousIndex, nextIndex) {
      if (previousIndex == nextIndex) {
        return;
      }

      // A tab switch requested from a pushed route (e.g. "ไปที่ Shopping"
      // from the cooking wizard) must land on that tab's root, not leave
      // the previous tab's stack of pushed pages behind underneath it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }

        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      });
    });

    ref.listen(cookingCompletionProvider, (previous, transaction) {
      if (transaction == null) {
        return;
      }

      ref.read(cookingCompletionProvider.notifier).clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }

        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'ทำอาหารเสร็จแล้ว และหักวัตถุดิบ ${transaction.changedIngredientCount} รายการ · แก้ย้อนหลังได้ในประวัติการทำอาหาร',
            ),
            duration: const Duration(seconds: 4),
            showCloseIcon: true,
          ),
        );
      });
    });

    final currentIndex = ref.watch(appNavigationProvider);
    final navigation = ref.read(appNavigationProvider.notifier);
    final pages = <Widget>[
      HomePage(
        onOpenPantry: navigation.openPantry,
        onOpenRecipes: navigation.openRecipes,
      ),
      const PantryPage(),
      const RecipeHubPage(),
      const ShoppingPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: navigation.selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Recipe',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
