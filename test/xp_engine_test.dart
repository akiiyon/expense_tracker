import 'dart:math';

import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/xp/date_parser.dart';
import 'package:expense_tracker/xp/xp_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeData implements XpData {
  FakeData(this.transactions);

  @override
  final List<Txn> transactions;
  @override
  String get userName => 'Akshay Kumar';
  @override
  double get balance => transactions.fold(0.0, (s, t) => s + t.signed);
  @override
  double monthlyBudget = 0;
  @override
  Map<String, double> get categoryBudgets => const {};

  int _id = 1000;

  @override
  Future<Txn> addTransaction(TxnDraft d) async {
    final t = Txn(id: _id++, type: d.type, amount: d.amount, category: d.category, title: d.title, date: d.date, source: d.source);
    transactions.insert(0, t);
    return t;
  }

  @override
  Future<void> removeTransaction(Txn txn) async => transactions.removeWhere((t) => t.id == txn.id);
}

// Wednesday 29 Oct 2026, 6pm
final now = DateTime(2026, 10, 29, 18);

Txn e(int id, double amount, String category, DateTime date, {String? title}) =>
    Txn(id: id, type: TxnType.expense, amount: amount, category: category, title: title ?? category, date: date);

Txn inc(int id, double amount, DateTime date, {String category = 'Salary'}) =>
    Txn(id: id, type: TxnType.income, amount: amount, category: category, title: category, date: date);

void main() {
  group('parseAmount', () {
    test('plain, currency, shorthand', () {
      expect(parseAmount('spent 250 on pizza'), 250);
      expect(parseAmount('paid ₹1,250.50 for groceries'), 1250.5);
      expect(parseAmount('rs. 499 netflix'), 499);
      expect(parseAmount('got 1.5k from client'), 1500);
      expect(parseAmount('salary 2 lakh'), 200000);
    });
    test('ignores date numbers', () {
      expect(parseAmount('spent 300 on 5th march'), 300);
      expect(parseAmount('on 12 oct I paid 800 for dinner'), 800);
      expect(parseAmount('2 days ago spent 150 on chai'), 150);
    });
  });

  group('parseEntry', () {
    test('expense with category and title', () {
      final p = parseEntry('spent 250 on pizza yesterday', now)!;
      expect(p.type, TxnType.expense);
      expect(p.amount, 250);
      expect(p.category, 'Food');
      expect(p.title, 'Pizza');
      expect(p.date.day, 28);
    });
    test('income', () {
      final p = parseEntry('got my salary of 50000', now)!;
      expect(p.type, TxnType.income);
      expect(p.category, 'Salary');
      expect(p.amount, 50000);
    });
    test('uber without a verb', () {
      final p = parseEntry('uber 340', now)!;
      expect(p.category, 'Transport');
    });
    test('not an entry', () {
      expect(parseEntry('what is 5 + 5', now), isNull);
    });
  });

  group('parseRange', () {
    test('relative ranges', () {
      expect(parseRange('how much last week', now)!.start, DateTime(2026, 10, 19));
      expect(parseRange('this month', now)!.start, DateTime(2026, 10, 1));
      expect(parseRange('last month', now)!.end, DateTime(2026, 10, 1));
      expect(parseRange('yesterday', now)!.start, DateTime(2026, 10, 28));
      expect(parseRange('last 7 days', now)!.start, DateTime(2026, 10, 23));
    });
    test('months and days', () {
      final march = parseRange('spending in march', now)!;
      expect(march.start, DateTime(2026, 3, 1));
      expect(march.end, DateTime(2026, 4, 1));
      expect(parseRange('in december', now)!.start, DateTime(2025, 12, 1));
      expect(parseRange('on 5 oct', now)!.start, DateTime(2026, 10, 5));
      final between = parseRange('between 1 oct and 10 oct', now)!;
      expect(between.start, DateTime(2026, 10, 1));
      expect(between.end, DateTime(2026, 10, 11));
    });
    test('modal "may" is not a month', () {
      expect(parseRange('how may I save', now), isNull);
    });
  });

  group('XpEngine', () {
    late FakeData data;
    late XpEngine xp;

    setUp(() {
      data = FakeData([
        e(1, 500, 'Food', DateTime(2026, 10, 28, 13)),
        e(2, 200, 'Transport', DateTime(2026, 10, 27, 9)),
        e(3, 1200, 'Shopping', DateTime(2026, 10, 25, 20)),
        e(4, 900, 'Food', DateTime(2026, 9, 15, 13)),
        inc(5, 50000, DateTime(2026, 10, 1, 10)),
      ]);
      xp = XpEngine(data, random: Random(1), clock: () => now);
    });

    test('adds an expense and can undo it', () async {
      final r = (await xp.respond('Spent 250 on lunch'))!;
      expect(r.text, contains('₹250'));
      expect(data.transactions.first.category, 'Food');
      expect(data.transactions.first.source, 'xp');
      await xp.respond('undo');
      expect(data.transactions.any((t) => t.title == 'Lunch'), isFalse);
    });

    test('totals this month with category filter', () async {
      final r = (await xp.respond('How much did I spend on food this month?'))!;
      expect(r.text, contains('₹500'));
      expect(r.text, contains('Food'));
    });

    test('category breakdown', () async {
      final r = (await xp.respond('category wise expenses this month'))!;
      expect(r.text, contains('₹1,900'));
      expect(r.cards.single, isA<XpBreakdownCard>());
    });

    test('month wise', () async {
      final r = (await xp.respond('month wise spending'))!;
      final card = r.cards.single as XpBreakdownCard;
      expect(card.rows.length, 6);
    });

    test('day wise', () async {
      final r = (await xp.respond('day wise spending this week'))!;
      expect(r.cards.single, isA<XpBreakdownCard>());
    });

    test('balance', () async {
      final r = (await xp.respond("what's my balance"))!;
      expect(r.text, contains('₹47,200'));
    });

    test('suggestions always give something', () async {
      final r = (await xp.respond('how can I save money?'))!;
      expect(r.text, contains('•'));
    });

    test('greets by first name', () async {
      final r = (await xp.respond('hey xp'))!;
      expect(r.text, contains('Akshay'));
    });

    test('unknown goes to the cloud', () async {
      expect(await xp.respond('explain mutual funds like I am five'), isNull);
    });
  });

  group('patterns', () {
    test('detects weekend spending and payday spikes', () {
      final txns = <Txn>[];
      var id = 0;
      for (var d = DateTime(2026, 9, 1); d.isBefore(now); d = d.add(const Duration(days: 1))) {
        final weekend = d.weekday >= 6;
        txns.add(e(id++, weekend ? 1500 : 200, 'Food', DateTime(d.year, d.month, d.day, 13)));
      }
      txns.add(inc(id++, 60000, DateTime(2026, 10, 1, 9)));
      for (var i = 0; i < 3; i++) {
        txns.add(e(id++, 4000, 'Shopping', DateTime(2026, 10, 1 + i, 15)));
      }
      final found = detectPatterns(txns, now: now).map((i) => i.kind).toSet();
      expect(found, contains(InsightKind.weekend));
      expect(found, contains(InsightKind.payday));
    });

    test('finds recurring payments', () {
      final txns = [
        e(1, 649, 'Subscriptions', DateTime(2026, 8, 5), title: 'Netflix'),
        e(2, 649, 'Subscriptions', DateTime(2026, 9, 5), title: 'Netflix'),
        e(3, 649, 'Subscriptions', DateTime(2026, 10, 5), title: 'Netflix'),
      ];
      expect(findRecurring(txns, now: now).single.title, 'Netflix');
    });
  });
}
