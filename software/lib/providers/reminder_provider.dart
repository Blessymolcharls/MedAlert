import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../models/dose_occurrence.dart';
import '../services/reminder_scheduler.dart';
import '../services/notification_service.dart';

class ReminderProvider with ChangeNotifier {
  List<Reminder> _reminders = [];
  final Map<String, DoseOccurrence> _occurrences = {};
  String _lastResetDate = "Never";
  late ReminderScheduler _scheduler;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  String get lastResetDate => _lastResetDate;

  ReminderProvider() {
    _loadData().then((_) {
      _scheduler = ReminderScheduler(this);
      _scheduler.start();
    });
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load reminders
    final remindersJson = prefs.getString('reminders');
    if (remindersJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(remindersJson);
        _reminders = decoded.map((e) => Reminder.fromJson(e)).toList();
      } catch (e) {
        _reminders = [];
      }
    }

    // 2. Load dose occurrences
    final occurrencesJson = prefs.getString('dose_occurrences');
    if (occurrencesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(occurrencesJson);
        _occurrences.clear();
        decoded.forEach((key, value) {
          _occurrences[key] = DoseOccurrence.fromMap(
            Map<String, dynamic>.from(value),
          );
        });
      } catch (e) {
        _occurrences.clear();
      }
    }

    // 3. Load last reset date
    _lastResetDate =
        prefs.getString('lastResetDate') ??
        prefs.getString('last_reset_date') ??
        "Never";

    // 4. Run daily reset check
    await checkDailyReset();
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_reminders.map((e) => e.toJson()).toList());
    await prefs.setString('reminders', jsonString);
  }

  Future<void> _saveOccurrences() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _occurrences.map((k, v) => MapEntry(k, v.toMap()));
    await prefs.setString('dose_occurrences', jsonEncode(map));
  }

  /// Adds a new medication reminder with validation and notification scheduling.
  void addReminder(Reminder reminder) {
    if (!reminder.isValid) {
      throw ArgumentError('Invalid reminder data');
    }
    _reminders.add(reminder);
    _saveReminders();
    NotificationService().scheduleWeeklyNotification(reminder);
    notifyListeners();
  }

  /// Edits an existing reminder and reconciles its notification schedule.
  void updateReminder(Reminder updated) {
    if (!updated.isValid) {
      throw ArgumentError('Invalid reminder data');
    }
    final index = _reminders.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      NotificationService().cancelReminderNotifications(_reminders[index]);
      _reminders[index] = updated;
      _saveReminders();
      NotificationService().scheduleWeeklyNotification(updated);
      notifyListeners();
    }
  }

  /// Removes a reminder, cancels notifications, and removes its occurrences.
  void removeReminder(String id) {
    final toRemove = _reminders.where((r) => r.id == id).toList();
    for (var r in toRemove) {
      NotificationService().cancelReminderNotifications(r);
    }
    _reminders.removeWhere((r) => r.id == id);
    _occurrences.removeWhere((key, _) => key.startsWith('${id}_'));
    _saveReminders();
    _saveOccurrences();
    notifyListeners();
  }

  /// Returns or initializes a dose occurrence for a specific date.
  DoseOccurrence getOccurrence(String reminderId, DateTime date) {
    final dateKey = DoseOccurrence.toDateKey(date);
    final key = '${reminderId}_$dateKey';
    return _occurrences.putIfAbsent(
      key,
      () => DoseOccurrence(reminderId: reminderId, dateString: dateKey),
    );
  }

  /// Calculates the dose status for a reminder on a given date.
  DoseStatus getDoseStatus(
    Reminder reminder,
    DateTime date, {
    DateTime? referenceNow,
  }) {
    final occ = getOccurrence(reminder.id, date);
    return occ.calculateStatus(reminder, referenceTime: referenceNow);
  }

  DateTime? getDoseTakenAt(String reminderId, DateTime date) {
    final occ = getOccurrence(reminderId, date);
    return occ.takenAt;
  }

  /// Explicitly confirms intake for a dose on a given date (default today).
  void confirmIntake(String id, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final occ = getOccurrence(id, targetDate);
      final now = DateTime.now();
      occ.isTaken = true;
      occ.takenAt = now;
      occ.isExplicitlyMissed = false;

      // Update today's cache on reminder model
      final todayKey = DoseOccurrence.toDateKey(now);
      if (occ.dateString == todayKey) {
        _reminders[index].isTakenToday = true;
        _reminders[index].isMissedToday = false;
        _reminders[index].lastTakenAt = now;
      }

      _saveOccurrences();
      _saveReminders();
      notifyListeners();
    }
  }

  void clearAll() {
    _reminders.clear();
    _occurrences.clear();
    _saveReminders();
    _saveOccurrences();
    NotificationService().cancelAll();
    notifyListeners();
  }

  /// Idempotent daily maintenance process.
  ///
  /// - Compares local calendar date against last reset date.
  /// - Preserves taken doses permanently in history.
  /// - Seals untaken past doses as missed.
  /// - Updates today's cached status on each reminder.
  /// - Updates last reset date in SharedPreferences and memory.
  Future<void> checkDailyReset({DateTime? referenceNow}) async {
    final now = referenceNow ?? DateTime.now();
    final todayStr = DoseOccurrence.toDateKey(now);

    final prefs = await SharedPreferences.getInstance();
    final storedReset =
        prefs.getString('lastResetDate') ?? prefs.getString('last_reset_date');

    if (storedReset != todayStr) {
      // Reconcile past days up to 7 days back
      for (var r in _reminders) {
        for (int i = 1; i <= 7; i++) {
          final pastDate = now.subtract(Duration(days: i));
          final weekdayIndex = pastDate.weekday - 1; // 0=Mon, 6=Sun
          if (r.selectedDays.contains(weekdayIndex)) {
            final occ = getOccurrence(r.id, pastDate);
            if (!occ.isTaken) {
              occ.isExplicitlyMissed = true;
            }
          }
        }

        // Sync today's cached flags from today's occurrence
        final todayOcc = getOccurrence(r.id, now);
        r.isTakenToday = todayOcc.isTaken;
        r.isMissedToday =
            todayOcc.calculateStatus(r, referenceTime: now) ==
            DoseStatus.missed;
      }

      _lastResetDate = todayStr;
      await prefs.setString('lastResetDate', todayStr);
      await prefs.setString('last_reset_date', todayStr);
      await _saveOccurrences();
      await _saveReminders();
      notifyListeners();
    } else {
      // Sync memory cache
      _lastResetDate = todayStr;
      for (var r in _reminders) {
        final todayOcc = getOccurrence(r.id, now);
        r.isTakenToday = todayOcc.isTaken;
        r.isMissedToday =
            todayOcc.calculateStatus(r, referenceTime: now) ==
            DoseStatus.missed;
      }
      notifyListeners();
    }
  }

  /// Checks for any scheduled doses that crossed the 15-minute missed threshold.
  void updateMissedStatuses({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    final todayWeekday = now.weekday - 1;
    bool changed = false;

    for (var r in _reminders) {
      if (r.selectedDays.contains(todayWeekday)) {
        final occ = getOccurrence(r.id, now);
        if (!occ.isTaken &&
            occ.calculateStatus(r, referenceTime: now) == DoseStatus.missed) {
          if (!r.isMissedToday) {
            r.isMissedToday = true;
            changed = true;
          }
        }
      }
    }

    if (changed) {
      _saveReminders();
      _saveOccurrences();
      notifyListeners();
    }
  }

  // --- UI Helpers ---

  List<Reminder> getTodayReminders({DateTime? referenceDate}) {
    final date = referenceDate ?? DateTime.now();
    final todayIndex = date.weekday - 1;
    final list = _reminders
        .where((r) => r.selectedDays.contains(todayIndex))
        .toList();
    list.sort((a, b) {
      if (a.time.hour != b.time.hour) {
        return a.time.hour.compareTo(b.time.hour);
      }
      return a.time.minute.compareTo(b.time.minute);
    });
    return list;
  }

  int getTodayTotalCount({DateTime? referenceDate}) =>
      getTodayReminders(referenceDate: referenceDate).length;

  int getTodayTakenCount({DateTime? referenceDate}) {
    final date = referenceDate ?? DateTime.now();
    return getTodayReminders(referenceDate: date).where((r) {
      return getDoseStatus(r, date) == DoseStatus.taken;
    }).length;
  }

  int getTodayPendingCount({DateTime? referenceDate}) {
    final date = referenceDate ?? DateTime.now();
    return getTodayReminders(referenceDate: date).where((r) {
      final s = getDoseStatus(r, date);
      return s == DoseStatus.pending || s == DoseStatus.upcoming;
    }).length;
  }

  int getTodayMissedCount({DateTime? referenceDate}) {
    final date = referenceDate ?? DateTime.now();
    return getTodayReminders(referenceDate: date).where((r) {
      return getDoseStatus(r, date) == DoseStatus.missed;
    }).length;
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
