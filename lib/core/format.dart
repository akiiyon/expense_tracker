import 'package:intl/intl.dart';

final _money0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _money2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

/// ₹1,25,000 style. Shows paise only when there are any.
String money(num value, {bool forceDecimals = false}) {
  final hasPaise = (value * 100).round() % 100 != 0;
  return (forceDecimals || hasPaise ? _money2 : _money0).format(value);
}

/// ₹1.2L / ₹12K, for chart axes.
String moneyCompact(num value) => value.abs() < 1000 ? _money0.format(value) : _compact.format(value);

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String friendlyDay(DateTime d) {
  final today = dayOf(DateTime.now());
  final diff = today.difference(dayOf(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7 && diff > 0) return DateFormat.EEEE().format(d);
  if (d.year == today.year) return DateFormat('d MMM').format(d);
  return DateFormat('d MMM yyyy').format(d);
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
