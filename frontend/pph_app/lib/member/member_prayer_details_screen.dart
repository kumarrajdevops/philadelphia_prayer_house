import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MemberPrayerDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> prayer;

  const MemberPrayerDetailsScreen({
    super.key,
    required this.prayer,
  });

  String _formatTime(BuildContext context, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "TBD";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final time = TimeOfDay(hour: hour, minute: minute);
        return time.format(context);
      }
    } catch (e) {
      print("Error parsing time: $e");
    }
    return timeStr;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "TBD";
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        return DateFormat('EEEE, MMMM d, y').format(date);
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
    return dateStr;
  }

  Widget _buildStatusTag(String status) {
    String displayText;
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'ongoing':
        displayText = 'LIVE NOW';
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        break;
      case 'completed':
        displayText = 'COMPLETED';
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        break;
      case 'upcoming':
      default:
        displayText = 'UPCOMING';
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        break;
    }

    if (status.toLowerCase() == 'ongoing') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[600]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withAlpha((255 * 0.2).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.red[700]!,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(BuildContext context, String location) async {
    try {
      final encodedLocation = Uri.encodeComponent(location);
      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
      
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open Google Maps"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening Google Maps: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String joinInfo) async {
    try {
      Uri whatsappUrl;
      final cleanInfo = joinInfo.trim();
      if (RegExp(r'^\+?[0-9]{10,}$').hasMatch(cleanInfo)) {
        final phoneNumber = cleanInfo.replaceAll(RegExp(r'[^\d]'), '');
        whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');
      } else if (cleanInfo.startsWith('http://') || cleanInfo.startsWith('https://')) {
        whatsappUrl = Uri.parse(cleanInfo);
      } else if (cleanInfo.startsWith('wa.me/') || cleanInfo.startsWith('chat.whatsapp.com/')) {
        whatsappUrl = Uri.parse('https://$cleanInfo');
      } else {
        final phoneMatch = RegExp(r'\+?[0-9]{10,}').firstMatch(cleanInfo);
        if (phoneMatch != null) {
          final phoneNumber = phoneMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
          whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');
        } else {
          throw Exception("Invalid WhatsApp join information format");
        }
      }
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open WhatsApp"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening WhatsApp: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _computeStatus(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) {
      return 'upcoming';
    }
    
    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.parse(startStr).toUtc();
      final end = DateTime.parse(endStr).toUtc();
      
      if (now.isBefore(start)) {
        return 'upcoming';
      } else if (now.isBefore(end)) {
        return 'ongoing';
      } else {
        return 'completed';
      }
    } catch (e) {
      // Fallback to status from prayer object if parsing fails
      return (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = prayer['title'] as String? ?? 'Prayer';
    final startStr = prayer['start_datetime'] as String?;
    final endStr = prayer['end_datetime'] as String?;
    // Compute status dynamically based on current time
    final status = _computeStatus(startStr, endStr);
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final joinInfo = prayer['join_info'] as String?;

    String dateDisplay = "TBD";
    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          dateDisplay = DateFormat('MMM d, y').format(start);
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          dateDisplay = "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}";
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        }
      } catch (e) {
        dateDisplay = "TBD";
        timeDisplay = "$startStr - $endStr";
      }
    } else if (startStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        dateDisplay = DateFormat('MMM d, y').format(start);
        timeDisplay = DateFormat('h:mm a').format(start);
      } catch (e) {
        dateDisplay = "TBD";
        timeDisplay = startStr;
      }
    }

    final isLive = status == 'ongoing';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Details"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section with Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isLive ? Colors.red[50] : Colors.blue[50],
                border: isLive
                    ? Border(
                        bottom: BorderSide(color: Colors.red[400]!, width: 2),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusTag(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Prayer Type Badge
                      if (prayerType == 'online')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 6),
                              Text(
                                'Online Prayer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 6),
                              Text(
                                'Offline Prayer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  _buildInfoRow(
                    Icons.calendar_today,
                    "Date",
                    dateDisplay,
                  ),
                  const Divider(),

                  // Time
                  _buildInfoRow(
                    Icons.access_time,
                    "Time",
                    timeDisplay,
                  ),
                  const Divider(),

                  // Location or Join Info
                  if (prayerType == 'offline')
                    _buildInfoRow(
                      Icons.location_on,
                      "Location",
                      location ?? "Location TBD",
                    )
                  else
                    _buildInfoRow(
                      Icons.chat,
                      "Join via WhatsApp",
                      joinInfo ?? "Join information not available",
                      valueColor: Colors.green[700],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isLive && ((prayerType == 'offline' && location != null && location.isNotEmpty) ||
            (prayerType == 'online' && joinInfo != null && joinInfo.isNotEmpty))
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: prayerType == 'offline' && location != null && location.isNotEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => _openGoogleMaps(context, location),
                        icon: const Icon(Icons.map),
                        label: const Text("Open in Google Maps"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(context, joinInfo!),
                        icon: const Icon(Icons.chat),
                        label: const Text("Join via WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
              ),
            )
          : (status == 'upcoming' && ((prayerType == 'offline' && location != null && location.isNotEmpty) ||
                (prayerType == 'online' && joinInfo != null && joinInfo.isNotEmpty)))
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: prayerType == 'offline' && location != null && location.isNotEmpty
                        ? ElevatedButton.icon(
                            onPressed: () => _openGoogleMaps(context, location),
                            icon: const Icon(Icons.map),
                            label: const Text("Open in Google Maps"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _openWhatsApp(context, joinInfo!),
                            icon: const Icon(Icons.chat),
                            label: const Text("Join via WhatsApp"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                  ),
                )
              : null,
    );
  }
}

