import 'package:expense_tracker/utils/api_service.dart';
import 'package:flutter/foundation.dart';
import 'expense.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Expense> _expenses = [];
  List<Map<String, dynamic>> _weeklyCategoryTotals = [];

  List<Expense> get expenses => _expenses;
  List<Map<String, dynamic>> get weeklyCategoryTotals => _weeklyCategoryTotals;

  int getLength() {
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

  Future<void> fetchWeeklyExpenses(int userId) async {
    try {
      final api = ApiService();
      _weeklyCategoryTotals = await api.getWeeklyExpenses(userId);
      // ensure we always have all 6 categories even if some have 0
      final allCategories = ["Bills", "Food", "Grocery", "Entertainment", "Commute", "Other"];
      for (var cat in allCategories) {
        if (!_weeklyCategoryTotals.any((e) => e["category"] == cat)) {
          _weeklyCategoryTotals.add({"category": cat, "total": 0.0});
        }
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching weekly expenses: $e");
    }
  }
}
