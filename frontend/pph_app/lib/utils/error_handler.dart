import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class ErrorHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Track if logout is in progress to prevent multiple simultaneous logouts
  static bool _logoutInProgress = false;

  /// Check if response indicates blocked/deleted user or invalid token and handle accordingly
  static Future<bool> handleResponse(
    BuildContext? context,
    http.Response response,
  ) async {
    // Prevent multiple simultaneous logout attempts
    if (_logoutInProgress) {
      return true; // Already logging out
    }

    // Check for 401 Unauthorized (invalid/expired token) - force logout
    if (response.statusCode == 401) {
      _logoutInProgress = true;
      try {
        // Force logout for any 401 error (invalid token, expired, etc.)
        await AuthService.logout();
        
        String message = "Session expired. Please login again.";
        try {
          final errorData = jsonDecode(response.body);
          message = errorData["detail"] as String? ?? message;
        } catch (e) {
          // Use default message
        }
        
        // Use provided context or navigator key
        final navContext = context ?? navigatorKey.currentContext;
        
        if (navContext != null && navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Navigate to login screen
          Navigator.of(navContext).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      } finally {
        _logoutInProgress = false;
      }
      
      return true; // Indicates user was logged out
    }
    
    // Check for 403 Forbidden (blocked/deleted user)
    if (response.statusCode == 403) {
      try {
        final errorData = jsonDecode(response.body);
        final detail = errorData["detail"] as String? ?? "";
        
        // Check if it's a blocked/deleted account message
        if (detail.contains("blocked") || detail.contains("deleted")) {
          _logoutInProgress = true;
          try {
            // Force logout
            await AuthService.logout();
            
            // Use provided context or navigator key
            final navContext = context ?? navigatorKey.currentContext;
            
            if (navContext != null && navContext.mounted) {
              ScaffoldMessenger.of(navContext).showSnackBar(
                SnackBar(
                  content: Text(detail),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
              
              // Navigate to login screen
              Navigator.of(navContext).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            }
          } finally {
            _logoutInProgress = false;
          }
          
          return true; // Indicates user was logged out
        }
      } catch (e) {
        print("Error parsing blocked user response: $e");
      }
    }
    
    return false; // No logout needed
  }

  /// Check user status on app resume
  static Future<void> checkUserStatus(BuildContext? context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");
      
      if (token == null) return; // Not logged in
      
      // Make a lightweight API call to check user status
      // Using profile endpoint as it's commonly called
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };
      
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/auth/profile"),
        headers: headers,
      );
      
      // Handle blocked/deleted user
      await handleResponse(context, response);
    } catch (e) {
      // Silently fail - network errors shouldn't force logout
      print("Error checking user status: $e");
    }
  }
}
