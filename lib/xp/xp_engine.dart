import 'dart:math';

import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/xp/date_parser.dart';
import 'package:intl/intl.dart';

/// Rich content shown under an xp message.
sealed class XpCard {
  const XpCard();
}

class XpTxnCard extends XpCard {
  final Txn txn;
  const XpTxnCard(this.txn);
}

class XpBreakdownCard extends XpCard {
  final String title;
  final List<MapEntry<String, double>> rows;
  final double total;

  /// rows are categories (coloured with category colours) rather than dates.
  final bool categories;
  const XpBreakdownCard(this.title, this.rows, this.total, {this.categories = false});
}

class XpTxnListCard extends XpCard {
  final List<Txn> txns;
  const XpTxnListCard(this.txns);
}

class XpReply {
  final String text;
  final List<XpCard> cards;
  final List<String> suggestions;
  const XpReply(this.text, {this.cards = const [], this.suggestions = const []});
}

/// What xp can see and change. Implemented by the app's providers (and fakes in tests).
abstract class XpData {
  String get userName;
  List<Txn> get transactions;
  double get balance;
  double get monthlyBudget;
  Map<String, double> get categoryBudgets;
  Future<Txn> addTransaction(TxnDraft draft);
  Future<void> removeTransaction(Txn txn);
}

/// Parsed "add an expense" request.
class ParsedEntry {
  final TxnType type;
  final double amount;
  final String category;
  final String title;
  final DateTime date;
  const ParsedEntry(this.type, this.amount, this.category, this.title, this.date);
}

/// xp's on-device brain. Understands the common requests without the internet.
/// Returns null from [respond] when it doesn't understand, so the caller can ask the cloud brain.
class XpEngine {
  XpEngine(this.data, {Random? random, DateTime Function()? clock})
      : _random = random ?? Random(),
        _clock = clock ?? DateTime.now;

  final XpData data;
  final Random _random;
  final DateTime Function() _clock;
  Txn? _lastAdded;

  String _pick(List<String> options) => options[_random.nextInt(options.length)];

  String get _name => data.userName.trim().isEmpty ? '' : data.userName.trim().split(' ').first;

  static const defaultSuggestions = [
    'How much did I spend this month?',
    'Category wise breakdown',
    'Any patterns in my spending?',
    'How can I save more?',
  ];

  Future<XpReply?> respond(String input) async {
    final text = input.trim();
    if (text.isEmpty) return null;
    final t = text.toLowerCase().replaceAll(RegExp(r'[’]'), "'");
    final now = _clock();

    if (_isGreeting(t)) return _greeting();
    if (RegExp(r"^(thanks|thank you|thx|ty|cool|great|awesome|nice|ok|okay|perfect)\b").hasMatch(t) && t.split(' ').length <= 5) {
      return XpReply(_pick(['Anytime! 💜', 'Happy to help!', 'Always here for you.', "That's what I'm here for!"]));
    }
    if (RegExp(r"\b(who are you|what are you|your name|what can you do|help me|^help$|how do you work|what do you do)\b").hasMatch(t)) {
      return const XpReply(
        "I'm xp, your money buddy! Tell me things like \"spent 250 on lunch\" and I'll log it. Ask me how much you spent on anything, any day, week or month, and I'll spot your habits and help you save.",
        suggestions: defaultSuggestions,
      );
    }
    if (RegExp(r"\bhow are you\b|\bhow's it going\b|\bwhat'?s up\b").hasMatch(t)) {
      return XpReply(_pick([
        "I'm great, thanks for asking! Your numbers are looking organised. What can I do for you?",
        "Doing wonderful! Ready to crunch some numbers with you.",
      ]), suggestions: defaultSuggestions);
    }

    if (RegExp(r'\b(undo|delete (the )?last|remove (the )?last|remove that|delete that|cancel that)\b').hasMatch(t)) {
      return _undo();
    }

    if (_isSavingsQuestion(t)) return _suggestions(now);
    if (RegExp(r'\b(pattern|patterns|habit|habits|insight|insights|analy[sz]e|trend|trends|when do i spend|where does my money go)\b').hasMatch(t)) {
      return _patterns(now);
    }

    final isQuestion = RegExp(r"^(how|what|which|when|where|show|list|give|tell|did|do|can|is|am|was|my)\b|\?$|\bhow much\b").hasMatch(t);

    if (!isQuestion || RegExp(r'^(add|log|record|note)\b').hasMatch(t)) {
      final entry = parseEntry(text, now);
      if (entry != null) return _add(entry);
    }

    if (RegExp(r'\b(balance|wallet|how much (money )?(do i have|is left|left)|money left)\b').hasMatch(t)) return _balance(now);
    if (RegExp(r'\b(budget|can i (still )?spend|how much can i spend)\b').hasMatch(t)) return _budget(now);

    if (RegExp(r'\b(spend|spent|spending|expense|expenses|cost|paid|pay|earn|earned|income|received|breakdown|wise|transactions|summary|total|list|biggest|largest|most)\b').hasMatch(t)) {
      return _query(t, now);
    }

    final entry = parseEntry(text, now);
    if (entry != null) return _add(entry);
    return null;
  }

  // ---------------------------------------------------------------- intents

  bool _isGreeting(String t) =>
      RegExp(r"^(hi|hello|hey|hii+|heya|yo|namaste|good (morning|afternoon|evening))( xp)?[!. ]*$").hasMatch(t) || t == 'xp';

  bool _isSavingsQuestion(String t) => RegExp(
          r'\b(save|saving|savings|cut (down|back)|reduce|spend less|tips?|advice|suggest|suggestion|suggestions|ideas?|overspend|wasting|unnecessary|cheaper)\b')
      .hasMatch(t);

  XpReply _greeting() {
    final hi = _name.isEmpty ? 'Hey there!' : _pick(['Hey $_name!', 'Hi $_name!', 'Hello $_name!']);
    final todaySpent = spent(data.transactions, DateRange.today(_clock()));
    final follow = todaySpent > 0
        ? "You've spent ${money(todaySpent)} today. What would you like to know?"
        : _pick(["Nothing spent today so far, love that. What can I do for you?", 'What can I help you with today?', 'Ready when you are. Log something or ask me anything.']);
    return XpReply('$hi $follow', suggestions: defaultSuggestions);
  }

  Future<XpReply> _undo() async {
    final target = _lastAdded;
    if (target == null) {
      return const XpReply("I haven't added anything in this chat yet, so there's nothing to undo. You can swipe any transaction in Activity to delete it.");
    }
    await data.removeTransaction(target);
    _lastAdded = null;
    return XpReply("Done, I removed ${target.title} (${money(target.amount)}). Poof, like it never happened.");
  }

  Future<XpReply> _add(ParsedEntry e) async {
    final txn = await data.addTransaction(TxnDraft(
      type: e.type,
      amount: e.amount,
      category: e.category,
      title: e.title,
      date: e.date,
      source: 'xp',
    ));
    _lastAdded = txn;
    final when = sameDay(e.date, _clock()) ? '' : ' for ${friendlyDay(e.date).toLowerCase()}';
    if (e.type == TxnType.income) {
      return XpReply(
        _pick([
          'Ka-ching! Added ${money(e.amount)} as ${e.category}$when. Your balance is now ${money(data.balance)}.',
          'Love to see it! ${money(e.amount)} ${e.category.toLowerCase()} logged$when. Balance: ${money(data.balance)}.',
        ]),
        cards: [XpTxnCard(txn)],
        suggestions: const ['Undo that', 'What is my balance?'],
      );
    }
    final monthSpent = spent(data.transactions, DateRange.month(_clock()));
    var extra = '';
    if (data.monthlyBudget > 0) {
      final left = data.monthlyBudget - monthSpent;
      extra = left >= 0 ? ' ${money(left)} left in this month\'s budget.' : ' Heads up, you\'re ${money(-left)} over budget this month.';
    }
    return XpReply(
      '${_pick(['Got it!', 'Done!', 'Noted!', 'Logged!'])} ${money(e.amount)} on ${e.title} under ${e.category}$when.$extra',
      cards: [XpTxnCard(txn)],
      suggestions: const ['Undo that', 'How much did I spend today?'],
    );
  }

  XpReply _balance(DateTime now) {
    final month = DateRange.month(now);
    final s = spent(data.transactions, month), e = earned(data.transactions, month);
    final mood = data.balance < 0 ? ' Looks like we\'re in the red, let\'s be gentle with spending for a bit.' : '';
    return XpReply(
      'Your wallet balance is ${money(data.balance)}. This month: ${money(e)} in, ${money(s)} out.$mood',
      suggestions: const ['Budget status', 'Category wise breakdown'],
    );
  }

  XpReply _budget(DateTime now) {
    final month = DateRange.month(now);
    final s = spent(data.transactions, month);
    if (data.monthlyBudget <= 0) {
      return XpReply(
        "You haven't set a monthly budget yet. You've spent ${money(s)} so far this month. Set one in Profile and I'll keep you on track!",
        suggestions: const ['How can I save more?'],
      );
    }
    final left = data.monthlyBudget - s;
    final daysLeft = month.end.difference(dayOf(now)).inDays;
    if (left <= 0) {
      return XpReply("You've used your whole ${money(data.monthlyBudget)} budget and gone ${money(-left)} over. Let's keep the rest of the month to essentials, okay?",
          suggestions: const ['How can I save more?']);
    }
    return XpReply(
      "You have ${money(left)} left of your ${money(data.monthlyBudget)} budget. That's about ${money((left / max(daysLeft, 1)).floorToDouble())} a day for the next $daysLeft days.",
      suggestions: const ['Category wise breakdown', 'Any patterns?'],
    );
  }

  XpReply _suggestions(DateTime now) {
    if (data.transactions.where((t) => t.isExpense).length < 3) {
      return const XpReply("I need a few more expenses before I can give you advice that's actually about you. Log a couple of days of spending and ask me again!");
    }
    final tips = savingSuggestions(data.transactions, monthlyBudget: data.monthlyBudget, categoryBudgets: data.categoryBudgets, now: now);
    final intro = _pick(['Okay, here\'s my honest take:', 'Here\'s where I think you can save:', 'Let\'s find you some money:']);
    return XpReply('$intro\n${tips.map((t) => '• $t').join('\n')}', suggestions: const ['Any patterns?', 'Category wise breakdown']);
  }

  XpReply _patterns(DateTime now) {
    final found = detectPatterns(data.transactions, monthlyBudget: data.monthlyBudget, categoryBudgets: data.categoryBudgets, now: now);
    if (found.isEmpty) {
      return const XpReply("No strong patterns yet. Once you've logged a few weeks of spending I'll spot things like weekend splurges or payday sprees.",
          suggestions: ['How can I save more?']);
    }
    final lines = found.take(4).map((i) => '• ${i.title}: ${i.body}').join('\n');
    return XpReply('${_pick(['Here\'s what I noticed:', 'Ooh, I found some patterns:', 'A few things stand out:'])}\n$lines',
        suggestions: const ['How can I save more?', 'Day wise spending this month']);
  }

  XpReply _query(String t, DateTime now) {
    final income = RegExp(r'\b(earn|earned|income|received|got paid|salary)\b').hasMatch(t);
    final type = income ? TxnType.income : TxnType.expense;
    final explicitRange = parseRange(t, now);
    final range = explicitRange ?? (RegExp(r'\bmonth ?wise\b|\bmonthly\b|\bper month\b|\bby month\b').hasMatch(t) ? DateRange.lastDays(180, now) : DateRange.month(now));
    final category = _mentionedCategory(t, income: income);
    final txns = data.transactions;

    // biggest expenses
    if (RegExp(r'\b(biggest|largest|highest|most expensive|top)\b').hasMatch(t) && !RegExp(r'\bcategor').hasMatch(t)) {
      final list = inRange(txns, range, type: type, category: category).toList()..sort((a, b) => b.amount.compareTo(a.amount));
      if (list.isEmpty) return XpReply('Nothing to show ${range.label}.');
      return XpReply('Your biggest ${income ? 'income' : 'spends'} ${range.label}:', cards: [XpTxnListCard(list.take(5).toList())]);
    }

    // list transactions
    if (RegExp(r'\b(list|show( me)?|transactions|what did i (buy|spend on))\b').hasMatch(t) && !RegExp(r'\bwise\b|\bbreakdown\b|\bby (category|day|month)\b').hasMatch(t)) {
      final list = inRange(txns, range, type: type, category: category).toList();
      if (list.isEmpty) return XpReply('No ${category ?? ''} ${income ? 'income' : 'expenses'} ${range.label}.'.replaceAll('  ', ' '));
      return XpReply(
        '${list.length} ${income ? 'income entries' : 'expenses'}${category != null ? ' in $category' : ''} ${range.label}, ${money(sumOf(list))} in total.',
        cards: [XpTxnListCard(list.take(10).toList())],
      );
    }

    // month wise
    if (RegExp(r'\bmonth ?wise\b|\bby month\b|\bper month\b|\bmonthly\b|\bmonth by month\b').hasMatch(t)) {
      final months = byMonth(category == null ? txns : txns.where((x) => x.category == category).toList(), count: 6, now: now, type: type);
      final rows = months.map((e) => MapEntry(DateFormat('MMM yy').format(e.key), e.value)).toList();
      final total = rows.fold(0.0, (s, e) => s + e.value);
      final nonZero = months.where((m) => m.value > 0).toList();
      if (nonZero.isEmpty) return XpReply('No ${income ? 'income' : 'spending'} in the last 6 months yet.');
      final peak = nonZero.reduce((a, b) => a.value >= b.value ? a : b);
      return XpReply(
        'Here\'s your month by month ${income ? 'income' : 'spending'}${category != null ? ' on $category' : ''}. ${DateFormat('MMMM').format(peak.key)} was the biggest at ${money(peak.value)}, and you averaged ${money((total / nonZero.length).roundToDouble())} a month.',
        cards: [XpBreakdownCard('Last 6 months', rows, total)],
      );
    }

    // weekday
    if (RegExp(r'\b(weekday|day of (the )?week|which day)\b').hasMatch(t)) {
      final r = explicitRange ?? DateRange.lastDays(56, now);
      final avg = weekdayAverages(txns, r);
      final rows = [for (var i = 1; i <= 7; i++) MapEntry(weekdayNames[i - 1].substring(0, 3), avg[i]!.roundToDouble())];
      final peak = avg.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return XpReply('On average you spend the most on ${weekdayNames[peak.key - 1]}s (${money(peak.value.roundToDouble())}).',
          cards: [XpBreakdownCard('Average per weekday', rows, rows.fold(0.0, (s, e) => s + e.value))]);
    }

    // day wise
    if (RegExp(r'\b(day ?wise|daily|by day|each day|per day|day by day)\b').hasMatch(t)) {
      final r = explicitRange ?? (range.days > 31 ? DateRange.lastDays(14, now) : range);
      final effective = DateRange(r.start, r.end.isAfter(now) ? dayOf(now).add(const Duration(days: 1)) : r.end, r.label);
      final days = byDay(category == null ? txns : txns.where((x) => x.category == category).toList(), effective, type: type);
      final total = days.fold(0.0, (s, e) => s + e.value);
      if (total == 0) return XpReply('No ${income ? 'income' : 'spending'} ${r.label}.');
      final active = days.where((d) => d.value > 0).toList();
      final peak = active.reduce((a, b) => a.value >= b.value ? a : b);
      final rows = days.reversed.where((d) => d.value > 0).map((d) => MapEntry(friendlyDay(d.key), d.value)).toList();
      return XpReply(
        '${money(total)} ${r.label}, about ${money((total / days.length).roundToDouble())} a day. Your biggest day was ${friendlyDay(peak.key)} at ${money(peak.value)}.',
        cards: [XpBreakdownCard('Day by day', rows, total)],
      );
    }

    final total = sumOf(inRange(txns, range, type: type, category: category));
    final count = inRange(txns, range, type: type, category: category).length;

    // category breakdown
    if (category == null && (RegExp(r'\b(categor\w*|breakdown|wise|split|where)\b').hasMatch(t) || explicitRange == null && RegExp(r'\b(spending|expenses)\b').hasMatch(t))) {
      final cats = byCategory(txns, range, type: type);
      if (cats.isEmpty) return XpReply('No ${income ? 'income' : 'spending'} ${range.label} yet. ${income ? '' : 'Your wallet thanks you!'}'.trim());
      final top = cats.take(3).toList();
      final pct = (top.first.value / total * 100).round();
      final rest = top.skip(1).map((e) => '${e.key} ${money(e.value)}').join(' and ');
      return XpReply(
        '${income ? 'You received' : 'You spent'} ${money(total)} ${range.label}. ${top.first.key} leads with ${money(top.first.value)} ($pct%)${rest.isEmpty ? '' : ', then $rest'}.',
        cards: [XpBreakdownCard('By category', cats, total, categories: true)],
        suggestions: const ['How can I save more?', 'How much did I spend last month?'],
      );
    }

    // single total, with a comparison to the period before
    final verb = income ? 'received' : 'spent';
    if (count == 0) {
      return XpReply(
        income
            ? 'No income recorded ${range.label}${category != null ? ' under $category' : ''}.'
            : _pick(['Zero! You spent nothing${category != null ? ' on $category' : ''} ${range.label}.', 'Nothing at all${category != null ? ' on $category' : ''} ${range.label}. Impressive!']),
      );
    }
    var compare = '';
    final previous = _previous(range);
    if (previous != null) {
      final before = sumOf(inRange(txns, previous, type: type, category: category));
      if (before > 0) {
        final change = (total - before) / before * 100;
        if (change.abs() >= 5) {
          compare = change < 0
              ? ' That\'s ${change.abs().round()}% less than ${previous.label}${income ? '' : ', nice going'}!'
              : ' That\'s ${change.round()}% more than ${previous.label}.';
        }
      }
    }
    return XpReply(
      'You $verb ${money(total)}${category != null ? ' on $category' : ''} ${range.label} across $count ${count == 1 ? 'transaction' : 'transactions'}.$compare',
      suggestions: [if (category == null) 'Category wise breakdown', 'Show the transactions'],
    );
  }

  DateRange? _previous(DateRange r) {
    final label = r.label;
    if (label == 'this month') return DateRange.month(r.start, -1);
    if (label == 'this week') return DateRange.week(r.start, -1);
    if (label == 'today') return DateRange.day(r.start.subtract(const Duration(days: 1)), 'yesterday');
    if (label == 'last month') return DateRange(DateRange.month(r.start, -1).start, r.start, 'the month before');
    if (label == 'last week') return DateRange(r.start.subtract(const Duration(days: 7)), r.start, 'the week before');
    return null;
  }

  String? _mentionedCategory(String t, {bool income = false}) {
    final list = income ? incomeCategories : expenseCategories;
    for (final c in list) {
      if (c.name == 'Other') continue;
      if (RegExp('\\b${RegExp.escape(c.name.toLowerCase())}\\b').hasMatch(t)) return c.name;
    }
    if (income) return null;
    // "on food", "for uber"
    final m = RegExp(r'\b(?:on|for|at)\s+([a-z ]+?)(?:\s+(?:this|last|in|on|today|yesterday|during|between|from)\b|\?|$)').firstMatch(t);
    if (m != null) return guessCategory(m.group(1)!);
    return null;
  }
}

// -------------------------------------------------------------------- parsing

const _incomeWords = r'\b(got|received|receive|earned|earn|salary|income|credited|credit|refund|cashback|gift(ed)?|bonus|freelance|top ?up|topped up|added to (my )?wallet|add money|deposit(ed)?)\b';
const _expenseVerbs = r'\b(spent|spend|paid|pay|bought|buy|purchased|ordered|gave|lost|used|cost|costs|expense|kharcha|kharch)\b';

/// Reads an amount like 250, 1,250, ₹1.5k, 2 lakh. Ignores numbers that are part of a date.
double? parseAmount(String input) {
  var t = input.toLowerCase().replaceAll('rupees', 'rs').replaceAll('bucks', 'rs');
  final currency = RegExp(r'(?:₹|\brs\.?|\binr)\s*(\d[\d,]*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|l)?\b|(\d[\d,]*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac)?\s*(?:₹|\brs\b|\brupees?\b|\binr\b)')
      .firstMatch(t);
  if (currency != null) {
    return _scale(currency.group(1) ?? currency.group(3)!, currency.group(2) ?? currency.group(4));
  }
  for (final p in dateNumberPatterns) {
    t = t.replaceAll(p, ' ');
  }
  final m = RegExp(r'(?<![\w.])(\d[\d,]*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac)?\b').firstMatch(t);
  if (m == null) return null;
  return _scale(m.group(1)!, m.group(2));
}

double? _scale(String digits, String? unit) {
  final v = double.tryParse(digits.replaceAll(',', ''));
  if (v == null) return null;
  return switch (unit) {
    'k' || 'thousand' => v * 1000,
    'lakh' || 'lakhs' || 'lac' || 'l' => v * 100000,
    _ => v,
  };
}

/// "spent 250 on pizza yesterday" -> expense ₹250, Food, "Pizza", yesterday.
ParsedEntry? parseEntry(String input, DateTime now) {
  final t = input.toLowerCase().trim();
  final amount = parseAmount(t);
  if (amount == null || amount <= 0 || amount > 10000000) return null;

  final isIncome = RegExp(_incomeWords).hasMatch(t) && !RegExp(r'\b(spent|paid|bought)\b').hasMatch(t);
  final hasExpenseVerb = RegExp(_expenseVerbs).hasMatch(t) || RegExp(r'^(add|log|record|note)\b').hasMatch(t);
  final guessed = guessCategory(t, income: isIncome);
  if (!isIncome && !hasExpenseVerb && guessed == null) return null;

  final date = parseDate(t, now);
  final when = date == null || sameDay(date, now) ? now : DateTime(date.year, date.month, date.day, 12);
  final category = guessed ?? _directCategory(t, isIncome) ?? (isIncome ? 'Other' : 'Other');
  return ParsedEntry(isIncome ? TxnType.income : TxnType.expense, amount, category, _title(t, category, isIncome), when);
}

String? _directCategory(String t, bool income) {
  for (final c in income ? incomeCategories : expenseCategories) {
    if (RegExp('\\b${RegExp.escape(c.name.toLowerCase())}\\b').hasMatch(t)) return c.name;
  }
  return null;
}

String _title(String t, String category, bool income) {
  final m = RegExp(r'\b(?:on|for|at|from|to)\s+(?:a\s+|an\s+|the\s+|my\s+)?(.+)$').firstMatch(t);
  var title = m?.group(1) ?? '';
  // drop trailing date words and amounts
  title = title
      .replaceAll(RegExp(r'\b(yesterday|today|tonight|this morning|this evening|day before yesterday|last \w+|on \w+day|\d+ days? ago)\b.*$'), '')
      .replaceAll(RegExp(r'(?:₹|\brs\.?|\binr)\s*[\d,.]+|\b[\d,.]+\s*(rs|rupees|k)?\b'), '')
      .replaceAll(RegExp(r'\b(for|on|at|and|of|in)\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty || title.length > 40) {
    if (income) return category == 'Other' ? 'Income' : category;
    return category == 'Other' ? 'Expense' : category;
  }
  return title[0].toUpperCase() + title.substring(1);
}
