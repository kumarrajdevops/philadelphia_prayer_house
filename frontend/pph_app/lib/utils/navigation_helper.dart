import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pastor/pastor_shell.dart';
import '../member/member_home_screen.dart';

class NavigationHelper {
  /// Navigate to appropriate home screen based on user role
  static Future<void> navigateToHome(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString("role");
    final isPastor = role == "pastor" || role == "admin";

    if (!context.mounted) return;

    if (isPastor) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PastorShell()),
        (_) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MemberHomeScreen()),
        (_) => false,
      );
    }
  }
}

