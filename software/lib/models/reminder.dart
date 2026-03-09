import 'package:flutter/material.dart';

class Reminder {
  final String id;
  final String name;
  final String dosage;
  final TimeOfDay time;
  final bool isAfterFood;
  final String section;
  final List<int> selectedDays;
  final DateTime createdAt;
  DateTime? lastTakenAt;
  bool isTakenToday;
  bool isMissedToday;

  Reminder({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isAfterFood,
    required this.section,
    required this.selectedDays,
    required this.createdAt,
    this.lastTakenAt,
    this.isTakenToday = false,
    this.isMissedToday = false,
  });

  bool isDueNow() {
    final now = DateTime.now();
    final reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.isAfter(reminderTime) || now.isAtSameMomentAs(reminderTime);
  }

  bool isMissed() {
    if (isTakenToday) return false;
    final now = DateTime.now();
    final reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final difference = now.difference(reminderTime).inMinutes;
    return difference > 15;
  }

  bool canConfirmNow() {
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final difference = now.difference(scheduled).inMinutes;

    if (difference < 0) return false; // too early
    if (difference > 15) return false; // too late

    return true;
  }

  void resetDailyStatus() {
    isTakenToday = false;
    isMissedToday = false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'isAfterFood': isAfterFood,
      'section': section,
      'selectedDays': selectedDays,
      'createdAt': createdAt.toIso8601String(),
      'lastTakenAt': lastTakenAt?.toIso8601String(),
      'isTakenToday': isTakenToday,
      'isMissedToday': isMissedToday,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      time: TimeOfDay(hour: map['timeHour'], minute: map['timeMinute']),
      isAfterFood: map['isAfterFood'],
      section: map['section'],
      selectedDays: List<int>.from(map['selectedDays']),
      createdAt: DateTime.parse(map['createdAt']),
      lastTakenAt: map['lastTakenAt'] != null
          ? DateTime.parse(map['lastTakenAt'])
          : null,
      isTakenToday: map['isTakenToday'] ?? false,
      isMissedToday: map['isMissedToday'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Reminder.fromJson(Map<String, dynamic> json) =>
      Reminder.fromMap(json);
}
