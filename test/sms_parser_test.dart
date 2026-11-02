import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

DetectedTxn? parse(String body, {String from = 'VM-HDFCBK'}) => parseTransactionSms(SmsMessage(from, body, DateTime(2026, 10, 29, 21, 30)));

void main() {
  test('UPI debit with VPA and ref', () {
    final t = parse('Rs.250.00 debited from A/c XX1234 on 29-10-26 to VPA swiggy@icici (UPI Ref No 429812345678). Not you? Call 18002586161')!;
    expect(t.type, TxnType.expense);
    expect(t.amount, 250);
    expect(t.merchant, 'Swiggy');
    expect(t.category, 'Food');
    expect(t.ref, 'sms:429812345678');
  });

  test('card spend at merchant, ignores available balance', () {
    final t = parse('INR 1,499.00 spent on HDFC Bank Card x4321 at AMAZON PAY INDIA on 2026-10-29:21:12:03. Avl Lmt: INR 85,000.00')!;
    expect(t.amount, 1499);
    expect(t.merchant, 'Amazon Pay India');
    expect(t.category, 'Shopping');
  });

  test('SBI style UPI debit', () {
    final t = parse('Dear UPI user A/C X5678 debited by 340.0 on date 29Oct26 trf to UBER INDIA Refno 512345678901. If not u? call 1800111109. -SBI',
        from: 'AX-SBIINB');
    expect(t!.amount, 340);
    expect(t.merchant, 'Uber India');
    expect(t.category, 'Transport');
  });

  test('salary credit', () {
    final t = parse('Your A/c XX1234 is credited with INR 52,000.00 on 01-10-26 by NEFT SALARY ACME CORP. Avl Bal: INR 60,120.50')!;
    expect(t.type, TxnType.income);
    expect(t.amount, 52000);
    expect(t.category, 'Salary');
  });

  test('received money from person', () {
    final t = parse('You have received Rs 500 from rahul.k@okaxis on 29-10-26. UPI Ref 512399998888', from: 'JD-PAYTMB')!;
    expect(t.type, TxnType.income);
    expect(t.merchant, 'Rahul K');
  });

  test('refund', () {
    final t = parse('Refund of Rs. 799.00 for your order has been credited to your account. Ref 778899AABB', from: 'AD-ICICIB')!;
    expect(t.type, TxnType.income);
    expect(t.category, 'Refund');
  });

  test('ignores OTP, reminders, promos, failed, and personal numbers', () {
    expect(parse('123456 is your OTP for txn of Rs 2,000 at FLIPKART. Do not share.'), isNull);
    expect(parse('Your credit card bill of Rs 5,400 is due on 05-11-26.'), isNull);
    expect(parse('Get a pre-approved loan of Rs 5,00,000. Apply now!'), isNull);
    expect(parse('Txn of Rs 300 at ZOMATO failed.'), isNull);
    expect(parse('Rs 500 debited, call me', from: '+919876543210'), isNull);
    expect(parse('Rahul has requested Rs 200 from you on Google Pay.'), isNull);
  });

  test('duplicate messages without a ref share a hash', () {
    final a = parse('Rs 99 debited at NETFLIX COM on 29-10.')!;
    final b = parse('Rs 99 debited at NETFLIX COM on 29-10.')!;
    expect(a.ref, b.ref);
    expect(a.ref, startsWith('smsh:'));
    expect(a.category, 'Subscriptions');
  });

  group('unclear payments', () {
    const toPerson = 'Rs 450.00 debited from A/c XX1234 to VPA ramesh.k@okhdfc on 02-11-26. UPI Ref No 600011112222';

    test('payment to a person needs details, a known merchant does not', () {
      expect(parse(toPerson)!.needsDetails, isTrue);
      expect(parse('Rs.250.00 debited from A/c XX1234 to VPA swiggy@icici (UPI Ref No 429812345678)')!.needsDetails, isFalse);
    });

    DetectedTxn answered(String? label, String? category) =>
        parseTransactionSms(SmsMessage('VM-HDFCBK', toPerson, DateTime(2026, 11, 2), label: label, labelCategory: category))!;

    test('a typed name from the notification sets title and category', () {
      final t = answered('lunch with team', null);
      expect(t.merchant, 'Lunch with team');
      expect(t.category, 'Food');
      expect(t.needsDetails, isFalse);
    });

    test('plural names still map to a category', () {
      expect(answered('vegetables', null).category, 'Groceries');
      expect(answered('medicines', null).category, 'Health');
    });

    test('a tapped category button is enough', () {
      final t = answered(null, 'Shopping');
      expect(t.category, 'Shopping');
      expect(t.merchant, 'Ramesh K');
      expect(t.needsDetails, isFalse);
    });

    test('a name we cannot categorise still asks in the app, keeping the name', () {
      final t = answered('stuff for didi', null);
      expect(t.merchant, 'Stuff for didi');
      expect(t.needsDetails, isTrue);
    });

    test('keyword list for the native side covers merchants', () {
      expect(categoryWordList(), containsAll(['swiggy', 'uber', 'salary']));
    });
  });
}
