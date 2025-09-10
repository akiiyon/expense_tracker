
import 'package:expense_tracker/utils/route.dart';
import 'package:expense_tracker/widgets/expense_list.dart';
import 'package:expense_tracker/widgets/new_expense_sheet.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/widgets/text_widget.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/model/expense_provider.dart';

class TransactionScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // open your NewExpenseSheet or navigate to AddExpenseScreen
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => NewExpenseSheet(), // your add expense widget
          );
        },
        icon: const Icon(Icons.add,color: Colors.black),
        label: const Text("Add Expense",style: TextStyle(color: Colors.black),),
        backgroundColor: Colors.amber.shade500,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
     
      body: SafeArea(
         
        child: Column(
      
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ListTile(
                title: MainTextWidget( inputText: 'Hi, Akshay', x: 20,),
                subtitle: SubTextWidget(inputText: 'Welcome Back!', x: 14,),
                trailing: Icon(Icons.notifications_active),
              ),
            ),
            SizedBox(height: 12,),
             // Wallet Balance (listens to provider)
            Consumer<ExpenseProvider>(
              builder: (context, expenseProvider, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal:8.0,vertical:16),
                  child: Card(
                    color: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.all(Radius.circular(16)),
                    ),
                    elevation: 6,
                    child: ListTile(
                      
                      title: Text('Wallet Balance', style: TextStyle(fontSize: 14,color: Colors.white),),
                      subtitle: Row(
                        children: [
                          const Text("₹",style: TextStyle(fontSize: 16,color: Colors.white),),
                          const SizedBox(width: 5,),
                          Text(
                                '${expenseProvider.walletBalance.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold,fontSize:36,color: Colors.white ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 16,),
            
            
            //recent-activity buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Recent",style: TextStyle(color: Colors.grey.shade700,fontSize: 16,fontWeight: FontWeight.bold),),
                  TextButton(
                    onPressed: (){
                      //show a page of all expenses in list format
                      Navigator.pushNamed(context, AppRoutes.details);
                    }, 
                    style: ButtonStyle(
                      
                    ),
                    child: Text(
                      "See details>",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            //expenses
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16),topRight: Radius.circular(16))
                ),
                
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ExpenseList(),
                )),
            ),
           
          ],
        ),
      ),
      
    );
  }
}

// Container(
//               margin: EdgeInsets.symmetric(horizontal: 46),
              
//               child: FloatingActionButton(
//                 onPressed: (){
//                   //add new expense function
//                   showModalBottomSheet(
//                     context: context,
//                     builder: (BuildContext bottomSheetcontext){
//                       return NewExpenseSheet();
//                     });
//                 },
//                 child: Text(
//                   "Add Expense",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold
//                     ),
//                 ),
//               ),    
//             ),