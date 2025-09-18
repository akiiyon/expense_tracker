import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "http://192.168.1.7/api/auth"; // Android Emulator
  // use http://localhost:4000 if running on web
  // or replace with your machine IP if testing on real device

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/signup");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Save token locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);

        return {"success": true, "user": data["user"], "token": data["token"]};
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error["message"] ?? "Signup failed",
        };
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
