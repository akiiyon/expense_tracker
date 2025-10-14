import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  late int _userId;
  late String _username;
  late String _email;

  double _startingBalance = 0.0;
  double _totalSpent = 0.0;

  int? get userId => _userId;
  String? get username => _username;
  String? get email => _email;

  void setUser(int id, String name, String mail, double bal) {
    _userId = id;
    _username = name;
    _email = mail;
    _startingBalance = bal;
    notifyListeners();
  }

  void updateBalance(double newBalance) {
    _startingBalance += newBalance;
    notifyListeners();
  }

  void spend(double amount) {
    _startingBalance -= amount;
    _totalSpent += amount;
    notifyListeners();
  }

  //get current wallet balance
  double get walletBalance => _startingBalance - _totalSpent;
}
