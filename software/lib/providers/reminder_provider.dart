import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/reminder_scheduler.dart';
import '../services/notification_service.dart';

class ReminderProvider with ChangeNotifier {
  List<Reminder> _reminders = [];
  late ReminderScheduler _scheduler;

  List<Reminder> get reminders => _reminders;

  ReminderProvider() {
    _loadReminders().then((_) {
      _scheduler = ReminderScheduler(this);
      _scheduler.start();
    });
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('reminders');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      _reminders = decoded.map((e) => Reminder.fromJson(e)).toList();
    }
    await checkDailyReset(); // Guarantee reset check is handled
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_reminders.map((e) => e.toJson()).toList());
    await prefs.setString('reminders', jsonString);
  }

  void addReminder(Reminder reminder) {
    _reminders.add(reminder);
    _saveReminders();
    NotificationService().scheduleWeeklyNotification(reminder);
    notifyListeners();
  }

  void removeReminder(String id) {
    final toRemove = _reminders.where((r) => r.id == id).toList();
    for (var r in toRemove) {
      NotificationService().cancelReminderNotifications(r);
    }
    _reminders.removeWhere((r) => r.id == id);
    _saveReminders();
    notifyListeners();
  }

  void toggleActive(String id) {
    // Optionally implemented if we want a master switch.
    // Ignored for now based on prompt standardizing models.
  }

  void confirmIntake(String id) {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      _reminders[index].isTakenToday = true;
      _reminders[index].isMissedToday = false;
      _reminders[index].lastTakenAt = DateTime.now();
      _saveReminders();
      notifyListeners();
    }
  }

  void clearAll() {
    _reminders.clear();
    _saveReminders();
    NotificationService().cancelAll();
    notifyListeners();
  }

  Future<void> checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetString = prefs.getString('lastResetDate');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    if (lastResetString != todayStr) {
      for (var r in _reminders) {
        r.resetDailyStatus();
      }
      await prefs.setString('lastResetDate', todayStr);
      await _saveReminders();
      notifyListeners();
    } else {
      notifyListeners(); // Force initial update
    }
  }

  void updateMissedStatuses() {
    bool changed = false;
    for (var r in _reminders) {
      if (!r.isTakenToday && r.isDueNow() && r.isMissed() && !r.isMissedToday) {
        r.isMissedToday = true;
        changed = true;
      }
    }
    if (changed) {
      _saveReminders();
      notifyListeners();
    }
  }

  Map<int, List<Reminder>> getRemindersGroupedByDay() {
    Map<int, List<Reminder>> grouped = {
      0: [],
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
    };

    for (var r in _reminders) {
      for (var dayIndex in r.selectedDays) {
        if (grouped.containsKey(dayIndex)) {
          grouped[dayIndex]!.add(r);
        }
      }
    }

    for (int i = 0; i < 7; i++) {
      grouped[i]!.sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });
    }

    return grouped;
  }
}
