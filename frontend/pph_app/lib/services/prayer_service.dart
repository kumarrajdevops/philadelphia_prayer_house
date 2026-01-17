import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';

class PrayerService {
  /// Create a new prayer
  /// Returns the created prayer data on success, null on failure
  static Future<Map<String, dynamic>?> createPrayer({
    required String title,
    required DateTime prayerDate,
    required DateTime startTime,
    required DateTime endTime,
    required String prayerType, // "online" or "offline"
    String? location, // Required for offline prayers
    String? joinInfo, // Required for online prayers (WhatsApp link/instructions)
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Format date as YYYY-MM-DD
      final dateStr = "${prayerDate.year}-${prayerDate.month.toString().padLeft(2, '0')}-${prayerDate.day.toString().padLeft(2, '0')}";
      
      // Format time as HH:MM:SS
      final startTimeStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
      final endTimeStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
      
      final body = jsonEncode({
        "title": title,
        "prayer_date": dateStr,
        "start_time": startTimeStr,
        "end_time": endTimeStr,
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
      });

      final res = await http.post(
        ApiClient.uri("/prayers"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Create prayer failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Create prayer error: $e");
      rethrow;
    }
  }

  /// Get all prayers
  static Future<List<Map<String, dynamic>>> getAllPrayers() async {
    try {
      final res = await http.get(
        ApiClient.uri("/prayers"),
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get prayers failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get prayers error: $e");
      return [];
    }
  }

  /// Update a prayer by ID
  /// Returns the updated prayer data on success, null on failure
  static Future<Map<String, dynamic>?> updatePrayer({
    required int prayerId,
    required String title,
    required DateTime prayerDate,
    required DateTime startTime,
    required DateTime endTime,
    required String prayerType, // "online" or "offline"
    String? location, // Required for offline prayers
    String? joinInfo, // Required for online prayers (WhatsApp link/instructions)
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Format date as YYYY-MM-DD
      final dateStr = "${prayerDate.year}-${prayerDate.month.toString().padLeft(2, '0')}-${prayerDate.day.toString().padLeft(2, '0')}";
      
      // Format time as HH:MM:SS
      final startTimeStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
      final endTimeStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
      
      final body = jsonEncode({
        "title": title,
        "prayer_date": dateStr,
        "start_time": startTimeStr,
        "end_time": endTimeStr,
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
      });

      final res = await http.put(
        ApiClient.uri("/prayers/$prayerId"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Update prayer failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to update prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to update prayer");
        }
      }
    } catch (e) {
      print("Update prayer error: $e");
      rethrow;
    }
  }

  /// Delete a prayer
  /// Returns true on success, false on failure
  /// Throws exception if prayer has already started
  static Future<bool> deletePrayer(int prayerId) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      final res = await http.delete(
        ApiClient.uri("/prayers/$prayerId"),
        headers: headers,
      );

      if (res.statusCode == 204) {
        return true;
      } else {
        print("Delete prayer failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to delete prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to delete prayer");
        }
      }
    } catch (e) {
      print("Delete prayer error: $e");
      rethrow;
    }
  }

  // =========================
  // Prayer Series Methods (Recurring Prayers)
  // =========================

  /// Preview prayer occurrences before creation
  static Future<List<Map<String, dynamic>>> previewPrayerOccurrences({
    required String title,
    required String prayerType,
    String? location,
    String? joinInfo,
    required DateTime startDatetime,
    required DateTime endDatetime,
    required String recurrenceType,
    String? recurrenceDays,
    String? recurrenceEndDate,
    int? recurrenceCount,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Convert to ISO 8601 format (UTC) for backend
      final startDatetimeStr = startDatetime.toUtc().toIso8601String();
      final endDatetimeStr = endDatetime.toUtc().toIso8601String();
      
      final body = jsonEncode({
        "title": title,
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetimeStr,
        "end_datetime": endDatetimeStr,
        "recurrence_type": recurrenceType,
        "recurrence_days": recurrenceDays,
        "recurrence_end_date": recurrenceEndDate,
        "recurrence_count": recurrenceCount,
      });

      final res = await http.post(
        ApiClient.uri("/prayers/preview"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> occurrences = data["occurrences"];
        return occurrences.cast<Map<String, dynamic>>();
      } else {
        print("Preview prayer failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Preview prayer error: $e");
      return [];
    }
  }

  /// Create a new prayer series
  static Future<Map<String, dynamic>?> createPrayerSeries({
    required String title,
    required String prayerType,
    String? location,
    String? joinInfo,
    required DateTime startDatetime,
    required DateTime endDatetime,
    required String recurrenceType,
    String? recurrenceDays,
    String? recurrenceEndDate,
    int? recurrenceCount,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Convert to ISO 8601 format (UTC) for backend
      final startDatetimeStr = startDatetime.toUtc().toIso8601String();
      final endDatetimeStr = endDatetime.toUtc().toIso8601String();
      
      final body = jsonEncode({
        "title": title,
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetimeStr,
        "end_datetime": endDatetimeStr,
        "recurrence_type": recurrenceType,
        "recurrence_days": recurrenceDays,
        "recurrence_end_date": recurrenceEndDate,
        "recurrence_count": recurrenceCount,
      });

      final res = await http.post(
        ApiClient.uri("/prayers/series"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Create prayer series failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Create prayer series error: $e");
      rethrow;
    }
  }

  /// Get all prayer occurrences
  static Future<List<Map<String, dynamic>>> getPrayerOccurrences({
    String? tab, // "today", "upcoming", "past"
  }) async {
    try {
      final uri = tab != null
          ? ApiClient.uri("/prayers/occurrences?tab=$tab")
          : ApiClient.uri("/prayers/occurrences");
      
      final res = await http.get(
        uri,
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get prayer occurrences failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get prayer occurrences error: $e");
      return [];
    }
  }

  /// Get a prayer occurrence by ID
  static Future<Map<String, dynamic>?> getPrayerOccurrenceById(int occurrenceId) async {
    try {
      final res = await http.get(
        ApiClient.uri("/prayers/occurrences/$occurrenceId"),
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Get prayer occurrence failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Get prayer occurrence error: $e");
      return null;
    }
  }

  /// Update a prayer occurrence
  static Future<Map<String, dynamic>?> updatePrayerOccurrence({
    required int occurrenceId,
    required String title,
    required String prayerType,
    String? location,
    String? joinInfo,
    required DateTime startDatetime,
    required DateTime endDatetime,
    bool applyToFuture = false,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Convert to ISO 8601 format (UTC) for backend
      final startDatetimeStr = startDatetime.toUtc().toIso8601String();
      final endDatetimeStr = endDatetime.toUtc().toIso8601String();
      
      final uri = ApiClient.uri("/prayers/occurrences/$occurrenceId?apply_to_future=$applyToFuture");
      
      final body = jsonEncode({
        "title": title,
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetimeStr,
        "end_datetime": endDatetimeStr,
      });

      final res = await http.put(
        uri,
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Update prayer occurrence failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to update prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to update prayer");
        }
      }
    } catch (e) {
      print("Update prayer occurrence error: $e");
      rethrow;
    }
  }

  /// Delete a prayer occurrence
  static Future<bool> deletePrayerOccurrence({
    required int occurrenceId,
    bool deleteFuture = false,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      final uri = ApiClient.uri("/prayers/occurrences/$occurrenceId?delete_future=$deleteFuture");
      
      final res = await http.delete(
        uri,
        headers: headers,
      );

      if (res.statusCode == 204) {
        return true;
      } else {
        print("Delete prayer occurrence failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to delete prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to delete prayer");
        }
      }
    } catch (e) {
      print("Delete prayer occurrence error: $e");
      rethrow;
    }
  }
}

