import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/data/models.dart';

class SmsMessage {
  final String address;
  final String body;
  final DateTime date;

  /// What the user typed in the notification's "What was it for?" reply, if anything.
  final String? label;

  /// Category the user picked from the notification's quick buttons, if any.
  final String? labelCategory;

  const SmsMessage(this.address, this.body, this.date, {this.label, this.labelCategory});

  factory SmsMessage.fromMap(Map<dynamic, dynamic> m) => SmsMessage(
        m['address'] as String? ?? '',
        m['body'] as String? ?? '',
        DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        label: (m['label'] as String?)?.trim().isEmpty ?? true ? null : (m['label'] as String).trim(),
        labelCategory: (m['labelCategory'] as String?)?.isEmpty ?? true ? null : m['labelCategory'] as String,
      );
}

/// Merchant names used when the SMS doesn't say who was paid.
const genericMerchants = {'Card / UPI payment', 'Money received'};

/// Every keyword that lets us tell a category from SMS text. Shared with the
/// native receiver so it knows when to ask the user in the notification.
List<String> categoryWordList() => {
      for (final words in categoryKeywords.values) ...words.map((w) => w.trim()),
      for (final words in incomeKeywords.values) ...words.map((w) => w.trim()),
    }.where((w) => w.length > 1).toList();

/// A payment or credit read from a bank / UPI / card SMS.
class DetectedTxn {
  final TxnType type;
  final double amount;
  final String merchant;
  final String category;
  final DateTime date;

  /// Stable id used to skip duplicates (bank reference number when there is one).
  final String ref;
  final String rawBody;

  /// The user already told us what this was (from the notification).
  final bool answered;

  const DetectedTxn({
    required this.type,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.date,
    required this.ref,
    required this.rawBody,
    this.answered = false,
  });

  /// The SMS didn't make clear what this was for, so we should ask.
  bool get needsDetails => !answered && (category == 'Other' || genericMerchants.contains(merchant));

  DetectedTxn withDetails({required String title, required String category}) => DetectedTxn(
        type: type,
        amount: amount,
        merchant: title,
        category: category,
        date: date,
        ref: ref,
        rawBody: rawBody,
        answered: true,
      );

  TxnDraft toDraft() => TxnDraft(
        type: type,
        amount: amount,
        category: category,
        title: merchant,
        date: date,
        note: 'Detected from SMS',
        source: 'sms',
        sourceRef: ref,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'amount': amount,
        'merchant': merchant,
        'category': category,
        'date': date.millisecondsSinceEpoch,
        'ref': ref,
        'body': rawBody,
        'answered': answered,
      };

  factory DetectedTxn.fromJson(Map<String, dynamic> j) => DetectedTxn(
        type: j['type'] == 'income' ? TxnType.income : TxnType.expense,
        amount: (j['amount'] as num).toDouble(),
        merchant: j['merchant'] as String,
        category: j['category'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
        ref: j['ref'] as String,
        rawBody: j['body'] as String? ?? '',
        answered: j['answered'] == true,
      );
}

final _ignore = RegExp(
  r'\b(otp|one[- ]time password|verification code|is due|due on|due date|will be debited|scheduled|reminder|requested|request from|collect request|has requested|failed|declined|unsuccessful|reversed? within|apply now|pre-?approved|offer|win |congratulations|kyc)\b',
  caseSensitive: false,
);
final _debit = RegExp(
  r'\b(debited|spent|paid|sent|withdrawn|withdrawal|purchase|purchased|txn of|transaction of|transferred|deducted|used at|payment of|dr\.?)\b',
  caseSensitive: false,
);
final _credit = RegExp(r'\b(credited|received|deposited|refund(ed)?|cashback of|cr\.?)\b', caseSensitive: false);
final _amount = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
// SBI style: "debited by 340.0" with no currency marker
final _bareAmount = RegExp(r'\b(?:debited|credited)\s+(?:by|with|for)\s+([\d,]+(?:\.\d{1,2})?)\b', caseSensitive: false);
final _balanceBefore = RegExp(r'(bal(ance)?|avl|available|limit|outstanding|total due|min(imum)? due)[\s.:a-z]*$', caseSensitive: false);
final _ref = RegExp(r'\b(?:upi ref(?:erence)?(?: no)?|ref(?:erence)?(?: no| num(?:ber)?)?|rrn|utr|txn ?id|transaction id|imps ref)[\s.:#-]*([a-z0-9]{6,})', caseSensitive: false);

final _merchantPatterns = <RegExp>[
  RegExp(r"\b(?:at|@)\s+([a-z0-9][a-z0-9 &'._*-]{1,40}?)(?=\s+(?:on|via|using|for|ref|refno|txn|avl|dated)\b|\.(?=\s|$)|[,;]|\s*$)", caseSensitive: false),
  RegExp(r'\bvpa\s+([a-z0-9._-]+@[a-z]+)', caseSensitive: false),
  RegExp(r"\b(?:to|trf to|paid to|sent to)\s+(?:vpa\s+)?([a-z0-9][a-z0-9 &'._@-]{1,40}?)(?=\s+(?:on|via|ref|refno|upi|using|from|a/c|ac)\b|\.(?=\s|$)|[,;(]|\s*$)", caseSensitive: false),
  RegExp(r'\binfo[:\s-]+([a-z0-9][a-z0-9 &/._*-]{1,40}?)(?=\.(?=\s|$)|[,;]|\s*$)', caseSensitive: false),
  RegExp(r"\bfrom\s+(?:vpa\s+)?([a-z0-9][a-z0-9 &'._@-]{1,40}?)(?=\s+(?:on|via|ref|refno|upi|to|a/c|ac)\b|\.(?=\s|$)|[,;(]|\s*$)", caseSensitive: false),
];

final _numericSender = RegExp(r'^\+?\d{7,}$');

/// Turns a bank SMS into a transaction, or null when it isn't one.
DetectedTxn? parseTransactionSms(SmsMessage sms) {
  final body = sms.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (body.isEmpty) return null;
  // personal numbers are not banks, and are a common scam vector
  if (_numericSender.hasMatch(sms.address.replaceAll(' ', ''))) return null;
  if (_ignore.hasMatch(body)) return null;

  final isDebit = _debit.hasMatch(body);
  final isCredit = _credit.hasMatch(body);
  if (!isDebit && !isCredit) return null;

  // "debited ... credited to merchant" is a debit; plain "credited to your a/c" is a credit
  final type = isDebit && (!isCredit || _firstIndex(_debit, body) < _firstIndex(_credit, body)) ? TxnType.expense : TxnType.income;

  double? amount;
  for (final m in _amount.allMatches(body)) {
    final before = body.substring((m.start - 25).clamp(0, m.start), m.start);
    if (_balanceBefore.hasMatch(before)) continue;
    amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (amount != null) break;
  }
  if (amount == null) {
    final m = _bareAmount.firstMatch(body);
    if (m != null) amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
  }
  if (amount == null || amount <= 0) return null;

  final merchant = _merchant(body, type);
  final lower = '${merchant.toLowerCase()} ${body.toLowerCase()}';
  final String category;
  if (type == TxnType.income) {
    category = RegExp(r'\bsalary\b').hasMatch(lower)
        ? 'Salary'
        : RegExp(r'\b(refund|reversal|cashback)\b').hasMatch(lower)
            ? 'Refund'
            : RegExp(r'\binterest\b').hasMatch(lower)
                ? 'Interest'
                : 'Other';
  } else {
    category = guessCategory(merchant) ?? guessCategory(body) ?? 'Other';
  }

  final refMatch = _ref.firstMatch(body);
  final ref = refMatch != null ? 'sms:${refMatch.group(1)!.toUpperCase()}' : 'smsh:${_hash('${sms.address}|$body')}';

  final detected = DetectedTxn(type: type, amount: amount, merchant: merchant, category: category, date: sms.date, ref: ref, rawBody: body);
  return _applyLabel(detected, sms);
}

/// Uses the answer from the notification: a typed name (category guessed from it)
/// and/or a tapped category.
DetectedTxn _applyLabel(DetectedTxn t, SmsMessage sms) {
  final label = sms.label;
  final picked = sms.labelCategory;
  if (label == null && picked == null) return t;
  final income = t.type == TxnType.income;
  final title = label == null ? t.merchant : label[0].toUpperCase() + label.substring(1);
  final category = picked ?? guessCategory(label!, income: income) ?? t.category;
  final known = picked != null || category != 'Other';
  return known ? t.withDetails(title: title, category: category) : DetectedTxn(
        type: t.type,
        amount: t.amount,
        merchant: title,
        category: category,
        date: t.date,
        ref: t.ref,
        rawBody: t.rawBody,
      );
}

int _firstIndex(RegExp r, String s) => r.firstMatch(s)?.start ?? 1 << 30;

String _merchant(String body, TxnType type) {
  for (final p in _merchantPatterns) {
    if (type == TxnType.expense && p.pattern.startsWith(r'\bfrom')) continue;
    final m = p.firstMatch(body);
    if (m == null) continue;
    final cleaned = _cleanMerchant(m.group(1)!);
    if (cleaned != null) return cleaned;
  }
  return type == TxnType.income ? 'Money received' : 'Card / UPI payment';
}

String? _cleanMerchant(String raw) {
  var s = raw.trim();
  // UPI ids: swiggy.food@icici -> Swiggy food
  if (s.contains('@')) s = s.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
  s = s.replaceAll(RegExp(r'\b(a/c|ac|acct|account|xx+\d*|\*+\d+|your|you|upi|vpa|imps|neft|pos|ecom)\b', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'[^a-zA-Z0-9 &.\x27-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length < 2 || RegExp(r'^[\d .-]+$').hasMatch(s)) return null;
  return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}

/// FNV-1a, 32 bit. Stable across runs, unlike String.hashCode.
String _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
