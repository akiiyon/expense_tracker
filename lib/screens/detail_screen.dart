import 'package:expense_tracker/widgets/expense_list.dart';
import 'package:flutter/material.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        title: Text("Expense details",style: TextStyle(color: Colors.white),),
      ),
      body: SafeArea(child: Expanded(child: ExpenseList())),
    );
  }
}