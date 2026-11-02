enum TxnType { expense, income }

class Txn {
  final int id;
  final TxnType type;
  final double amount;
  final String category;
  final String title;
  final String? note;
  final DateTime date;

  /// manual | sms | xp
  final String source;

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.title,
    required this.date,
    this.note,
    this.source = 'manual',
  });

  bool get isExpense => type == TxnType.expense;
  bool get isIncome => type == TxnType.income;

  /// +amount for income, -amount for expense.
  double get signed => isIncome ? amount : -amount;

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as int,
        type: j['type'] == 'income' ? TxnType.income : TxnType.expense,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String? ?? 'Other',
        title: j['title'] as String? ?? '',
        note: j['note'] as String?,
        date: DateTime.parse(j['txn_date'] as String).toLocal(),
        source: j['source'] as String? ?? 'manual',
      );
}

/// What the app sends to create or edit a transaction.
class TxnDraft {
  final TxnType type;
  final double amount;
  final String category;
  final String title;
  final String? note;
  final DateTime date;
  final String source;
  final String? sourceRef;

  const TxnDraft({
    required this.type,
    required this.amount,
    required this.category,
    required this.title,
    required this.date,
    this.note,
    this.source = 'manual',
    this.sourceRef,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'amount': amount,
        'category': category,
        'title': title,
        'note': note,
        'txn_date': date.toUtc().toIso8601String(),
        'source': source,
        'source_ref': sourceRef,
      };
}

class AppUser {
  final int id;
  final String name;
  final String email;
  final double monthlyBudget;

  const AppUser({required this.id, required this.name, required this.email, this.monthlyBudget = 0});

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {'id': id, 'username': name, 'email': email, 'monthly_budget': monthlyBudget};

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['username'] as String? ?? '',
        email: j['email'] as String? ?? '',
        monthlyBudget: (j['monthly_budget'] as num?)?.toDouble() ?? 0,
      );
}
