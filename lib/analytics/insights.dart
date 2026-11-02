import 'dart:math' as math;

import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:intl/intl.dart';

/// [start, end) in local time.
class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;
  const DateRange(this.start, this.end, this.label);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  int get days => dayOf(end).difference(dayOf(start)).inDays.clamp(1, 100000);

  static DateRange today([DateTime? now]) {
    final d = dayOf(now ?? DateTime.now());
    return DateRange(d, d.add(const Duration(days: 1)), 'today');
  }

  static DateRange day(DateTime day, String label) {
    final d = dayOf(day);
    return DateRange(d, DateTime(d.year, d.month, d.day + 1), label);
  }

  /// Weeks start on Monday.
  static DateRange week([DateTime? now, int offset = 0]) {
    final d = dayOf(now ?? DateTime.now());
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1) + offset * 7);
    return DateRange(start, DateTime(start.year, start.month, start.day + 7), offset == 0 ? 'this week' : offset == -1 ? 'last week' : 'that week');
  }

  static DateRange month([DateTime? now, int offset = 0]) {
    final d = now ?? DateTime.now();
    final start = DateTime(d.year, d.month + offset, 1);
    final label = offset == 0
        ? 'this month'
        : offset == -1
            ? 'last month'
            : DateFormat('MMMM yyyy').format(start);
    return DateRange(start, DateTime(start.year, start.month + 1, 1), label);
  }

  static DateRange year([DateTime? now, int offset = 0]) {
    final d = now ?? DateTime.now();
    final start = DateTime(d.year + offset, 1, 1);
    return DateRange(start, DateTime(start.year + 1, 1, 1), offset == 0 ? 'this year' : offset == -1 ? 'last year' : '${start.year}');
  }

  static DateRange lastDays(int n, [DateTime? now]) {
    final d = dayOf(now ?? DateTime.now());
    return DateRange(DateTime(d.year, d.month, d.day - n + 1), DateTime(d.year, d.month, d.day + 1), 'the last $n days');
  }
}

Iterable<Txn> inRange(Iterable<Txn> txns, DateRange r, {TxnType? type, String? category}) => txns.where((t) =>
    r.contains(t.date) && (type == null || t.type == type) && (category == null || t.category.toLowerCase() == category.toLowerCase()));

double sumOf(Iterable<Txn> txns) => txns.fold(0.0, (s, t) => s + t.amount);

double spent(Iterable<Txn> txns, DateRange r, {String? category}) => sumOf(inRange(txns, r, type: TxnType.expense, category: category));

double earned(Iterable<Txn> txns, DateRange r) => sumOf(inRange(txns, r, type: TxnType.income));

/// Category totals, biggest first.
List<MapEntry<String, double>> byCategory(Iterable<Txn> txns, DateRange r, {TxnType type = TxnType.expense}) {
  final map = <String, double>{};
  for (final t in inRange(txns, r, type: type)) {
    map[t.category] = (map[t.category] ?? 0) + t.amount;
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// One entry per day in the range (zeros included).
List<MapEntry<DateTime, double>> byDay(Iterable<Txn> txns, DateRange r, {TxnType type = TxnType.expense}) {
  final map = <DateTime, double>{};
  for (var d = dayOf(r.start); d.isBefore(r.end); d = DateTime(d.year, d.month, d.day + 1)) {
    map[d] = 0;
  }
  for (final t in inRange(txns, r, type: type)) {
    final d = dayOf(t.date);
    map[d] = (map[d] ?? 0) + t.amount;
  }
  return map.entries.toList();
}

/// Last [count] months ending with the month of [now], oldest first.
List<MapEntry<DateTime, double>> byMonth(Iterable<Txn> txns, {int count = 6, DateTime? now, TxnType type = TxnType.expense}) {
  final n = now ?? DateTime.now();
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final r = DateRange.month(n, -i);
        return MapEntry(r.start, sumOf(inRange(txns, r, type: type)));
      }(),
  ];
}

/// Average spend per calendar weekday (1 = Monday) over the range.
Map<int, double> weekdayAverages(Iterable<Txn> txns, DateRange r) {
  final totals = {for (var i = 1; i <= 7; i++) i: 0.0};
  final counts = {for (var i = 1; i <= 7; i++) i: 0};
  for (var d = dayOf(r.start); d.isBefore(r.end); d = DateTime(d.year, d.month, d.day + 1)) {
    counts[d.weekday] = counts[d.weekday]! + 1;
  }
  for (final t in inRange(txns, r, type: TxnType.expense)) {
    totals[t.date.weekday] = totals[t.date.weekday]! + t.amount;
  }
  return {for (var i = 1; i <= 7; i++) i: counts[i] == 0 ? 0 : totals[i]! / counts[i]!};
}

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

// --------------------------------------------------------------------------
// Patterns & suggestions
// --------------------------------------------------------------------------

enum InsightKind { weekend, payday, peakDay, topCategory, rising, smallSpends, lateNight, subscriptions, budgetPace, budgetCategory, saving }

class Insight {
  final InsightKind kind;
  final String title;
  final String body;

  /// What to do about it. Null when it's just an observation.
  final String? tip;

  /// Higher shows first.
  final double weight;

  /// Good news rather than a warning.
  final bool positive;

  const Insight(this.kind, this.title, this.body, {this.tip, this.weight = 1, this.positive = false});
}

class Recurring {
  final String title;
  final double amount;
  final int months;
  const Recurring(this.title, this.amount, this.months);
}

/// Same-ish title and amount showing up in 2+ different months.
List<Recurring> findRecurring(List<Txn> txns, {DateTime? now}) {
  final since = DateRange.month(now, -3).start;
  final groups = <String, List<Txn>>{};
  for (final t in txns) {
    if (!t.isExpense || t.date.isBefore(since)) continue;
    final key = t.title.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (key.length < 3) continue;
    groups.putIfAbsent(key, () => []).add(t);
  }
  final out = <Recurring>[];
  for (final list in groups.values) {
    final months = list.map((t) => t.date.year * 12 + t.date.month).toSet();
    if (months.length < 2) continue;
    final amounts = list.map((t) => t.amount).toList()..sort();
    final median = amounts[amounts.length ~/ 2];
    final similar = list.where((t) => (t.amount - median).abs() <= median * 0.1).length;
    if (similar >= 2 && list.length <= months.length * 2) {
      out.add(Recurring(list.first.title, median, months.length));
    }
  }
  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}

/// Finds habits in the user's history. Needs a few weeks of data for most patterns.
List<Insight> detectPatterns(List<Txn> txns, {double monthlyBudget = 0, Map<String, double> categoryBudgets = const {}, DateTime? now}) {
  final n = now ?? DateTime.now();
  final out = <Insight>[];
  final expenses = txns.where((t) => t.isExpense).toList();
  if (expenses.isEmpty) return out;

  // --- weekends vs weekdays (last 8 weeks) ---
  final eightWeeks = DateRange.lastDays(56, n);
  final avg = weekdayAverages(expenses, eightWeeks);
  final weekdayAvg = [1, 2, 3, 4, 5].map((d) => avg[d]!).reduce((a, b) => a + b) / 5;
  final weekendAvg = (avg[6]! + avg[7]!) / 2;
  final activeDays = inRange(expenses, eightWeeks).map((t) => dayOf(t.date)).toSet().length;
  if (activeDays >= 6 && weekendAvg > weekdayAvg * 1.4 && weekendAvg - weekdayAvg > 150) {
    final ratio = weekdayAvg <= 0 ? 0 : weekendAvg / weekdayAvg;
    out.add(Insight(
      InsightKind.weekend,
      'Weekend splurger',
      ratio > 0
          ? 'You spend about ${ratio.toStringAsFixed(1)}x more on a weekend day (${money(weekendAvg.roundToDouble())}) than on a weekday (${money(weekdayAvg.roundToDouble())}).'
          : 'Almost all your spending happens on weekends (${money(weekendAvg.roundToDouble())} a day).',
      tip: 'Try a weekend cap of ${money((weekendAvg * 2 * 0.75).roundToDouble())} and plan one free outing.',
      weight: 3 + math.min(ratio.toDouble(), 3),
    ));
  }

  // --- busiest weekday ---
  if (activeDays >= 10) {
    final peak = avg.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final overall = avg.values.reduce((a, b) => a + b) / 7;
    if (overall > 0 && peak.value > overall * 1.6) {
      out.add(Insight(
        InsightKind.peakDay,
        '${weekdayNames[peak.key - 1]}s hit hardest',
        'On average you spend ${money(peak.value.roundToDouble())} on ${weekdayNames[peak.key - 1]}s, ${(peak.value / overall).toStringAsFixed(1)}x your daily norm.',
        weight: 1.5,
      ));
    }
  }

  // --- payday spike: spending in the 3 days after a salary / big income ---
  final incomes = txns.where((t) => t.isIncome && (t.category == 'Salary' || t.amount >= 15000)).toList();
  if (incomes.isNotEmpty) {
    final windows = <double>[];
    for (final inc in incomes.where((t) => t.date.isAfter(n.subtract(const Duration(days: 120))))) {
      final start = dayOf(inc.date);
      final r = DateRange(start, start.add(const Duration(days: 3)), '');
      if (r.end.isAfter(n.add(const Duration(days: 1)))) continue;
      windows.add(spent(expenses, r));
    }
    final baseRange = DateRange.lastDays(90, n);
    final baseline = spent(expenses, baseRange) / baseRange.days * 3;
    if (windows.isNotEmpty && baseline > 0) {
      final afterPay = windows.reduce((a, b) => a + b) / windows.length;
      if (afterPay > baseline * 1.5 && afterPay - baseline > 500) {
        out.add(Insight(
          InsightKind.payday,
          'Payday effect',
          'In the 3 days after money comes in you spend about ${money(afterPay.roundToDouble())}, vs ${money(baseline.roundToDouble())} in a normal 3 days.',
          tip: 'Move a fixed amount to savings the moment your salary lands, before the spending starts.',
          weight: 3.5,
        ));
      }
    }
  }

  // --- top category this month ---
  final thisMonth = DateRange.month(n);
  final monthSpend = spent(expenses, thisMonth);
  final cats = byCategory(expenses, thisMonth);
  if (cats.isNotEmpty && monthSpend > 0) {
    final top = cats.first;
    final share = top.value / monthSpend;
    if (share > 0.35 && cats.length > 1) {
      out.add(Insight(
        InsightKind.topCategory,
        '${top.key} leads the pack',
        '${(share * 100).round()}% of this month\'s spending (${money(top.value)}) went to ${top.key}.',
        tip: _categoryTip(top.key),
        weight: 2 + share,
      ));
    }
  }

  // --- categories growing vs last month (projected) ---
  final lastMonth = DateRange.month(n, -1);
  final elapsed = (n.difference(thisMonth.start).inHours / 24).clamp(1, 31) / thisMonth.days;
  if (elapsed > 0.25) {
    for (final c in cats) {
      final before = spent(expenses, lastMonth, category: c.key);
      final projected = c.value / elapsed;
      if (before > 300 && projected > before * 1.3 && projected - before > 500) {
        out.add(Insight(
          InsightKind.rising,
          '${c.key} is climbing',
          'At this pace ${c.key} will reach about ${money(projected.roundToDouble())} this month, up from ${money(before)} last month.',
          tip: _categoryTip(c.key),
          weight: 2.5,
        ));
        break;
      }
    }
  }

  // --- small frequent spends ---
  final last30 = DateRange.lastDays(30, n);
  final small = inRange(expenses, last30).where((t) => t.amount <= 200).toList();
  if (small.length >= 12) {
    final total = sumOf(small);
    out.add(Insight(
      InsightKind.smallSpends,
      'Little things add up',
      '${small.length} small spends under ₹200 in the last 30 days came to ${money(total)}.',
      tip: 'Cutting half of them would save around ${money((total / 2 * 12).roundToDouble())} a year.',
      weight: 2.2,
    ));
  }

  // --- late night spending (needs real times, e.g. from SMS) ---
  final late = inRange(expenses, last30).where((t) => t.date.hour >= 23 || t.date.hour < 4).toList();
  if (late.length >= 4) {
    out.add(Insight(
      InsightKind.lateNight,
      'Night owl purchases',
      '${late.length} payments after 11pm this month, worth ${money(sumOf(late))}.',
      tip: 'Late-night orders are often impulse buys. Try a "sleep on it" rule for anything not urgent.',
      weight: 2,
    ));
  }

  // --- subscriptions ---
  final recurring = findRecurring(expenses, now: n);
  if (recurring.isNotEmpty) {
    final total = recurring.fold(0.0, (s, r) => s + r.amount);
    out.add(Insight(
      InsightKind.subscriptions,
      'Repeat payments',
      '${recurring.take(3).map((r) => r.title).join(', ')}${recurring.length > 3 ? ' and more' : ''} show up every month, about ${money(total)} in total.',
      tip: 'Cancel any you haven\'t used in the last month.',
      weight: 1.8,
    ));
  }

  // --- monthly budget pace ---
  if (monthlyBudget > 0) {
    final projected = monthSpend / elapsed;
    if (monthSpend > monthlyBudget) {
      out.add(Insight(InsightKind.budgetPace, 'Over budget', 'You\'ve spent ${money(monthSpend)}, which is ${money(monthSpend - monthlyBudget)} over your ${money(monthlyBudget)} budget.',
          tip: 'Pause non-essentials until the 1st.', weight: 5));
    } else if (projected > monthlyBudget * 1.05 && elapsed > 0.2) {
      out.add(Insight(InsightKind.budgetPace, 'Budget pace check',
          'At this pace you\'ll spend about ${money(projected.roundToDouble())} by month end, above your ${money(monthlyBudget)} budget.',
          tip: 'Keep daily spending under ${money(((monthlyBudget - monthSpend) / math.max(1, thisMonth.days * (1 - elapsed))).floorToDouble())} to finish on target.',
          weight: 4));
    } else if (elapsed > 0.5) {
      out.add(Insight(InsightKind.budgetPace, 'On track', 'You\'re pacing to finish ${money((monthlyBudget - projected).clamp(0, monthlyBudget).roundToDouble())} under budget. Nice!',
          weight: 1.2, positive: true));
    }
  }

  // --- category budgets ---
  for (final e in categoryBudgets.entries) {
    final used = spent(expenses, thisMonth, category: e.key);
    if (e.value > 0 && used > e.value * 0.9) {
      out.add(Insight(
        InsightKind.budgetCategory,
        used > e.value ? '${e.key} budget blown' : '${e.key} budget nearly used',
        '${money(used)} of ${money(e.value)} used on ${e.key} this month.',
        weight: used > e.value ? 4.5 : 3,
      ));
    }
  }

  // --- saving rate ---
  final income = earned(txns, lastMonth);
  final lastSpend = spent(expenses, lastMonth);
  if (income > 0 && lastSpend < income) {
    final rate = (income - lastSpend) / income;
    if (rate >= 0.2) {
      out.add(Insight(InsightKind.saving, 'Saver mode', 'You kept ${(rate * 100).round()}% of what came in last month. That\'s a great habit!',
          weight: 1, positive: true));
    }
  }

  out.sort((a, b) => b.weight.compareTo(a.weight));
  return out;
}

String _categoryTip(String category) => switch (category) {
      'Food' => 'Cooking at home 2 extra days a week and skipping delivery fees can trim this a lot.',
      'Groceries' => 'A weekly list and one big shop beats many quick-commerce top-ups.',
      'Transport' => 'Mixing in metro, bus or pooled rides for regular routes adds up fast.',
      'Shopping' => 'Try a 48-hour wait before non-essential buys and clear your saved carts.',
      'Entertainment' => 'Set a fun budget for the month and look for free events nearby.',
      'Subscriptions' => 'Audit your subscriptions and keep only the ones you used this month.',
      'Bills' => 'Check for cheaper plans on mobile and internet; annual plans are often cheaper.',
      'Travel' => 'Book early and set fare alerts; flexible dates save the most.',
      _ => 'Set a category budget so xp can warn you before it gets out of hand.',
    };

/// Concrete ideas to spend less, best first. Always returns something.
List<String> savingSuggestions(List<Txn> txns, {double monthlyBudget = 0, Map<String, double> categoryBudgets = const {}, DateTime? now}) {
  final tips = <String>[];
  for (final i in detectPatterns(txns, monthlyBudget: monthlyBudget, categoryBudgets: categoryBudgets, now: now)) {
    if (i.tip != null && !i.positive) tips.add('${i.title}: ${i.tip}');
  }
  final n = now ?? DateTime.now();
  final cats = byCategory(txns, DateRange.lastDays(30, n));
  for (final c in cats.take(2)) {
    final tip = _categoryTip(c.key);
    if (!tips.any((t) => t.contains(tip))) tips.add('${c.key} (${money(c.value)} in 30 days): $tip');
  }
  if (monthlyBudget <= 0) tips.add('Set a monthly budget in your profile so I can warn you before you overspend.');
  if (tips.length < 3) tips.add('Try the 50/30/20 rule: 50% needs, 30% wants, 20% savings.');
  return tips.take(5).toList();
}
