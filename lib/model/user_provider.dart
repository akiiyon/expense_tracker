import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  late int _userId;
  late String _username;
  late String _email;

  int? get userId => _userId;
  String? get username => _username;
  String? get email => _email;

  void setUser(int id, String name, String mail) {
    _userId = id;
    _username = name;
    _email = mail;
    notifyListeners();
  }
}
