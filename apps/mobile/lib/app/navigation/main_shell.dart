import 'package:flutter/material.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/pantry/presentation/pages/pantry_page.dart';
import '../../features/recipe/presentation/pages/recipe_page.dart';
import '../../features/shopping/presentation/pages/shopping_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';


class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}


class _MainShellState extends State<MainShell> {

  int currentIndex = 0;

  final pages = const [
    HomePage(),
    PantryPage(),
    RecipePage(),
    ShoppingPage(),
    ProfilePage(),
  ];


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: pages[currentIndex],

      bottomNavigationBar: NavigationBar(

        selectedIndex: currentIndex,

        onDestinationSelected: (index){

          setState(() {
            currentIndex = index;
          });

        },

        destinations: const [

          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(Icons.inventory),
            label: 'Pantry',
          ),

          NavigationDestination(
            icon: Icon(Icons.restaurant),
            label: 'Recipe',
          ),

          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),

          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),

        ],
      ),
    );
  }
}