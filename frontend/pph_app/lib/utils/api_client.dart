import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'error_handler.dart';

class ApiClient {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<Map<String, String>?> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    
    // Return null if no token (user is logged out) - prevents unnecessary API calls
    if (token == null) {
      return null;
    }
    
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Uri uri(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse("$baseUrl$path");
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  /// Check response for blocked/deleted user errors
  /// Returns true if user was logged out, false otherwise
  static Future<bool> checkResponse(BuildContext? context, http.Response response) async {
    return await ErrorHandler.handleResponse(context, response);
  }

  /// Make an authenticated HTTP request with automatic error handling
  /// Returns the response if successful, null if user was logged out
  static Future<http.Response?> makeAuthenticatedRequest(
    BuildContext? context,
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      
      // Check for 401/403 errors and handle logout
      final wasLoggedOut = await ErrorHandler.handleResponse(context, response);
      if (wasLoggedOut) {
        return null; // User was logged out
      }
      
      return response;
    } catch (e) {
      print("API request error: $e");
      return null;
    }
  }
}

