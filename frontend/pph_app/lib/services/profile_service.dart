import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_client.dart';

class ProfileService {
  /// Get current user's profile
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/auth/profile"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("Get profile failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Get profile error: $e");
      return null;
    }
  }

  /// Update profile (name, username, email)
  static Future<Map<String, dynamic>?> updateProfile({
    String? name,
    String? username,
    String? email,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final body = <String, dynamic>{};
      if (name != null) body["name"] = name;
      if (username != null) body["username"] = username;
      if (email != null) body["email"] = email;

      final res = await http.put(
        ApiClient.uri("/auth/profile"),
        headers: headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        if (data["name"] != null) await prefs.setString("name", data["name"]);
        if (data["username"] != null) await prefs.setString("username", data["username"]);
        return data;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to update profile");
      }
    } catch (e) {
      print("Update profile error: $e");
      rethrow;
    }
  }

  /// Change password (for users with existing password)
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        ApiClient.uri("/auth/change-password"),
        headers: headers,
        body: jsonEncode({
          "current_password": currentPassword,
          "new_password": newPassword,
        }),
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to change password");
      }
    } catch (e) {
      print("Change password error: $e");
      rethrow;
    }
  }

  /// Set password (for OTP-only users)
  static Future<bool> setPassword(String newPassword) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        ApiClient.uri("/auth/set-password"),
        headers: headers,
        body: jsonEncode({
          "new_password": newPassword,
        }),
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to set password");
      }
    } catch (e) {
      print("Set password error: $e");
      rethrow;
    }
  }

  /// Upload profile picture
  static Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final headers = await ApiClient.authHeaders();
      // Remove Content-Type for multipart/form-data (http package sets it automatically)
      headers.remove("Content-Type");

      // Determine content type from file extension
      MediaType contentType = MediaType("image", "jpeg"); // default
      final extension = imageFile.path.toLowerCase().split('.').last;
      if (extension == "png") {
        contentType = MediaType("image", "png");
      } else if (extension == "webp") {
        contentType = MediaType("image", "webp");
      } else if (extension == "jpg" || extension == "jpeg") {
        contentType = MediaType("image", "jpeg");
      }

      final request = http.MultipartRequest(
        "POST",
        ApiClient.uri("/auth/profile/picture"),
      );
      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          imageFile.path,
          contentType: contentType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["profile_image_url"];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error["detail"] ?? "Failed to upload profile picture");
      }
    } catch (e) {
      print("Upload profile picture error: $e");
      rethrow;
    }
  }

  /// Delete account (soft delete)
  static Future<bool> deleteAccount() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.delete(
        ApiClient.uri("/auth/account"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to delete account");
      }
    } catch (e) {
      print("Delete account error: $e");
      rethrow;
    }
  }
}
