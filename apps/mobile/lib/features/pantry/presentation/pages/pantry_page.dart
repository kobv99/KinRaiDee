import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../widgets/add_ingredient_dialog.dart';



class PantryPage extends ConsumerWidget {


  const PantryPage({

    super.key,

  });



  @override
  Widget build(

    BuildContext context,

    WidgetRef ref,

  ) {



    final ingredients =
        ref.watch(pantryProvider);




    return Scaffold(



      appBar: AppBar(


        title:

            const Text(

          'Pantry 🥬',

        ),


      ),





      body:



          ingredients.isEmpty



              ? const Center(


                  child: Text(

                    'ยังไม่มีวัตถุดิบ\nกด + เพื่อเพิ่ม',

                    textAlign:

                        TextAlign.center,

                  ),


                )





              : ListView.builder(



                  padding:

                      const EdgeInsets.all(12),




                  itemCount:

                      ingredients.length,





                  itemBuilder:

                      (context, index) {



                    final item =

                        ingredients[index];




                    return _IngredientCard(

                      item: item,

                      onDelete: () {



                        ref

                            .read(

                              pantryProvider

                                  .notifier,

                            )

                            .removeIngredient(

                              item.id,

                            );


                      },


                    );



                  },

                ),







      floatingActionButton:

          FloatingActionButton(



        onPressed: () async {



          final ingredient =

              await showDialog<Ingredient>(



            context: context,



            builder: (context) {



              return const

                  AddIngredientDialog();



            },


          );




          if (ingredient != null) {



            ref

                .read(

                  pantryProvider.notifier,

                )

                .addIngredient(

                  ingredient,

                );



          }


        },



        child:

            const Icon(

          Icons.add,

        ),



      ),


    );


  }


}







class _IngredientCard extends StatelessWidget {


  final Ingredient item;


  final VoidCallback onDelete;



  const _IngredientCard({

    required this.item,

    required this.onDelete,

  });





  @override
  Widget build(BuildContext context) {


    return Card(


      elevation: 2,


      margin:

          const EdgeInsets.only(

        bottom: 12,

      ),



      child: Padding(


        padding:

            const EdgeInsets.all(12),



        child: Row(



          children: [





            Container(


              width: 55,

              height: 55,



              decoration:

                  BoxDecoration(


                color:

                    Colors.orange.shade50,



                borderRadius:

                    BorderRadius.circular(15),



              ),




              child:

                  Center(


                    child: Text(


                      item.emoji,



                      style:

                          const TextStyle(

                        fontSize: 32,

                      ),



                    ),

                  ),


            ),





            const SizedBox(width: 15),





            Expanded(



              child: Column(



                crossAxisAlignment:

                    CrossAxisAlignment.start,



                children: [





                  Text(



                    item.name,



                    style:

                        const TextStyle(


                      fontSize: 18,


                      fontWeight:

                          FontWeight.bold,


                    ),



                  ),






                  const SizedBox(height: 4),





                  Text(


                    item.category,



                    style:

                        TextStyle(


                      color:

                          Colors.grey.shade600,


                    ),



                  ),






                  const SizedBox(height: 8),





                  Row(



                    children: [



                      const Icon(

                        Icons.inventory_2,

                        size: 18,

                      ),



                      const SizedBox(width: 5),





                      Text(

                        '${item.quantity} ${item.unit}',

                      ),



                    ],



                  ),






                  if (item.expiryDate != null)

                    Padding(



                      padding:

                          const EdgeInsets.only(

                        top: 6,

                      ),



                      child: Row(



                        children: [



                          const Icon(

                            Icons.calendar_month,

                            size: 16,

                          ),




                          const SizedBox(width: 5),




                          Text(



                            'หมดอายุ '
                            '${item.expiryDate!.day}/'
                            '${item.expiryDate!.month}/'
                            '${item.expiryDate!.year}',



                            style:

                                TextStyle(

                              fontSize: 12,

                              color:

                                  Colors.grey.shade700,

                            ),



                          ),



                        ],



                      ),



                    ),




                ],



              ),



            ),






            IconButton(



              icon:

                  const Icon(

                Icons.delete_outline,

              ),



              onPressed:

                  onDelete,



            ),



          ],



        ),



      ),



    );

  }


}