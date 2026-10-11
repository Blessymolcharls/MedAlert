import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../models/dose_occurrence.dart';
import '../services/reminder_scheduler.dart';
import '../services/notification_service.dart';

enum DayMedicationStatus {
  none,
  completed,
  upcoming,
  missed;

  Color get indicatorColor {
    switch (this) {
      case DayMedicationStatus.none:
        return Colors.transparent;
      case DayMedicationStatus.completed:
        return const Color(0xFF2E7D32); // Deep green
      case DayMedicationStatus.upcoming:
        return const Color(0xFFF57F17); // Amber/orange
      case DayMedicationStatus.missed:
        return const Color(0xFFD32F2F); // Red
    }
  }
}

class ReminderProvider with ChangeNotifier {
  List<Reminder> _reminders = [];
  final Map<String, DoseOccurrence> _occurrences = {};
  String _lastResetDate = "Never";
  ReminderScheduler? _scheduler;
  bool _isDisposed = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  String get lastResetDate => _lastResetDate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  ReminderProvider() {
    _loadData().then((_) {
      if (_isDisposed) return;
      _scheduler = ReminderScheduler(this);
      _scheduler?.start();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scheduler?.stop();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
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

    _isLoading = false;
    notifyListeners();
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

  bool getDoseSkipped(String reminderId, DateTime date) {
    final occ = getOccurrence(reminderId, date);
    return occ.isSkipped;
  }

  String? getDoseSkipReason(String reminderId, DateTime date) {
    final occ = getOccurrence(reminderId, date);
    return occ.skipReason;
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
      occ.isSkipped = false;
      occ.skipReason = null;

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

  /// Explicitly records skipping a dose on a given date (with optional reason).
  void skipDose(String id, {DateTime? date, String? reason}) {
    final targetDate = date ?? DateTime.now();
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final occ = getOccurrence(id, targetDate);
      occ.isSkipped = true;
      occ.skipReason = reason;
      occ.isTaken = false;
      occ.isExplicitlyMissed = false;

      final todayKey = DoseOccurrence.toDateKey(DateTime.now());
      if (occ.dateString == todayKey) {
        _reminders[index].isTakenToday = false;
        _reminders[index].isMissedToday = false;
      }

      _saveOccurrences();
      _saveReminders();
      notifyListeners();
    }
  }

  /// Resets a dose on a given date back to its default calculated status.
  void unmarkDose(String id, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final occ = getOccurrence(id, targetDate);
      occ.isTaken = false;
      occ.takenAt = null;
      occ.isSkipped = false;
      occ.skipReason = null;
      occ.isExplicitlyMissed = false;

      final now = DateTime.now();
      final todayKey = DoseOccurrence.toDateKey(now);
      if (occ.dateString == todayKey) {
        _reminders[index].isTakenToday = false;
        _reminders[index].isMissedToday =
            occ.calculateStatus(_reminders[index], referenceTime: now) ==
            DoseStatus.missed;
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

  bool _isSimulatedTime = false;

  /// Idempotent daily maintenance process.
  ///
  /// - Compares local calendar date against last reset date.
  /// - Preserves taken doses permanently in history.
  /// - Seals untaken past doses as missed.
  /// - Updates today's cached status on each reminder.
  /// - Updates last reset date in SharedPreferences and memory.
  Future<void> checkDailyReset({DateTime? referenceNow}) async {
    if (referenceNow != null) {
      _isSimulatedTime = true;
    } else if (_isSimulatedTime) {
      // In simulated time (unit testing), do not let background timer overwrite simulation
      return;
    }

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
          if (r.isScheduledOnDate(pastDate)) {
            final occ = getOccurrence(r.id, pastDate);
            if (!occ.isTaken && !occ.isSkipped) {
              occ.isExplicitlyMissed = true;
            }
          }
        }

        // Sync today's cached flags from today's occurrence
        if (r.isScheduledOnDate(now)) {
          final todayOcc = getOccurrence(r.id, now);
          r.isTakenToday = todayOcc.isTaken;
          r.isMissedToday =
              todayOcc.calculateStatus(r, referenceTime: now) ==
              DoseStatus.missed;
        } else {
          r.isTakenToday = false;
          r.isMissedToday = false;
        }
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
        if (r.isScheduledOnDate(now)) {
          final todayOcc = getOccurrence(r.id, now);
          r.isTakenToday = todayOcc.isTaken;
          r.isMissedToday =
              todayOcc.calculateStatus(r, referenceTime: now) ==
              DoseStatus.missed;
        } else {
          r.isTakenToday = false;
          r.isMissedToday = false;
        }
      }
      notifyListeners();
    }
  }

  /// Checks for any scheduled doses that crossed the 15-minute missed threshold.
  void updateMissedStatuses({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    bool changed = false;

    for (var r in _reminders) {
      if (r.isScheduledOnDate(now)) {
        final occ = getOccurrence(r.id, now);
        if (!occ.isTaken &&
            !occ.isSkipped &&
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

  // --- UI Helpers & Calendar Integration ---

  /// Returns all reminders scheduled for a specific calendar date, sorted chronologically.
  ///
  /// - Future dates and current day evaluate active reminder schedule (`isScheduledOnDate`).
  /// - Past dates also preserve reminders if historical dose activity exists (`isTaken`, `isSkipped`, or `isExplicitlyMissed`),
  ///   even if the recurring schedule was subsequently edited.
  List<Reminder> getRemindersForDate(DateTime date) {
    final dateKey = DoseOccurrence.toDateKey(date);
    final todayKey = DoseOccurrence.toDateKey(DateTime.now());
    final isPast = dateKey.compareTo(todayKey) < 0;

    final list = _reminders.where((r) {
      if (r.isScheduledOnDate(date)) {
        return true;
      }
      if (isPast) {
        final occKey = '${r.id}_$dateKey';
        final occ = _occurrences[occKey];
        if (occ != null &&
            (occ.isTaken || occ.isSkipped || occ.isExplicitlyMissed)) {
          return true;
        }
      }
      return false;
    }).toList();

    list.sort((a, b) {
      if (a.time.hour != b.time.hour) {
        return a.time.hour.compareTo(b.time.hour);
      }
      return a.time.minute.compareTo(b.time.minute);
    });
    return list;
  }

  List<Reminder> getTodayReminders({DateTime? referenceDate}) {
    return getRemindersForDate(referenceDate ?? DateTime.now());
  }

  int getTotalCountForDate(DateTime date) => getRemindersForDate(date).length;

  int getTakenCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      return getDoseStatus(r, date, referenceNow: referenceNow) ==
          DoseStatus.taken;
    }).length;
  }

  int getPendingCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      return getDoseStatus(r, date, referenceNow: referenceNow) ==
          DoseStatus.pending;
    }).length;
  }

  int getUpcomingCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      final s = getDoseStatus(r, date, referenceNow: referenceNow);
      return s == DoseStatus.upcoming || s == DoseStatus.pending;
    }).length;
  }

  int getMissedCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      return getDoseStatus(r, date, referenceNow: referenceNow) ==
          DoseStatus.missed;
    }).length;
  }

  int getSkippedCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      return getDoseStatus(r, date, referenceNow: referenceNow) ==
          DoseStatus.skipped;
    }).length;
  }

  int getCompletedCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      final s = getDoseStatus(r, date, referenceNow: referenceNow);
      return s == DoseStatus.taken || s == DoseStatus.skipped;
    }).length;
  }

  int getDueNowCountForDate(DateTime date, {DateTime? referenceNow}) {
    return getRemindersForDate(date).where((r) {
      return getDoseStatus(r, date, referenceNow: referenceNow) ==
          DoseStatus.pending;
    }).length;
  }

  /// Calculates the day status applying the required status precedence:
  /// 1. If any dose is missed -> Red ([DayMedicationStatus.missed])
  /// 2. Else if any dose is upcoming/pending -> Yellow/Amber ([DayMedicationStatus.upcoming])
  /// 3. Else if ALL scheduled doses are completed (taken or skipped) -> Green ([DayMedicationStatus.completed])
  /// 4. If no doses scheduled -> [DayMedicationStatus.none]
  DayMedicationStatus getDayStatus(DateTime date, {DateTime? referenceNow}) {
    final list = getRemindersForDate(date);
    if (list.isEmpty) return DayMedicationStatus.none;

    int missedCount = 0;
    int upcomingOrPendingCount = 0;
    int completedCount = 0;

    for (final r in list) {
      final status = getDoseStatus(r, date, referenceNow: referenceNow);
      if (status == DoseStatus.missed) {
        missedCount++;
      } else if (status == DoseStatus.upcoming || status == DoseStatus.pending) {
        upcomingOrPendingCount++;
      } else if (status == DoseStatus.taken || status == DoseStatus.skipped) {
        completedCount++;
      }
    }

    if (missedCount > 0) return DayMedicationStatus.missed;
    if (upcomingOrPendingCount > 0) return DayMedicationStatus.upcoming;
    if (completedCount == list.length && completedCount > 0) {
      return DayMedicationStatus.completed;
    }

    return DayMedicationStatus.none;
  }

  /// Returns individual dose statuses for all doses on [date] in chronological order.
  List<DoseStatus> getDoseStatusesForDate(
    DateTime date, {
    DateTime? referenceNow,
  }) {
    final list = getRemindersForDate(date);
    return list
        .map((r) => getDoseStatus(r, date, referenceNow: referenceNow))
        .toList();
  }

  int getTodayTotalCount({DateTime? referenceDate}) =>
      getTotalCountForDate(referenceDate ?? DateTime.now());

  int getTodayTakenCount({DateTime? referenceDate}) =>
      getTakenCountForDate(referenceDate ?? DateTime.now());

  int getTodayPendingCount({DateTime? referenceDate}) =>
      getUpcomingCountForDate(referenceDate ?? DateTime.now());

  int getTodayMissedCount({DateTime? referenceDate}) =>
      getMissedCountForDate(referenceDate ?? DateTime.now());

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
      if (r.isOneTime && r.oneTimeDate != null) {
        final dayIndex = r.oneTimeDate!.weekday - 1;
        if (grouped.containsKey(dayIndex)) {
          grouped[dayIndex]!.add(r);
        }
      } else {
        for (var dayIndex in r.selectedDays) {
          if (grouped.containsKey(dayIndex)) {
            grouped[dayIndex]!.add(r);
          }
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
