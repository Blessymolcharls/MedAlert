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

  bool get isValid =>
      id.isNotEmpty &&
      name.trim().isNotEmpty &&
      dosage.trim().isNotEmpty &&
      selectedDays.isNotEmpty &&
      selectedDays.every((d) => d >= 0 && d <= 6);

  bool isDueNow({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.isAfter(reminderTime) || now.isAtSameMomentAs(reminderTime);
  }

  bool isMissed({DateTime? referenceTime}) {
    if (isTakenToday) return false;
    final now = referenceTime ?? DateTime.now();
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

  bool canConfirmNow({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
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

  Reminder copyWith({
    String? id,
    String? name,
    String? dosage,
    TimeOfDay? time,
    bool? isAfterFood,
    String? section,
    List<int>? selectedDays,
    DateTime? createdAt,
    DateTime? lastTakenAt,
    bool? isTakenToday,
    bool? isMissedToday,
  }) {
    return Reminder(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      isAfterFood: isAfterFood ?? this.isAfterFood,
      section: section ?? this.section,
      selectedDays: selectedDays ?? List.from(this.selectedDays),
      createdAt: createdAt ?? this.createdAt,
      lastTakenAt: lastTakenAt ?? this.lastTakenAt,
      isTakenToday: isTakenToday ?? this.isTakenToday,
      isMissedToday: isMissedToday ?? this.isMissedToday,
    );
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
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      time: TimeOfDay(
        hour: map['timeHour'] as int? ?? 0,
        minute: map['timeMinute'] as int? ?? 0,
      ),
      isAfterFood: map['isAfterFood'] as bool? ?? true,
      section: map['section'] as String? ?? 'Morning',
      selectedDays: map['selectedDays'] != null
          ? List<int>.from(map['selectedDays'])
          : [0, 1, 2, 3, 4, 5, 6],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastTakenAt: map['lastTakenAt'] != null
          ? DateTime.tryParse(map['lastTakenAt'])
          : null,
      isTakenToday: map['isTakenToday'] as bool? ?? false,
      isMissedToday: map['isMissedToday'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Reminder.fromJson(Map<String, dynamic> json) =>
      Reminder.fromMap(json);
}
