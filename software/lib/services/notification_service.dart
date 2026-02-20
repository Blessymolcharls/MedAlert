import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/compartment.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> scheduleNotification(Compartment compartment) async {
    if (compartment.time == '00:00' || compartment.medicineName.isEmpty) return;

    final parts = compartment.time.split(':');
    if (parts.length != 2) return;

    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);

    // Calculate next occurrence
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Calculate which day of week this compartment represents
    int targetDayOfWeek;
    switch (compartment.day) {
      case 'Monday':
        targetDayOfWeek = DateTime.monday;
        break;
      case 'Tuesday':
        targetDayOfWeek = DateTime.tuesday;
        break;
      case 'Wednesday':
        targetDayOfWeek = DateTime.wednesday;
        break;
      case 'Thursday':
        targetDayOfWeek = DateTime.thursday;
        break;
      case 'Friday':
        targetDayOfWeek = DateTime.friday;
        break;
      case 'Saturday':
        targetDayOfWeek = DateTime.saturday;
        break;
      case 'Sunday':
        targetDayOfWeek = DateTime.sunday;
        break;
      default:
        return; // invalid day
    }

    // Move to the next target day of the week
    while (scheduledDate.weekday != targetDayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If it's today but the time has passed, add 7 days
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    // Generate unique ID
    final int id = _getNotificationId(compartment);

    // First cancel the old one
    await cancelNotification(id);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title:
            'Time to take ${compartment.medicineName} - ${compartment.slotName}',
        body: 'Dosage: ${compartment.dosage}',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medalert_channel',
            'MedAlert Reminders',
            channelDescription: 'Medications reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: \$e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  int _getNotificationId(Compartment compartment) {
    // Generate an ID based on day and slot
    int dayBase = 0;
    switch (compartment.day) {
      case 'Monday':
        dayBase = 100;
        break;
      case 'Tuesday':
        dayBase = 200;
        break;
      case 'Wednesday':
        dayBase = 300;
        break;
      // if more days are added they can be handled here
    }
    return dayBase + compartment.slotIndex;
  }
}
