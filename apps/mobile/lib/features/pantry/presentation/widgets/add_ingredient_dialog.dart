import 'package:flutter/material.dart';

import '../../../../core/models/ingredient.dart';

import '../widgets/emoji_selector.dart';



class AddIngredientDialog extends StatefulWidget {


  const AddIngredientDialog({

    super.key,

  });



  @override
  State<AddIngredientDialog> createState() =>
      _AddIngredientDialogState();

}





class _AddIngredientDialogState
    extends State<AddIngredientDialog> {


  final quantityController =
      TextEditingController();



  String unit = 'ชิ้น';


  String category = '';


  String name = '';


  String emoji = '';



  DateTime? expiryDate;





  @override
  void dispose() {


    quantityController.dispose();


    super.dispose();

  }






  Future<void> pickExpiryDate() async {


    final date = await showDatePicker(


      context: context,


      initialDate:
          DateTime.now(),


      firstDate:
          DateTime.now(),


      lastDate:
          DateTime.now().add(

            const Duration(

              days: 365,

            ),

          ),


    );



    if (date != null) {


      setState(() {


        expiryDate = date;


      });


    }


  }







  @override
  Widget build(BuildContext context) {


    return AlertDialog(


      title: const Text(

        'เพิ่มวัตถุดิบ 🥬',

      ),






      content: SingleChildScrollView(


        child: Column(


          mainAxisSize:

              MainAxisSize.min,



          crossAxisAlignment:

              CrossAxisAlignment.start,



          children: [





            EmojiSelector(


              onSelected:
                  (

                    selectedCategory,

                    selectedName,

                    selectedEmoji,

                  ) {



                setState(() {



                  category =
                      selectedCategory;



                  name =
                      selectedName;



                  emoji =
                      selectedEmoji;



                });


              },

            ),






            const SizedBox(height: 20),






            if (name.isNotEmpty)


              Card(


                child: ListTile(


                  leading:

                      Text(


                    emoji,


                    style:

                        const TextStyle(

                      fontSize: 30,

                    ),


                  ),



                  title:

                      Text(

                    name,

                  ),



                  subtitle:

                      Text(

                    category,

                  ),



                ),


              ),






            TextField(



              controller:

                  quantityController,



              keyboardType:

                  const TextInputType.numberWithOptions(

                    decimal: true,

                  ),




              decoration:

                  const InputDecoration(


                labelText:

                    'จำนวน',


              ),


            ),








            DropdownButton<String>(



              value:

                  unit,




              items:

                  const [




                DropdownMenuItem(


                  value:

                      'ชิ้น',


                  child:

                      Text('ชิ้น'),


                ),




                DropdownMenuItem(


                  value:

                      'ฟอง',


                  child:

                      Text('ฟอง'),


                ),




                DropdownMenuItem(


                  value:

                      'กรัม',


                  child:

                      Text('กรัม'),


                ),




                DropdownMenuItem(


                  value:

                      'กิโลกรัม',


                  child:

                      Text('กิโลกรัม'),


                ),



              ],






              onChanged:

                  (value) {


                setState(() {


                  unit = value!;


                });


              },


            ),






            const SizedBox(height: 10),






            ListTile(


              contentPadding:

                  EdgeInsets.zero,



              leading:

                  const Icon(

                Icons.calendar_month,

              ),




              title:

                  Text(



                expiryDate == null


                    ? 'เลือกวันหมดอายุ'


                    : 'หมดอายุ ${expiryDate!.day}/'
                      '${expiryDate!.month}/'
                      '${expiryDate!.year}',



              ),




              onTap:

                  pickExpiryDate,



            ),



          ],


        ),


      ),








      actions: [






        TextButton(



          onPressed: () {



            Navigator.pop(context);



          },



          child:

              const Text(

            'ยกเลิก',

          ),



        ),








        ElevatedButton(





          onPressed: () {



            if (name.isEmpty) {


              ScaffoldMessenger.of(context)
                  .showSnackBar(



                const SnackBar(


                  content:

                      Text(

                    'กรุณาเลือกวัตถุดิบ',

                  ),



                ),



              );



              return;



            }







            final now =
                DateTime.now();






            final ingredient =
                Ingredient(




              id:

                  now

                      .millisecondsSinceEpoch

                      .toString(),






              name:

                  name,





              category:

                  category,






              emoji:

                  emoji,






              quantity:

                  double.tryParse(

                    quantityController.text,

                  ) ??

                  0,






              unit:

                  unit,






              expiryDate:

                  expiryDate,






              createdAt:

                  now,






              updatedAt:

                  now,



            );







            Navigator.pop(


              context,


              ingredient,


            );




          },





          child:

              const Text(

            'เพิ่ม',

          ),



        ),



      ],



    );

  }


}