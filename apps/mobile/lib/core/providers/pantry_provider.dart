import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient.dart';
import '../services/storage_service.dart';



class PantryNotifier extends Notifier<List<Ingredient>> {


  @override
  List<Ingredient> build() {

    return StorageService.loadIngredients();

  }



  void addIngredient(
    Ingredient ingredient,
  ) {


    state = [

      ...state,

      ingredient,

    ];


    StorageService.saveIngredients(
      state,
    );


  }



  void removeIngredient(
    String id,
  ) {


    state = state
        .where(
          (item) => item.id != id,
        )
        .toList();



    StorageService.saveIngredients(
      state,
    );


  }



  void clear() {


    state = [];


    StorageService.saveIngredients(
      state,
    );


  }


}



final pantryProvider =
    NotifierProvider<PantryNotifier, List<Ingredient>>(
  PantryNotifier.new,
);