import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/reminder.dart';
import '../models/compartment.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize timezones for scheduled notifications
    tz.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
        'NotificationService: Could not get local timezone, falling back to UTC: $e',
      );
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

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
        // Handle notification click route if needed
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
        'medalert_high_channel',
        'MedAlert Reminders',
        description: 'High priority medicine intake reminders',
        importance: Importance.max,
      );

      await androidImplementation?.createNotificationChannel(channel);

      // Request Android 13+ Notification Permissions
      try {
        await androidImplementation?.requestNotificationsPermission();
      } catch (e) {
        debugPrint(
          'NotificationService: requestNotificationsPermission error: $e',
        );
      }

      // Request Exact Alarm permissions (Android 12/13+)
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint(
          'NotificationService: requestExactAlarmsPermission error: $e',
        );
      }
    }

    _isInitialized = true;
  }

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

  Future<void> scheduleWeeklyNotification(Reminder reminder) async {
    if (reminder.isOneTime && reminder.oneTimeDate != null) {
      final oneTime = reminder.oneTimeDate!;
      final tz.TZDateTime scheduledTime = tz.TZDateTime(
        tz.local,
        oneTime.year,
        oneTime.month,
        oneTime.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      if (scheduledTime.isBefore(now)) return; // Past date, do not schedule

      final int notifId = _generateNotificationId(reminder.id, 0);
      final String foodText = reminder.isAfterFood
          ? "After Food"
          : "Before Food";
      final formattedTimeStr = _formatTimeOfDay(reminder.time);

      const title = "Upcoming Medicine Reminder";
      final body = "${reminder.name} at $formattedTimeStr ($foodText)";

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'medalert_high_channel',
          'MedAlert Reminders',
          channelDescription: 'High priority medicine intake reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      try {
        await _plugin.zonedSchedule(
          notifId,
          title,
          body,
          scheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        try {
          await _plugin.zonedSchedule(
            notifId,
            title,
            body,
            scheduledTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }
      return;
    }

    for (int dayIndex in reminder.selectedDays) {
      final int flutterWeekdayMatch = dayIndex + 1;

      final tz.TZDateTime scheduledTime = _nextInstanceOfWeekday(
        flutterWeekdayMatch,
        reminder.time,
      );

      final int notifId = _generateNotificationId(reminder.id, dayIndex);
      final String foodText = reminder.isAfterFood
          ? "After Food"
          : "Before Food";
      final formattedTimeStr = _formatTimeOfDay(reminder.time);

      const title = "Upcoming Medicine Reminder";
      final body = "${reminder.name} at $formattedTimeStr ($foodText)";

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'medalert_high_channel',
          'MedAlert Reminders',
          channelDescription: 'High priority medicine intake reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      // Attempt exact alarm, fallback to inexact if restricted
      try {
        await _plugin.zonedSchedule(
          notifId,
          title,
          body,
          scheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint(
          'NotificationService: exactAllowWhileIdle failed, falling back to inexact: $e',
        );
        try {
          await _plugin.zonedSchedule(
            notifId,
            title,
            body,
            scheduledTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e2) {
          debugPrint('NotificationService: fallback zonedSchedule error: $e2');
        }
      }
    }
  }

  /// Calculates the next occurrence of a weekday and time in local timezone.
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int daysToAdd = (weekday - now.weekday) % 7;
    if (daysToAdd < 0) daysToAdd += 7;

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysToAdd,
      time.hour,
      time.minute,
    );

    if (daysToAdd == 0 && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
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
    return (reminderId.hashCode + dayIndex).abs() % 2147483647;
  }

  Future<void> cancelReminderNotifications(Reminder reminder) async {
    if (reminder.isOneTime) {
      try {
        await _plugin.cancel(_generateNotificationId(reminder.id, 0));
      } catch (e) {
        debugPrint('NotificationService: cancel error: $e');
      }
      return;
    }
    for (int dayIndex in reminder.selectedDays) {
      try {
        await _plugin.cancel(_generateNotificationId(reminder.id, dayIndex));
      } catch (e) {
        debugPrint('NotificationService: cancel error: $e');
      }
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService: cancelAll error: $e');
    }
  }

  // Legacy stubs to avoid breaking other files
  Future<void> scheduleNotification(Compartment compartment) async {}
}
