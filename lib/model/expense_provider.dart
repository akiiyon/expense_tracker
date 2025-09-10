import 'package:flutter/foundation.dart';
import 'expense.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Expense> _expenses = [
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
    Expense(name: 'outing', amount: 540, category: 'Food', date: DateTime(8-7-25)),
  ];

  List<Expense> get expenses => _expenses;

  final double  _startingBalance =10000;

  int getLength(){
    return _expenses.length;
  }
  void addExpense(Expense expense) {
    _expenses.add(expense);
    notifyListeners(); // tells UI to rebuild
  }

  void removeExpense(Expense expense) {
    _expenses.remove(expense);
    notifyListeners();
  }
  //***WHAT DOES THIS TOTAL AMOUNT DO???? */
  double get totalSpent =>
      _expenses.fold(0, (sum, e) => sum + e.amount);

  //get present balance as user inserts an expense
  double get walletBalance =>
      _startingBalance - totalSpent; // 💰 dynamic balance
}
