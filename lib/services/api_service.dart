// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class ApiService {
//   final String baseUrl = "http://192.168.1.10:4000"; // replace with your IP
//   final storage = const FlutterSecureStorage();

//   // Signup
//   Future<Map<String, dynamic>> signup(String name, String email, String password) async {
//     final response = await http.post(
//       Uri.parse("$baseUrl/auth/signup"),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"name": name, "email": email, "password": password}),
//     );
//     return jsonDecode(response.body);
//   }

//   // Login
//   Future<bool> login(String email, String password) async {
//     final response = await http.post(
//       Uri.parse("$baseUrl/auth/login"),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"email": email, "password": password}),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       await storage.write(key: "token", value: data["token"]);
//       return true;
//     }
//     return false;
//   }

//   // Fetch Expenses
//   Future<List<dynamic>> getExpenses() async {
//     final token = await storage.read(key: "token");
//     final response = await http.get(
//       Uri.parse("$baseUrl/expenses"),
//       headers: {"Authorization": "Bearer $token"},
//     );
//     return jsonDecode(response.body);
//   }

//   // Add Expense
//   Future<Map<String, dynamic>> addExpense(String title, double amount, String category, String date, {String? note}) async {
//     final token = await storage.read(key: "token");
//     final response = await http.post(
//       Uri.parse("$baseUrl/expenses"),
//       headers: {
//         "Authorization": "Bearer $token",
//         "Content-Type": "application/json"
//       },
//       body: jsonEncode({
//         "title": title,
//         "amount": amount,
//         "category": category,
//         "date": date,
//         "note": note
//       }),
//     );
//     return jsonDecode(response.body);
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://192.168.1.7/";

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );

    return {"status": response.statusCode, "body": jsonDecode(response.body)};
  }
}
