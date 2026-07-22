import 'package:hive_flutter/hive_flutter.dart';

import '../models/ingredient.dart';


class StorageService {

  static const String pantryBox = 'pantry_box';



  static Future<void> init() async {

    await Hive.initFlutter();

    await Hive.openBox(pantryBox);

  }



  static Box get _box {

    return Hive.box(pantryBox);

  }



  static Future<void> saveIngredients(
    List<Ingredient> ingredients,
  ) async {


    final data = ingredients.map(

      (item) {

        return {

          'id': item.id,

          'name': item.name,

          'category': item.category,

          'emoji': item.emoji,

          'quantity': item.quantity,

          'unit': item.unit,


          'expiryDate':
              item.expiryDate
                  ?.toIso8601String(),


          'createdAt':
              item.createdAt
                  .toIso8601String(),


          'updatedAt':
              item.updatedAt
                  .toIso8601String(),

        };

      },

    ).toList();



    await _box.put(

      'ingredients',

      data,

    );

  }







  static List<Ingredient> loadIngredients() {


    final data = _box.get(

      'ingredients',

      defaultValue: [],

    );



    return (data as List)

        .map(

          (item) {


            return Ingredient(


              id:
                  item['id'] ?? '',



              name:
                  item['name'] ?? '',



              category:
                  item['category'] ?? 'Other',



              emoji:
                  item['emoji'] ?? '🍽️',



              quantity:
                  (item['quantity'] ?? 0)
                      .toDouble(),



              unit:
                  item['unit'] ?? 'ชิ้น',





              expiryDate:

                  item['expiryDate'] != null

                      ? DateTime.parse(
                          item['expiryDate'],
                        )

                      : null,





              createdAt:

                  item['createdAt'] != null

                      ? DateTime.parse(
                          item['createdAt'],
                        )

                      : DateTime.now(),





              updatedAt:

                  item['updatedAt'] != null

                      ? DateTime.parse(
                          item['updatedAt'],
                        )

                      :

                  // รองรับข้อมูลเก่าที่ไม่มี updatedAt

                  (item['createdAt'] != null

                      ? DateTime.parse(
                          item['createdAt'],
                        )

                      : DateTime.now()),



            );


          },

        )

        .toList();


  }



}