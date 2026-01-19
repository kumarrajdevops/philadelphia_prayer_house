import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';
import '../auth/auth_service.dart';

class EngagementService {
  /// Record attendance when member taps "JOIN NOW"
  /// Silent, non-intrusive tracking - no UI friction
  static Future<bool> recordAttendance({
    int? prayerOccurrenceId,
    int? eventOccurrenceId,
  }) async {
    try {
      if (prayerOccurrenceId == null && eventOccurrenceId == null) {
        return false;
      }

      // Check if user is logged in first
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        print("Warning: User not logged in - cannot record attendance");
        return false;
      }

      final headers = await ApiClient.authHeaders();
      
      // Double-check: Verify Authorization header is present
      if (!headers.containsKey("Authorization")) {
        print("Warning: No authorization token found for attendance recording");
        return false;
      }

      final body = jsonEncode({
        if (prayerOccurrenceId != null) "prayer_occurrence_id": prayerOccurrenceId,
        if (eventOccurrenceId != null) "event_occurrence_id": eventOccurrenceId,
      });

      final res = await http.post(
        ApiClient.uri("/attendance"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return true;
      } else {
        // Log error for debugging (but don't show to user)
        print("Attendance recording failed: ${res.statusCode} - ${res.body}");
        return false;
      }
    } catch (e) {
      // Silent failure - don't interrupt user flow, but log for debugging
      print("Record attendance error: $e");
      return false;
    }
  }

  /// Add a prayer or event series to favorites
  static Future<Map<String, dynamic>?> addFavorite({
    int? prayerSeriesId,
    int? eventSeriesId,
  }) async {
    try {
      if (prayerSeriesId == null && eventSeriesId == null) {
        return null;
      }

      final headers = await ApiClient.authHeaders();
      final body = jsonEncode({
        if (prayerSeriesId != null) "prayer_series_id": prayerSeriesId,
        if (eventSeriesId != null) "event_series_id": eventSeriesId,
      });

      final res = await http.post(
        ApiClient.uri("/favorites"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Add favorite failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Add favorite error: $e");
      return null;
    }
  }

  /// Remove a favorite
  static Future<bool> removeFavorite(int favoriteId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.delete(
        ApiClient.uri("/favorites/$favoriteId"),
        headers: headers,
      );

      return res.statusCode == 204;
    } catch (e) {
      print("Remove favorite error: $e");
      return false;
    }
  }

  /// Get all favorites for the current user
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/favorites"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      } else {
        print("Get favorites failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get favorites error: $e");
      return [];
    }
  }

  /// Create or update a reminder setting
  static Future<Map<String, dynamic>?> setReminder({
    int? prayerSeriesId,
    int? eventSeriesId,
    required int remindBeforeMinutes, // 15 or 5
    required bool isEnabled,
  }) async {
    try {
      if (remindBeforeMinutes != 15 && remindBeforeMinutes != 5) {
        return null;
      }

      if (prayerSeriesId == null && eventSeriesId == null) {
        return null;
      }

      final headers = await ApiClient.authHeaders();
      final body = jsonEncode({
        if (prayerSeriesId != null) "prayer_series_id": prayerSeriesId,
        if (eventSeriesId != null) "event_series_id": eventSeriesId,
        "remind_before_minutes": remindBeforeMinutes,
        "is_enabled": isEnabled,
      });

      final res = await http.post(
        ApiClient.uri("/reminders"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Set reminder failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Set reminder error: $e");
      return null;
    }
  }

  /// Update reminder setting (toggle on/off)
  static Future<bool> updateReminder(int reminderId, bool isEnabled) async {
    try {
      final headers = await ApiClient.authHeaders();
      final body = jsonEncode({
        "is_enabled": isEnabled,
      });

      final res = await http.put(
        ApiClient.uri("/reminders/$reminderId"),
        headers: headers,
        body: body,
      );

      return res.statusCode == 200;
    } catch (e) {
      print("Update reminder error: $e");
      return false;
    }
  }

  /// Get all reminder settings for the current user
  static Future<List<Map<String, dynamic>>> getReminders() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/reminders"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      } else {
        print("Get reminders failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get reminders error: $e");
      return [];
    }
  }

  /// Submit a prayer request
  static Future<Map<String, dynamic>?> submitPrayerRequest({
    required String requestText,
    required String requestType, // "public" or "private"
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final body = jsonEncode({
        "request_text": requestText,
        "request_type": requestType,
      });

      final res = await http.post(
        ApiClient.uri("/prayer-requests"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Submit prayer request failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Submit prayer request error: $e");
      return null;
    }
  }

  /// Get all prayer requests (pastor only)
  static Future<List<Map<String, dynamic>>> getPrayerRequests({String? statusFilter}) async {
    try {
      final headers = await ApiClient.authHeaders();
      final uri = statusFilter != null
          ? ApiClient.uri("/prayer-requests?status_filter=$statusFilter")
          : ApiClient.uri("/prayer-requests");

      final res = await http.get(
        uri,
        headers: headers,
      );

      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      } else {
        print("Get prayer requests failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get prayer requests error: $e");
      return [];
    }
  }

  /// Get current user's own prayer requests (members only)
  static Future<List<Map<String, dynamic>>> getMyPrayerRequests() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/prayer-requests/my"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      } else {
        print("Get my prayer requests failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get my prayer requests error: $e");
      return [];
    }
  }

  /// Get a specific prayer request by ID
  static Future<Map<String, dynamic>?> getPrayerRequestById(int requestId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/prayer-requests/$requestId"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Get prayer request failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Get prayer request error: $e");
      return null;
    }
  }

  /// Update prayer request status (pastor only)
  static Future<bool> updatePrayerRequestStatus(int requestId, String status) async {
    try {
      if (status != "new" && status != "prayed" && status != "archived") {
        return false;
      }

      final headers = await ApiClient.authHeaders();
      final body = jsonEncode({
        "status": status,
      });

      final res = await http.put(
        ApiClient.uri("/prayer-requests/$requestId"),
        headers: headers,
        body: body,
      );

      return res.statusCode == 200;
    } catch (e) {
      print("Update prayer request status error: $e");
      return false;
    }
  }
}
