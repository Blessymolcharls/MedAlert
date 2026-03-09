import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/reminder.dart';
import '../models/compartment.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize timezones for scheduled notifications
    tz.initializeTimeZones();

    // 2. Setup initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click route here if needed
      },
    );

    // 3. Android Specific Setup (Channel + Permissions)
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Create high importance channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medalert_high_channel', // id
        'MedAlert Reminders', // name
        description: 'High priority medicine intake reminders',
        importance: Importance.max, // Requires max for heads-up behavior
      );

      await androidImplementation?.createNotificationChannel(channel);

      // Request Android 13 Notification Permissions
      await androidImplementation?.requestNotificationsPermission();

      // Request Exact Alarm permissions (Android 12/13+)
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  // ============== EXAMPLE: INSTANT NOTIFICATION ==============
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medalert_high_channel',
        'MedAlert Reminders',
        channelDescription: 'High priority medicine intake reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  // ============== EXAMPLE: SINGLE SCHEDULED NOTIFICATION ==============
  Future<void> scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medalert_high_channel',
          'MedAlert Reminders',
          channelDescription: 'High priority medicine intake reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ============== IMPLEMENTATION: WEEKLY REMINDER ==============
  Future<void> scheduleWeeklyNotification(Reminder reminder) async {
    for (int dayIndex in reminder.selectedDays) {
      int flutterWeekdayMatch = dayIndex + 1;

      // Compute the absolute next date/time matching this weekday
      tz.TZDateTime scheduledTime = _nextInstanceOfWeekday(
        flutterWeekdayMatch,
        reminder.time,
      );

      int notifId = _generateNotificationId(reminder.id, dayIndex);
      final String foodText = reminder.isAfterFood
          ? "After Food"
          : "Before Food";
      final formattedTimeStr = _formatTimeOfDay(reminder.time);

      final title = "Upcoming Medicine Reminder";
      final body = "${reminder.name} at $formattedTimeStr ($foodText)";

      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medalert_high_channel', // Match channel id perfectly
            'MedAlert Reminders',
            channelDescription: 'High priority medicine intake reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // Timezone helper to find the exact next matching day/time
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, TimeOfDay time) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Timezone helper to check if time has already passed today
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minuteRange = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minuteRange $period";
  }

  int _generateNotificationId(String reminderId, int dayIndex) {
    // Ensuring positive 32-bit integer for ID to satisfy Android requirements
    return (reminderId.hashCode + dayIndex).abs() % 2147483647;
  }

  Future<void> cancelReminderNotifications(Reminder reminder) async {
    for (int dayIndex in reminder.selectedDays) {
      await _plugin.cancel(_generateNotificationId(reminder.id, dayIndex));
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // Legacy stub to avoid breaking backwards compatibility constraints with other files
  Future<void> scheduleNotification(Compartment compartment) async {}
}
