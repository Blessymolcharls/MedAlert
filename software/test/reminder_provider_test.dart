import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medalert/models/reminder.dart';
import 'package:medalert/models/dose_occurrence.dart';
import 'package:medalert/providers/reminder_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  group('ReminderProvider Tests', () {
    late ReminderProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = ReminderProvider();
      await provider.checkDailyReset(
        referenceNow: DateTime(2026, 10, 10, 8, 0),
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('Add and retrieve reminders with validation', () {
      final rem1 = Reminder(
        id: 'r1',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime.now(),
      );

      provider.addReminder(rem1);
      expect(provider.reminders.length, 1);
      expect(provider.reminders.first.name, 'Metformin');

      // Invalid reminder throws ArgumentError
      final invalid = Reminder(
        id: 'r2',
        name: '  ',
        dosage: '',
        time: const TimeOfDay(hour: 0, minute: 0),
        isAfterFood: true,
        section: '',
        selectedDays: [],
        createdAt: DateTime.now(),
      );
      expect(() => provider.addReminder(invalid), throwsArgumentError);
    });

    test('Multiple reminders at the same time operate independently', () {
      final remA = Reminder(
        id: 'remA',
        name: 'Vitamin D',
        dosage: '1000 IU',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime.now(),
      );

      final remB = Reminder(
        id: 'remB',
        name: 'Calcium',
        dosage: '500mg',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime.now(),
      );

      provider.addReminder(remA);
      provider.addReminder(remB);

      // Confirm intake only for remA
      provider.confirmIntake('remA', date: DateTime(2026, 10, 10));

      final today = DateTime(2026, 10, 10, 9, 5);
      expect(
        provider.getDoseStatus(remA, today, referenceNow: today),
        DoseStatus.taken,
      );
      expect(
        provider.getDoseStatus(remB, today, referenceNow: today),
        DoseStatus.pending,
      );
    });

    test(
      'Daily reset preserves taken history and seals past missed doses',
      () async {
        final rem = Reminder(
          id: 'r_daily',
          name: 'Lisinopril',
          dosage: '10mg',
          time: const TimeOfDay(hour: 8, minute: 0),
          isAfterFood: true,
          section: 'Morning',
          selectedDays: [0, 1, 2, 3, 4, 5, 6],
          createdAt: DateTime.now(),
        );
        provider.addReminder(rem);

        // Day 1: 2026-10-10, mark dose taken
        final day1 = DateTime(2026, 10, 10, 8, 5);
        provider.confirmIntake('r_daily', date: day1);
        expect(provider.getDoseStatus(rem, day1), DoseStatus.taken);

        // Day 2: 2026-10-11, crossing midnight boundary while app was inactive
        final day2 = DateTime(2026, 10, 11, 8, 30);
        await provider.checkDailyReset(referenceNow: day2);

        // Day 1 history MUST still be taken!
        expect(provider.getDoseStatus(rem, day1), DoseStatus.taken);

        // Day 2 dose at 08:30 AM (past 15-min window) is missed
        expect(
          provider.getDoseStatus(rem, day2, referenceNow: day2),
          DoseStatus.missed,
        );

        // Maintenance timestamp was updated to Day 2
        expect(provider.lastResetDate, '2026-10-11');
      },
    );

    test('Editing and deleting a reminder works cleanly', () {
      final rem = Reminder(
        id: 'r_edit',
        name: 'Ibuprofen',
        dosage: '200mg',
        time: const TimeOfDay(hour: 12, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0, 1, 2],
        createdAt: DateTime.now(),
      );
      provider.addReminder(rem);

      final updated = rem.copyWith(dosage: '400mg');
      provider.updateReminder(updated);
      expect(provider.reminders.first.dosage, '400mg');

      provider.removeReminder('r_edit');
      expect(provider.reminders.isEmpty, isTrue);
    });
  });
}
