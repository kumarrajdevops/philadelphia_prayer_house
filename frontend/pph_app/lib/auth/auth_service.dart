import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_client.dart';

class AuthService {
  static Future<bool> login(String username, String password) async {
    final res = await http.post(
      ApiClient.uri("/auth/login"),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: "username=$username&password=$password",
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access_token", data["access_token"]);
      await prefs.setString("refresh_token", data["refresh_token"]);
      await prefs.setString("user_id", data["user_id"].toString());
      await prefs.setString("username", data["username"]);
      await prefs.setString("role", data["role"]);
      return true;
    }
    return false;
  }

  static Future<bool> requestOtp(String value) async {
    final body = value.contains("@")
        ? jsonEncode({"email": value})
        : jsonEncode({"phone": value});

    final res = await http.post(
      ApiClient.uri("/auth/otp/request"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    return res.statusCode == 200;
  }

  static Future<bool> verifyOtp(
    String value,
    String otpCode,
    String? name,
    String? username,
    String? emailOptional,
    String? password,
  ) async {
    final body = <String, dynamic>{
      value.contains("@") ? "email" : "phone": value,
      "otp_code": otpCode,
    };

    // Add name and username for new user registration
    if (name != null && name.isNotEmpty) {
      body["name"] = name;
    }
    if (username != null && username.isNotEmpty) {
      body["username"] = username;
    }
    // Add optional email for registration
    if (emailOptional != null && emailOptional.trim().isNotEmpty) {
      body["email_optional"] = emailOptional.trim();
    }
    // Add optional password for future password-based login
    if (password != null && password.trim().isNotEmpty) {
      body["password"] = password.trim();
    }

    final res = await http.post(
      ApiClient.uri("/auth/otp/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access_token", data["access_token"]);
      await prefs.setString("refresh_token", data["refresh_token"]);
      await prefs.setString("user_id", data["user_id"].toString());
      await prefs.setString("username", data["username"]);
      await prefs.setString("role", data["role"]);
      return true;
    } else {
      // Try to parse error message from backend
      try {
        final errorData = jsonDecode(res.body);
        throw Exception(errorData["detail"] ?? "Verification failed");
      } catch (e) {
        rethrow;
      }
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
    await prefs.remove("user_id");
    await prefs.remove("username");
    await prefs.remove("role");
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("access_token") != null;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("role");
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("username");
  }
}

