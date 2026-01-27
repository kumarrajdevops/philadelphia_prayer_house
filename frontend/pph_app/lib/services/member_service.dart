import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';

class MemberService {
  /// Get all members with optional search and filters
  static Future<List<Map<String, dynamic>>> getMembers({
    String? search,
    String? role,
    bool? isActive,
    bool? isDeleted,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // If no headers (user logged out), return empty list immediately
      if (headers == null) {
        return [];
      }
      
      final queryParams = <String, String>{};
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (role != null && role.isNotEmpty) {
        queryParams['role'] = role;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }
      if (isDeleted != null) {
        queryParams['is_deleted'] = isDeleted.toString();
      }
      
      final uri = ApiClient.uri("/members", queryParams: queryParams);
      final res = await http.get(uri, headers: headers);
      
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get members failed: ${res.statusCode} - ${res.body}");
        throw Exception("Failed to load members");
      }
    } catch (e) {
      print("Get members error: $e");
      rethrow;
    }
  }

  /// Get detailed member information
  static Future<Map<String, dynamic>?> getMemberDetails(int memberId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/members/$memberId"),
        headers: headers,
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("Get member details failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Get member details error: $e");
      return null;
    }
  }

  /// Update member details
  static Future<Map<String, dynamic>?> updateMember(
    int memberId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.put(
        ApiClient.uri("/members/$memberId"),
        headers: headers,
        body: jsonEncode(updates),
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to update member");
      }
    } catch (e) {
      print("Update member error: $e");
      rethrow;
    }
  }

  /// Block a member
  static Future<bool> blockMember(int memberId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        ApiClient.uri("/members/$memberId/block"),
        headers: headers,
      );
      
      if (res.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to block member");
      }
    } catch (e) {
      print("Block member error: $e");
      rethrow;
    }
  }

  /// Unblock a member
  static Future<bool> unblockMember(int memberId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        ApiClient.uri("/members/$memberId/unblock"),
        headers: headers,
      );
      
      if (res.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(res.body);
        throw Exception(error["detail"] ?? "Failed to unblock member");
      }
    } catch (e) {
      print("Unblock member error: $e");
      rethrow;
    }
  }

  /// Get member's prayer requests
  static Future<List<Map<String, dynamic>>> getMemberPrayerRequests(int memberId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/members/$memberId/prayer-requests"),
        headers: headers,
      );
      
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get member prayer requests failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get member prayer requests error: $e");
      return [];
    }
  }

  /// Get member's attendance history
  static Future<List<Map<String, dynamic>>> getMemberAttendance(int memberId) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        ApiClient.uri("/members/$memberId/attendance"),
        headers: headers,
      );
      
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get member attendance failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get member attendance error: $e");
      return [];
    }
  }
}
