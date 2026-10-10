import 'reminder.dart';

enum DoseStatus {
  upcoming,
  pending,
  taken,
  missed;

  String get displayName {
    switch (this) {
      case DoseStatus.upcoming:
        return 'Upcoming';
      case DoseStatus.pending:
        return 'Pending';
      case DoseStatus.taken:
        return 'Taken';
      case DoseStatus.missed:
        return 'Missed';
    }
  }
}

/// Represents an individual dose instance scheduled for a specific calendar date.
class DoseOccurrence {
  final String reminderId;
  final String dateString; // YYYY-MM-DD
  bool isTaken;
  DateTime? takenAt;
  bool isExplicitlyMissed;

  DoseOccurrence({
    required this.reminderId,
    required this.dateString,
    this.isTaken = false,
    this.takenAt,
    this.isExplicitlyMissed = false,
  });

  String get id => '${reminderId}_$dateString';

  static String toDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Calculates the dose status using current local time (or provided [referenceTime]).
  ///
  /// Status transitions:
  /// - [DoseStatus.taken]: Marked taken by user action.
  /// - [DoseStatus.missed]: If date is before today and not taken, or today past 15-min window without intake.
  /// - [DoseStatus.pending]: Today between scheduled time and scheduled time + 15 mins.
  /// - [DoseStatus.upcoming]: Scheduled in the future (future date or later today).
  DoseStatus calculateStatus(Reminder reminder, {DateTime? referenceTime}) {
    if (isTaken) {
      return DoseStatus.taken;
    }

    final now = referenceTime ?? DateTime.now();
    final todayKey = toDateKey(now);

    // Past date not taken -> Missed
    if (dateString.compareTo(todayKey) < 0) {
      return DoseStatus.missed;
    }

    // Future date -> Upcoming
    if (dateString.compareTo(todayKey) > 0) {
      return DoseStatus.upcoming;
    }

    // Date is today
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    final diffMinutes = now.difference(scheduledToday).inMinutes;

    if (diffMinutes < 0) {
      return DoseStatus.upcoming;
    } else if (diffMinutes <= 15) {
      return DoseStatus.pending;
    } else {
      return DoseStatus.missed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'reminderId': reminderId,
      'dateString': dateString,
      'isTaken': isTaken,
      'takenAt': takenAt?.toIso8601String(),
      'isExplicitlyMissed': isExplicitlyMissed,
    };
  }

  factory DoseOccurrence.fromMap(Map<String, dynamic> map) {
    return DoseOccurrence(
      reminderId: map['reminderId'] as String,
      dateString: map['dateString'] as String,
      isTaken: map['isTaken'] as bool? ?? false,
      takenAt: map['takenAt'] != null
          ? DateTime.tryParse(map['takenAt'] as String)
          : null,
      isExplicitlyMissed: map['isExplicitlyMissed'] as bool? ?? false,
    );
  }
}
