import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/pantry_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/pantry/presentation/pages/pantry_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/recipe/presentation/pages/recipe_page.dart';
import '../../features/shopping/presentation/pages/shopping_page.dart';
import 'app_navigation_provider.dart';
import 'cooking_completion_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(appNavigationProvider, (previousIndex, nextIndex) {
      if (nextIndex != AppNavigationNotifier.pantryTab ||
          previousIndex == nextIndex) {
        return;
      }

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
              'ทำอาหารเสร็จแล้ว และหักวัตถุดิบ ${transaction.changedIngredientCount} รายการจาก Pantry',
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'ย้อนกลับ',
              onPressed: () async {
                final restored = await ref
                    .read(pantryProvider.notifier)
                    .undoQuantityTransaction(transaction);
                if (!context.mounted) {
                  return;
                }

                final resultMessenger = ScaffoldMessenger.of(context);
                resultMessenger.clearSnackBars();
                resultMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      restored > 0
                          ? 'คืนวัตถุดิบ $restored รายการกลับเข้า Pantry แล้ว'
                          : 'ย้อนกลับไม่ได้ เพราะปริมาณวัตถุดิบถูกแก้ไขหลังจากนั้น',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });
    });

    final currentIndex = ref.watch(appNavigationProvider);
    final navigation = ref.read(appNavigationProvider.notifier);
    final pages = <Widget>[
      HomePage(onOpenPantry: navigation.openPantry),
      const PantryPage(),
      const RecipePage(),
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