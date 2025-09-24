import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:4000";

  //signup api or function
  Future<http.Response> signup(
    String username,
    String email,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/signup");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    return response;
  }

  //signin api or function
  Future<http.Response> signin(String email, String password) async {
    final url = Uri.parse("$baseUrl/signin");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return response;
  }

  Future<http.Response> addExpense(
    int userId,
    String username,
    double amount,
    String category,
  ) async {
    final url = Uri.parse("$baseUrl/addExpense");

    final response = await http.post(
      url,
      headers: {"Conten-Type": "application/json"},
      body: {
        "user_id": userId,
        "username": username,
        "amount": amount,
        "category": category,
      },
    );

    if (response.statusCode == 201) {
      print("Expense added: ${response.body}");
    } else {
      print("Error: ${response.body}");
    }

    return response;
  }
}
