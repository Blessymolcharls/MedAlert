import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medalert/models/reminder.dart';
import 'package:medalert/models/dose_occurrence.dart';

void main() {
  group('DoseOccurrence and DoseStatus Transitions', () {
    final testReminder = Reminder(
      id: 'rem_1',
      name: 'Amoxicillin',
      dosage: '500mg',
      time: const TimeOfDay(hour: 8, minute: 0),
      isAfterFood: true,
      section: 'Morning',
      selectedDays: [0, 1, 2, 3, 4, 5, 6],
      createdAt: DateTime(2026, 10, 1),
    );

    test('Dose scheduled in the future is upcoming', () {
      final occ = DoseOccurrence(reminderId: 'rem_1', dateString: '2026-10-10');

      // Current time is 07:30 AM (before 08:00 AM)
      final refNow = DateTime(2026, 10, 10, 7, 30);
      expect(
        occ.calculateStatus(testReminder, referenceTime: refNow),
        DoseStatus.upcoming,
      );
    });

    test(
      'Dose within 15-minute scheduled window is pending (active for intake)',
      () {
        final occ = DoseOccurrence(
          reminderId: 'rem_1',
          dateString: '2026-10-10',
        );

        // Exact scheduled time: 08:00 AM
        final atTime = DateTime(2026, 10, 10, 8, 0);
        expect(
          occ.calculateStatus(testReminder, referenceTime: atTime),
          DoseStatus.pending,
        );

        // 10 minutes later: 08:10 AM
        final withinWindow = DateTime(2026, 10, 10, 8, 10);
        expect(
          occ.calculateStatus(testReminder, referenceTime: withinWindow),
          DoseStatus.pending,
        );

        // 15 minutes mark: 08:15 AM
        final boundary = DateTime(2026, 10, 10, 8, 15);
        expect(
          occ.calculateStatus(testReminder, referenceTime: boundary),
          DoseStatus.pending,
        );
      },
    );

    test('Dose exceeding 15 minutes without intake is missed', () {
      final occ = DoseOccurrence(reminderId: 'rem_1', dateString: '2026-10-10');

      // 16 minutes after scheduled time: 08:16 AM
      final pastThreshold = DateTime(2026, 10, 10, 8, 16);
      expect(
        occ.calculateStatus(testReminder, referenceTime: pastThreshold),
        DoseStatus.missed,
      );
    });

    test('Explicitly taken dose stays taken regardless of time or date', () {
      final occ = DoseOccurrence(
        reminderId: 'rem_1',
        dateString: '2026-10-10',
        isTaken: true,
        takenAt: DateTime(2026, 10, 10, 8, 5),
      );

      // Check hours later
      final lateNow = DateTime(2026, 10, 10, 20, 0);
      expect(
        occ.calculateStatus(testReminder, referenceTime: lateNow),
        DoseStatus.taken,
      );

      // Check on subsequent days
      final nextDay = DateTime(2026, 10, 11, 8, 0);
      expect(
        occ.calculateStatus(testReminder, referenceTime: nextDay),
        DoseStatus.taken,
      );
    });

    test('Past date dose not taken is missed', () {
      final occ = DoseOccurrence(
        reminderId: 'rem_1',
        dateString: '2026-10-09',
        isTaken: false,
      );

      final today = DateTime(2026, 10, 10, 6, 0);
      expect(
        occ.calculateStatus(testReminder, referenceTime: today),
        DoseStatus.missed,
      );
    });

    test('Future date dose is upcoming', () {
      final occ = DoseOccurrence(reminderId: 'rem_1', dateString: '2026-10-11');

      final today = DateTime(2026, 10, 10, 23, 0);
      expect(
        occ.calculateStatus(testReminder, referenceTime: today),
        DoseStatus.upcoming,
      );
    });
  });
}
