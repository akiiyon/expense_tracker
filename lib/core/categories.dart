import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;
  const CategoryInfo(this.name, this.icon, this.color);
}

/// Must match EXPENSE_CATEGORIES / INCOME_CATEGORIES in backend/lib/finance.js.
const expenseCategories = <CategoryInfo>[
  CategoryInfo('Food', Icons.restaurant_rounded, Color(0xFFFF8A4C)),
  CategoryInfo('Groceries', Icons.local_grocery_store_rounded, Color(0xFF2EC4B6)),
  CategoryInfo('Transport', Icons.directions_car_rounded, Color(0xFF4D96FF)),
  CategoryInfo('Shopping', Icons.shopping_bag_rounded, Color(0xFFFF5CA8)),
  CategoryInfo('Bills', Icons.receipt_long_rounded, Color(0xFFFFB547)),
  CategoryInfo('Rent', Icons.home_rounded, Color(0xFF8D6E63)),
  CategoryInfo('Entertainment', Icons.movie_rounded, Color(0xFF9B5DE5)),
  CategoryInfo('Health', Icons.favorite_rounded, Color(0xFFEF476F)),
  CategoryInfo('Education', Icons.school_rounded, Color(0xFF3A86FF)),
  CategoryInfo('Travel', Icons.flight_takeoff_rounded, Color(0xFF00BBF9)),
  CategoryInfo('Subscriptions', Icons.autorenew_rounded, Color(0xFF7B5CFF)),
  CategoryInfo('Other', Icons.category_rounded, Color(0xFF8E8AA6)),
];

const incomeCategories = <CategoryInfo>[
  CategoryInfo('Salary', Icons.work_rounded, Color(0xFF00C896)),
  CategoryInfo('Freelance', Icons.laptop_mac_rounded, Color(0xFF06D6A0)),
  CategoryInfo('Gift', Icons.card_giftcard_rounded, Color(0xFFFF5CA8)),
  CategoryInfo('Refund', Icons.replay_rounded, Color(0xFF4D96FF)),
  CategoryInfo('Interest', Icons.trending_up_rounded, Color(0xFFFFB547)),
  CategoryInfo('Top-up', Icons.account_balance_wallet_rounded, Color(0xFF6C4BFF)),
  CategoryInfo('Other', Icons.add_card_rounded, Color(0xFF8E8AA6)),
];

CategoryInfo categoryInfo(String name, {bool income = false}) {
  final list = income ? incomeCategories : expenseCategories;
  return list.firstWhere((c) => c.name == name, orElse: () => list.last);
}

/// Words people use for each expense category. Used by xp and the SMS parser.
const categoryKeywords = <String, List<String>>{
  'Food': [
    'food', 'lunch', 'dinner', 'breakfast', 'snack', 'pizza', 'burger', 'biryani', 'coffee', 'chai',
    'tea', 'cafe', 'restaurant', 'swiggy', 'zomato', 'dominos', 'mcdonald', 'kfc', 'starbucks',
    'eat', 'meal', 'dosa', 'momos', 'juice', 'bakery', 'cake', 'icecream', 'ice cream', 'drinks', 'bar', 'beer',
  ],
  'Groceries': [
    'grocery', 'groceries', 'vegetable', 'veggies', 'fruits', 'milk', 'bigbasket', 'blinkit', 'zepto',
    'instamart', 'dmart', 'supermarket', 'kirana', 'eggs', 'bread', 'ration',
  ],
  'Transport': [
    'uber', 'ola', 'rapido', 'cab', 'taxi', 'auto', 'rickshaw', 'metro', 'bus', 'petrol', 'diesel',
    'fuel', 'parking', 'toll', 'fastag', 'commute', 'ride', 'train ticket', 'local train',
  ],
  'Shopping': [
    'shopping', 'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'clothes', 'shoes', 'shirt',
    'jeans', 'dress', 'gadget', 'phone', 'headphones', 'watch', 'bag',
  ],
  'Bills': [
    'bill', 'electricity', 'water bill', 'gas', 'recharge', 'mobile', 'wifi', 'broadband', 'internet',
    'jio', 'airtel', 'vi ', 'bsnl', 'dth', 'emi', 'insurance', 'credit card bill', 'maintenance',
  ],
  'Rent': ['rent', 'pg', 'hostel', 'landlord', 'house rent', 'flat'],
  'Entertainment': [
    'movie', 'movies', 'cinema', 'pvr', 'inox', 'bookmyshow', 'concert', 'game', 'gaming', 'party',
    'club', 'outing', 'bowling', 'event',
  ],
  'Health': [
    'medicine', 'medical', 'doctor', 'hospital', 'pharmacy', 'apollo', 'pharmeasy', '1mg', 'gym',
    'fitness', 'clinic', 'dentist', 'tablets', 'checkup',
  ],
  'Education': ['course', 'books', 'book', 'tuition', 'fees', 'college', 'school', 'udemy', 'exam', 'stationery'],
  'Travel': ['flight', 'hotel', 'trip', 'travel', 'irctc', 'makemytrip', 'goibibo', 'airbnb', 'oyo', 'vacation', 'holiday'],
  'Subscriptions': [
    'netflix', 'spotify', 'prime', 'hotstar', 'youtube premium', 'subscription', 'icloud', 'google one',
    'chatgpt', 'zee5', 'sonyliv', 'apple music',
  ],
};

const incomeKeywords = <String, List<String>>{
  'Salary': ['salary', 'payroll', 'stipend', 'paycheck'],
  'Freelance': ['freelance', 'client', 'project payment', 'invoice', 'gig'],
  'Gift': ['gift', 'birthday money', 'shagun'],
  'Refund': ['refund', 'cashback', 'reversal', 'reversed'],
  'Interest': ['interest', 'dividend'],
};

/// Best-guess category for free text, or null when nothing matches.
String? guessCategory(String text, {bool income = false}) {
  final t = ' ${text.toLowerCase()} ';
  final map = income ? incomeKeywords : categoryKeywords;
  for (final entry in map.entries) {
    for (final word in entry.value) {
      // plurals count too: "vegetables", "medicines"
      if (RegExp('(^|[^a-z])${RegExp.escape(word.trim())}(s|es)?([^a-z]|\$)').hasMatch(t)) return entry.key;
    }
  }
  return null;
}
