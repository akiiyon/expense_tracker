import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:flutter/foundation.dart';

/// All of the signed-in user's transactions, the wallet balance and category budgets.
class FinanceProvider with ChangeNotifier {
  FinanceProvider(this.api);

  final ApiClient api;

  List<Txn> _txns = [];
  Map<String, double> _budgets = {};
  double _balance = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Txn> get transactions => _txns;
  Map<String, double> get budgets => _budgets;
  double get balance => _balance;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await api.transactions();
      _txns = result.transactions;
      _balance = result.balance;
      _budgets = await api.budgets();
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Txn> add(TxnDraft draft) async {
    final result = await api.addTransaction(draft);
    _insert(result.txn);
    _balance = result.balance;
    notifyListeners();
    return result.txn;
  }

  /// Adds many (SMS sync). Returns only the ones the server didn't already have.
  Future<List<Txn>> addMany(List<TxnDraft> drafts) async {
    if (drafts.isEmpty) return const [];
    final result = await api.addTransactions(drafts);
    for (final t in result.added) {
      _insert(t);
    }
    _balance = result.balance;
    notifyListeners();
    return result.added;
  }

  Future<void> update(Txn old, TxnDraft draft) async {
    final result = await api.updateTransaction(old.id, draft);
    _txns.removeWhere((t) => t.id == old.id);
    _insert(result.txn);
    _balance = result.balance;
    notifyListeners();
  }

  /// Removes right away so the list feels instant; puts it back if the server fails.
  Future<void> remove(Txn txn) async {
    final index = _txns.indexWhere((t) => t.id == txn.id);
    if (index < 0) return;
    _txns.removeAt(index);
    _balance -= txn.signed;
    notifyListeners();
    try {
      _balance = await api.deleteTransaction(txn.id);
      notifyListeners();
    } on ApiException {
      _insert(txn);
      _balance += txn.signed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setBudget(String category, double amount) async {
    await api.setBudget(category, amount);
    if (amount <= 0) {
      _budgets.remove(category);
    } else {
      _budgets[category] = amount;
    }
    notifyListeners();
  }

  void clear() {
    _txns = [];
    _budgets = {};
    _balance = 0;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  void _insert(Txn t) {
    // keep newest first
    final i = _txns.indexWhere((x) => x.date.isBefore(t.date) || (x.date == t.date && x.id < t.id));
    if (i < 0) {
      _txns.add(t);
    } else {
      _txns.insert(i, t);
    }
  }
}
