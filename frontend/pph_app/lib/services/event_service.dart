import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';

class EventService {
  /// Preview event occurrences before creation
  static Future<List<Map<String, dynamic>>> previewEventOccurrences({
    required String title,
    String? description,
    required String eventType,
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
      
      final body = jsonEncode({
        "title": title,
        "description": description,
        "event_type": eventType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetime.toUtc().toIso8601String(),
        "end_datetime": endDatetime.toUtc().toIso8601String(),
        "recurrence_type": recurrenceType,
        "recurrence_days": recurrenceDays,
        "recurrence_end_date": recurrenceEndDate,
        "recurrence_count": recurrenceCount,
      });

      final res = await http.post(
        ApiClient.uri("/events/preview"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> occurrences = data["occurrences"];
        return occurrences.cast<Map<String, dynamic>>();
      } else {
        print("Preview event failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Preview event error: $e");
      return [];
    }
  }

  /// Create a new event
  static Future<Map<String, dynamic>?> createEvent({
    required String title,
    String? description,
    required String eventType,
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
      
      final body = jsonEncode({
        "title": title,
        "description": description,
        "event_type": eventType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetime.toUtc().toIso8601String(),
        "end_datetime": endDatetime.toUtc().toIso8601String(),
        "recurrence_type": recurrenceType,
        "recurrence_days": recurrenceDays,
        "recurrence_end_date": recurrenceEndDate,
        "recurrence_count": recurrenceCount,
      });

      final res = await http.post(
        ApiClient.uri("/events"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Create event failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Create event error: $e");
      rethrow;
    }
  }

  /// Get all event occurrences
  /// tab: "today", "upcoming", "past", or null for all
  static Future<List<Map<String, dynamic>>> getEventOccurrences({String? tab}) async {
    try {
      final queryParam = tab != null ? "?tab=$tab" : "";
      final res = await http.get(
        ApiClient.uri("/events/occurrences$queryParam"),
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get events failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get events error: $e");
      return [];
    }
  }

  /// Get a single event occurrence by ID
  static Future<Map<String, dynamic>?> getEventOccurrence(int occurrenceId) async {
    try {
      final res = await http.get(
        ApiClient.uri("/events/occurrences/$occurrenceId"),
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Get event failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Get event error: $e");
      return null;
    }
  }

  /// Update an event occurrence
  static Future<Map<String, dynamic>?> updateEventOccurrence({
    required int occurrenceId,
    required String title,
    String? description,
    required String eventType,
    String? location,
    String? joinInfo,
    required DateTime startDatetime,
    required DateTime endDatetime,
    bool applyToFuture = false,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      final queryParam = applyToFuture ? "?apply_to_future=true" : "";
      
      final body = jsonEncode({
        "title": title,
        "description": description,
        "event_type": eventType,
        "location": location,
        "join_info": joinInfo,
        "start_datetime": startDatetime.toUtc().toIso8601String(),
        "end_datetime": endDatetime.toUtc().toIso8601String(),
      });

      final res = await http.put(
        ApiClient.uri("/events/occurrences/$occurrenceId$queryParam"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Update event failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Update event error: $e");
      rethrow;
    }
  }

  /// Delete an event occurrence
  static Future<bool> deleteEventOccurrence({
    required int occurrenceId,
    bool deleteFuture = false,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      final queryParam = deleteFuture ? "?delete_future=true" : "";
      
      final res = await http.delete(
        ApiClient.uri("/events/occurrences/$occurrenceId$queryParam"),
        headers: headers,
      );

      return res.statusCode == 204;
    } catch (e) {
      print("Delete event error: $e");
      return false;
    }
  }
}

