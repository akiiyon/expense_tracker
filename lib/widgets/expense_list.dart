import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/model/expense_provider.dart';
import 'package:intl/intl.dart';

class ExpenseList extends StatelessWidget {
  

  @override
  Widget build(BuildContext context) {
    final providerHelp=Provider.of<ExpenseProvider>(context);
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: providerHelp.getLength(),
      itemBuilder: (BuildContext context,int index){
        
        return Container(
          margin: EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            
            leading: Icon(_getCategoryIcon(providerHelp.expenses[index].category)),
            title: Text(providerHelp.expenses[index].name),
            subtitle: Text(DateFormat.yMMMd().format(providerHelp.expenses[index].date)),
            trailing: Text("-₹${providerHelp.expenses[index].amount.toStringAsFixed(2)}",style: TextStyle(fontSize: 14),),
          ),
        );
      });
  }
}

IconData _getCategoryIcon(String category) {
  switch (category) {
    case "Rent":
      return Icons.home;
    case "Bill":
      return Icons.receipt_long;
    case "Food":
      return Icons.fastfood;
    case "Grocery":
      return Icons.shopping_cart;
    case "Entertainment":
      return Icons.movie;
    case "Other":
    default:
      return Icons.attach_money;
  }
}
