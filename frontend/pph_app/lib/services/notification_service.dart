import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Background notification handler (must be top-level function)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Handle background notification tap if needed
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _reminderCheckTimer;
  // Store scheduled reminder times as a workaround for Android scheduled notifications not firing
  final Map<int, DateTime> _scheduledReminders = {};

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    // Get system timezone name and set local location
    try {
      // Get the system timezone name
      final timeZoneName = DateTime.now().timeZoneName;
      // Try to get the location - common timezone names
      String? locationName;
      if (timeZoneName.contains('IST') || timeZoneName.contains('India')) {
        locationName = 'Asia/Kolkata';
      } else if (timeZoneName.contains('EST')) {
        locationName = 'America/New_York';
      } else if (timeZoneName.contains('PST')) {
        locationName = 'America/Los_Angeles';
      } else if (timeZoneName.contains('GMT') || timeZoneName.contains('UTC')) {
        locationName = 'UTC';
      }
      
      if (locationName != null) {
        final location = await tz.getLocation(locationName);
        tz.setLocalLocation(location);
      } else {
        // Fallback to UTC if we can't determine
        final location = await tz.getLocation('UTC');
        tz.setLocalLocation(location);
      }
    } catch (e) {
      // Continue anyway - will use system default
    }
    
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (initialized != true) {
      return;
    }

    // Create notification channels for Android
    await _createNotificationChannels();

    // Request permissions for Android 13+
    await _requestPermissions();

    _initialized = true;
    
    // Start periodic check for due reminders (workaround for Android scheduled notifications)
    _startReminderChecker();
  }

  // Periodic check for due reminders (workaround for Android scheduled notifications not firing)
  void _startReminderChecker() {
    _reminderCheckTimer?.cancel();
    // Check every 30 seconds for due reminders
    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndFireDueReminders();
    });
  }

  void _stopReminderChecker() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
  }

  // Check for due reminders and fire them immediately
  Future<void> _checkAndFireDueReminders() async {
    try {
      if (!_initialized || _scheduledReminders.isEmpty) return;

      final now = DateTime.now();
      final dueReminders = <int>[];

      // Check all scheduled reminders
      _scheduledReminders.forEach((reminderId, scheduledTime) {
        // Fire if the scheduled time has passed (with 1 minute buffer)
        if (now.isAfter(scheduledTime.subtract(const Duration(minutes: 1)))) {
          dueReminders.add(reminderId);
        }
      });

      // Fire due reminders
      for (final reminderId in dueReminders) {
        final scheduledTime = _scheduledReminders[reminderId];
        if (scheduledTime == null) continue;

        // Get the pending notification to get title and body
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          try {
            final pendingNotifications = await androidImplementation.pendingNotificationRequests();
            final notification = pendingNotifications.firstWhere(
              (n) => n.id == reminderId,
              orElse: () => throw Exception('Notification not found'),
            );

            // Fire the notification immediately
            await _notifications.show(
              reminderId,
              notification.title,
              notification.body,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'prayer_reminders',
                  'Prayer Reminders',
                  channelDescription: 'Notifications for prayer reminders',
                  importance: Importance.high,
                  priority: Priority.high,
                  enableVibration: true,
                  playSound: true,
                  showWhen: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
            );

            // Cancel the scheduled notification and remove from tracking
            await _notifications.cancel(reminderId);
            _scheduledReminders.remove(reminderId);
          } catch (e) {
            // Notification might have already been cancelled or fired
            _scheduledReminders.remove(reminderId);
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Create prayer reminders channel
      const prayerChannel = AndroidNotificationChannel(
        'prayer_reminders',
        'Prayer Reminders',
        description: 'Notifications for prayer reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      // Create event reminders channel
      const eventChannel = AndroidNotificationChannel(
        'event_reminders',
        'Event Reminders',
        description: 'Notifications for event reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await androidImplementation.createNotificationChannel(prayerChannel);
      await androidImplementation.createNotificationChannel(eventChannel);
    }
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // Check if exact alarms permission is granted
  Future<bool> checkExactAlarmsPermission() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      try {
        // Check if we can schedule exact alarms
        final canSchedule = await androidImplementation.areNotificationsEnabled();
        // Note: There's no direct API to check exact alarms, but we can try to schedule a test
        return canSchedule ?? false;
      } catch (e) {
        print('Error checking exact alarms permission: $e');
        return false;
      }
    }
    return false;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
  }

  Future<void> schedulePrayerReminder({
    required int reminderId,
    required String prayerTitle,
    required DateTime prayerStartTime,
    required int minutesBefore,
  }) async {
    try {
      if (!_initialized) await initialize();

      final reminderTime = prayerStartTime.subtract(Duration(minutes: minutesBefore));
      final now = DateTime.now();
      
      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(now)) {
        return;
      }

      final title = 'Prayer Reminder';
      final body = minutesBefore == 15
          ? '$prayerTitle starts in 15 minutes'
          : '$prayerTitle starts in 5 minutes';

      // Convert to timezone-aware datetime
      // prayerStartTime is already in local time, so we create TZDateTime from it
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

      // Try exact scheduling first, fallback to inexact if needed
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      try {
        await _notifications.zonedSchedule(
          reminderId,
          title,
          body,
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_reminders',
              'Prayer Reminders',
              channelDescription: 'Notifications for prayer reminders',
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: true,
              playSound: true,
              showWhen: true,
              when: scheduledDate.millisecondsSinceEpoch,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        // Store the scheduled time for periodic checking (workaround)
        _scheduledReminders[reminderId] = scheduledDate.toLocal();
      } catch (e) {
        // Fallback to inexact scheduling
        try {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          await _notifications.zonedSchedule(
            reminderId,
            title,
            body,
            scheduledDate,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'prayer_reminders',
                'Prayer Reminders',
                channelDescription: 'Notifications for prayer reminders',
                importance: Importance.high,
                priority: Priority.high,
                enableVibration: true,
                playSound: true,
                showWhen: true,
                when: scheduledDate.millisecondsSinceEpoch,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          _scheduledReminders[reminderId] = scheduledDate.toLocal();
        } catch (e2) {
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> scheduleEventReminder({
    required int reminderId,
    required String eventTitle,
    required DateTime eventStartTime,
    required int minutesBefore,
  }) async {
    try {
      if (!_initialized) await initialize();

      final reminderTime = eventStartTime.subtract(Duration(minutes: minutesBefore));
      final now = DateTime.now();
      
      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(now)) {
        return;
      }

      final title = 'Event Reminder';
      final body = minutesBefore == 15
          ? '$eventTitle starts in 15 minutes'
          : '$eventTitle starts in 5 minutes';

      // Convert to timezone-aware datetime
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

      // Try exact scheduling first, fallback to inexact if needed
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      try {
        await _notifications.zonedSchedule(
          reminderId,
          title,
          body,
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'event_reminders',
              'Event Reminders',
              channelDescription: 'Notifications for event reminders',
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: true,
              playSound: true,
              showWhen: true,
              when: scheduledDate.millisecondsSinceEpoch,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        // Store the scheduled time for periodic checking (workaround)
        _scheduledReminders[reminderId] = scheduledDate.toLocal();
      } catch (e) {
        // Fallback to inexact scheduling
        try {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          await _notifications.zonedSchedule(
            reminderId,
            title,
            body,
            scheduledDate,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'event_reminders',
                'Event Reminders',
                channelDescription: 'Notifications for event reminders',
                importance: Importance.high,
                priority: Priority.high,
                enableVibration: true,
                playSound: true,
                showWhen: true,
                when: scheduledDate.millisecondsSinceEpoch,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          _scheduledReminders[reminderId] = scheduledDate.toLocal();
        } catch (e2) {
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelReminder(int reminderId) async {
    if (!_initialized) await initialize();
    await _notifications.cancel(reminderId);
    _scheduledReminders.remove(reminderId);
  }

  Future<void> cancelAllReminders() async {
    if (!_initialized) await initialize();
    await _notifications.cancelAll();
    _scheduledReminders.clear();
  }

  // Generate unique ID for reminder based on series_id and minutes
  // Prayer: 1000000 + (seriesId * 10) + (minutes == 15 ? 1 : 5)
  // Event: 2000000 + (seriesId * 10) + (minutes == 15 ? 1 : 5)
  static int getPrayerReminderId(int seriesId, int minutesBefore) {
    return 1000000 + (seriesId * 10) + (minutesBefore == 15 ? 1 : 5);
  }

  static int getEventReminderId(int seriesId, int minutesBefore) {
    return 2000000 + (seriesId * 10) + (minutesBefore == 15 ? 1 : 5);
  }

}
