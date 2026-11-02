import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:intl/intl.dart';

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _monthPattern = r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
const _weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const _numberWords = {'a': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'ten': 10, 'fifteen': 15, 'thirty': 30};

int _month(String s) => _months[s.substring(0, 3)]!;

int? _num(String s) => int.tryParse(s) ?? _numberWords[s];

/// Regex fragments that describe a date. Used to keep date numbers from being read as amounts.
final dateNumberPatterns = <RegExp>[
  RegExp(r'\b\d{1,2}\s*(st|nd|rd|th)\b'),
  RegExp('\\b\\d{1,2}\\s+(of\\s+)?$_monthPattern\\b'),
  RegExp('\\b$_monthPattern\\s+\\d{1,2}(st|nd|rd|th)?\\b'),
  RegExp('\\b$_monthPattern\\s+\\d{4}\\b'),
  RegExp(r'\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b'),
  RegExp(r'\b\d+\s+(days?|weeks?|months?|years?)\b'),
  RegExp(r'\b(19|20)\d{2}\b'),
];

/// Finds "5 march", "march 5", "5th", "5/3/2025" style dates. Picks the past year when no year is given.
DateTime? _parseDayMonth(String t, DateTime now) {
  DateTime build(int day, int month, int? year) {
    var y = year ?? now.year;
    if (y < 100) y += 2000;
    var d = DateTime(y, month, day);
    if (year == null && d.isAfter(now)) d = DateTime(y - 1, month, day);
    return d;
  }

  var m = RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?$_monthPattern(?:,?\\s+(\\d{4}))?').firstMatch(t);
  if (m != null) return build(int.parse(m.group(1)!), _month(m.group(2)!), m.group(3) == null ? null : int.parse(m.group(3)!));

  m = RegExp('\\b$_monthPattern\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?\\b').firstMatch(t);
  if (m != null) return build(int.parse(m.group(2)!), _month(m.group(1)!), m.group(3) == null ? null : int.parse(m.group(3)!));

  m = RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b').firstMatch(t);
  if (m != null) {
    final day = int.parse(m.group(1)!), month = int.parse(m.group(2)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return build(day, month, m.group(3) == null ? null : int.parse(m.group(3)!));
    }
  }

  m = RegExp(r'\b(?:on\s+(?:the\s+)?)?(\d{1,2})(st|nd|rd|th)\b').firstMatch(t);
  if (m != null) {
    final day = int.parse(m.group(1)!);
    if (day >= 1 && day <= 31) {
      var d = DateTime(now.year, now.month, day);
      if (d.isAfter(now)) d = DateTime(now.year, now.month - 1, day);
      return d;
    }
  }
  return null;
}

/// The most recent [weekday] on or before today ("last friday" skips today).
DateTime _lastWeekday(int weekday, DateTime now, {bool strictlyBefore = false}) {
  var d = dayOf(now);
  var back = (d.weekday - weekday) % 7;
  if (back == 0 && strictlyBefore) back = 7;
  return DateTime(d.year, d.month, d.day - back);
}

/// A single day mentioned in text, e.g. when adding an expense. Null means "not mentioned".
DateTime? parseDate(String input, DateTime now) {
  final t = input.toLowerCase();
  if (RegExp(r'\bday before yesterday\b').hasMatch(t)) return dayOf(now).subtract(const Duration(days: 2));
  if (RegExp(r'\byesterday\b').hasMatch(t)) return dayOf(now).subtract(const Duration(days: 1));
  if (RegExp(r'\b(today|tonight|this morning|this evening)\b').hasMatch(t)) return dayOf(now);
  final ago = RegExp(r'\b(\d+|a|one|two|three|four|five|six|seven|ten)\s+(day|week)s?\s+ago\b').firstMatch(t);
  if (ago != null) {
    final n = _num(ago.group(1)!) ?? 1;
    return dayOf(now).subtract(Duration(days: ago.group(2) == 'week' ? n * 7 : n));
  }
  for (var i = 0; i < 7; i++) {
    final m = RegExp('\\b(last\\s+|on\\s+|this\\s+)?${_weekdays[i]}\\b').firstMatch(t);
    if (m != null) return _lastWeekday(i + 1, now, strictlyBefore: (m.group(1) ?? '').startsWith('last'));
  }
  return _parseDayMonth(t, now);
}

/// A period mentioned in a question ("last week", "in march", "between 1 jan and 15 jan").
DateRange? parseRange(String input, DateTime now) {
  final t = input.toLowerCase();
  final today = dayOf(now);

  // explicit ranges
  final between = RegExp(r'\b(?:between|from)\s+(.+?)\s+(?:and|to|till|until|-)\s+(.+?)(?:\?|$|\s+(?:on|in|for)\b)').firstMatch(t);
  if (between != null) {
    final a = parseDate(between.group(1)!, now);
    final b = parseDate(between.group(2)!, now);
    if (a != null && b != null) {
      final start = a.isBefore(b) ? a : b;
      final end = a.isBefore(b) ? b : a;
      return DateRange(start, end.add(const Duration(days: 1)), '${DateFormat('d MMM').format(start)} to ${DateFormat('d MMM').format(end)}');
    }
  }

  final lastN = RegExp(r'\b(?:last|past|previous)\s+(\d+|two|three|four|five|six|seven|ten|fifteen|thirty)\s+(day|week|month)s?\b').firstMatch(t);
  if (lastN != null) {
    final n = _num(lastN.group(1)!) ?? 1;
    switch (lastN.group(2)) {
      case 'day':
        return DateRange.lastDays(n, now);
      case 'week':
        return DateRange(DateTime(today.year, today.month, today.day - n * 7 + 1), today.add(const Duration(days: 1)), 'the last $n weeks');
      case 'month':
        return DateRange(DateTime(now.year, now.month - n + 1, 1), today.add(const Duration(days: 1)), 'the last $n months');
    }
  }

  if (RegExp(r'\bday before yesterday\b').hasMatch(t)) return DateRange.day(today.subtract(const Duration(days: 2)), 'the day before yesterday');
  if (RegExp(r'\byesterday\b').hasMatch(t)) return DateRange.day(today.subtract(const Duration(days: 1)), 'yesterday');
  if (RegExp(r'\b(today|tonight)\b').hasMatch(t)) return DateRange.today(now);

  if (RegExp(r'\b(last|previous)\s+weekend\b').hasMatch(t)) {
    final sat = _lastWeekday(6, now, strictlyBefore: true);
    final s = now.weekday >= 6 ? sat.subtract(const Duration(days: 7)) : sat;
    return DateRange(s, s.add(const Duration(days: 2)), 'last weekend');
  }
  if (RegExp(r'\b(this\s+)?weekend\b').hasMatch(t)) {
    final sat = now.weekday >= 6 ? _lastWeekday(6, now) : _lastWeekday(6, now, strictlyBefore: true);
    return DateRange(sat, sat.add(const Duration(days: 2)), now.weekday >= 6 ? 'this weekend' : 'last weekend');
  }

  if (RegExp(r'\b(last|previous)\s+week\b').hasMatch(t)) return DateRange.week(now, -1);
  if (RegExp(r'\b(this|current)\s+week\b|\bweekly\b').hasMatch(t)) return DateRange.week(now);
  if (RegExp(r'\b(last|previous)\s+month\b').hasMatch(t)) return DateRange.month(now, -1);
  if (RegExp(r'\b(this|current)\s+month\b|\bmonthly\b').hasMatch(t)) return DateRange.month(now);
  if (RegExp(r'\b(last|previous)\s+year\b').hasMatch(t)) return DateRange.year(now, -1);
  if (RegExp(r'\b(this|current)\s+year\b|\byearly\b|\bannual').hasMatch(t)) return DateRange.year(now);
  if (RegExp(r'\b(all time|ever|overall|total ever|so far)\b').hasMatch(t)) return DateRange(DateTime(2000), today.add(const Duration(days: 1)), 'all time');

  // a specific day ("on 5 march", "on monday")
  final weekdayMatch = RegExp('\\b(last\\s+|on\\s+)?(${_weekdays.join('|')})\\b').firstMatch(t);
  if (weekdayMatch != null) {
    final d = _lastWeekday(_weekdays.indexOf(weekdayMatch.group(2)!) + 1, now, strictlyBefore: (weekdayMatch.group(1) ?? '').startsWith('last'));
    return DateRange.day(d, 'on ${DateFormat('EEEE d MMM').format(d)}');
  }
  if (RegExp('\\b\\d{1,2}(st|nd|rd|th)?\\s+(of\\s+)?$_monthPattern|\\b$_monthPattern\\s+\\d{1,2}(st|nd|rd|th)?\\b(?!\\d)|\\b\\d{1,2}[/-]\\d{1,2}\\b|\\b\\d{1,2}(st|nd|rd|th)\\b').hasMatch(t) &&
      !RegExp('\\b$_monthPattern\\s+\\d{4}\\b').hasMatch(t)) {
    final d = _parseDayMonth(t, now);
    if (d != null) return DateRange.day(d, 'on ${DateFormat('d MMM').format(d)}');
  }

  // a whole month ("in march", "march 2025")
  final monthMatch = RegExp('\\b$_monthPattern(?:\\s+(\\d{4}))?\\b').firstMatch(t);
  if (monthMatch != null && !(monthMatch.group(1) == 'may' && !RegExp(r'\bin may\b|\bmay\s+\d{4}').hasMatch(t))) {
    final month = _month(monthMatch.group(1)!);
    var year = monthMatch.group(2) != null ? int.parse(monthMatch.group(2)!) : now.year;
    if (monthMatch.group(2) == null && DateTime(year, month).isAfter(now)) year -= 1;
    final start = DateTime(year, month, 1);
    return DateRange(start, DateTime(year, month + 1, 1), 'in ${DateFormat(year == now.year ? 'MMMM' : 'MMMM yyyy').format(start)}');
  }
  return null;
}
