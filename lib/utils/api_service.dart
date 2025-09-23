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

    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
  }
}
