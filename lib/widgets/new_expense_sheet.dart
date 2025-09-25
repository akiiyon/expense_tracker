import 'dart:collection';

import 'package:expense_tracker/model/expense.dart';
import 'package:expense_tracker/model/expense_provider.dart';
import 'package:expense_tracker/utils/api_service.dart';
import 'package:expense_tracker/widgets/category_list.dart';
import 'package:expense_tracker/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:expense_tracker/model/user_provider.dart';

class NewExpenseSheet extends StatefulWidget {
  const NewExpenseSheet({super.key});

  @override
  State<NewExpenseSheet> createState() => _NewExpenseSheetState();
}

class _NewExpenseSheetState extends State<NewExpenseSheet> {
  final api = ApiService();

  //* CONTROLLERS FOR INPUT *//
  final expenseNameContoller = TextEditingController();
  final expenseamountContoller = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String selectedCategory = "";

  //adding expense to backend
  Future<void> handleNewExpense(double amount) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final response = await api.addExpense(
      userProvider.userId!,
      amount,
      selectedCategory,
      _selectedDate,
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense saved to backend ✅")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${response.body}")));
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    expenseNameContoller.dispose();
    expenseamountContoller.dispose();
    super.dispose();
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),
            ),
            CupertinoButton(
              child: Text("Done"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MainTextWidget(inputText: "New expense", x: 16),
            SizedBox(height: 10),
            //********EXPENSE NAME********/
            TextFormField(
              controller: expenseNameContoller,
              decoration: InputDecoration(
                labelText: "Expense",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            //********EXPENSE AMOUNT********/
            TextFormField(
              controller: expenseamountContoller,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // allow only digits
              ],
              decoration: InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            ////****CHOSSING CATEGORY*** */////
            CategoryList(
              onCategorySelected: (category) {
                setState(() {
                  selectedCategory = category; // ✅ store selected category
                });
              },
            ),

            SizedBox(height: 20),

            //////****** DATE N TIME ********//////
            GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Date"),
                    Text(
                      "${_selectedDate.month}-${_selectedDate.day}-${_selectedDate.year}",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),

            /////****ADD NEW EXPENSE BUTTON****/////
            Center(
              child: CupertinoButton(
                child: Text("Add"),
                onPressed: () {
                  //add new expense to list
                  final name = expenseNameContoller.text.trim();
                  final amountText = expenseamountContoller.text.trim();

                  if (name.isEmpty || amountText.isEmpty) {
                    // show error (optional)
                    ScaffoldMessenger.of(
                      Navigator.of(context, rootNavigator: true).context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter name and amount"),
                      ),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountText);
                  if (amount == null) {
                    ScaffoldMessenger.of(
                      Navigator.of(context, rootNavigator: true).context,
                    ).showSnackBar(
                      const SnackBar(content: Text("Invalid amount")),
                    );
                    return;
                  }
                  // call backend
                  handleNewExpense(amount);

                  // create new Expense object
                  final newExpense = Expense(
                    name: name,
                    amount: amount,
                    category: selectedCategory ?? "Other",
                    date: _selectedDate,
                  );

                  // add to provider
                  Provider.of<ExpenseProvider>(
                    context,
                    listen: false,
                  ).addExpense(newExpense);

                  print("Expense Added: $name - ₹$amount");
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
