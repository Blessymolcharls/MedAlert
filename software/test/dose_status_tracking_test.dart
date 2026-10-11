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

  group('Dose Status Tracking & Adherence Tests', () {
    late ReminderProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = ReminderProvider();
      await provider.checkDailyReset(
        referenceNow: DateTime(2026, 10, 12, 8, 0),
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Dose status transitions: upcoming -> due now -> missed -> taken', () {
      final rem = Reminder(
        id: 'rem_trans',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final today = DateTime(2026, 10, 12);

      // (A) Before scheduled time (e.g. 08:30) -> Upcoming
      final beforeTime = DateTime(2026, 10, 12, 8, 30);
      expect(
        provider.getDoseStatus(rem, today, referenceNow: beforeTime),
        DoseStatus.upcoming,
      );

      // (B) Exactly at scheduled time (09:00) -> Due Now (pending)
      final atTime = DateTime(2026, 10, 12, 9, 0);
      expect(
        provider.getDoseStatus(rem, today, referenceNow: atTime),
        DoseStatus.pending,
      );
      expect(DoseStatus.pending.displayName, 'Due Now');

      // (C) Within 15-minute grace window (09:12) -> Due Now (pending)
      final withinWindow = DateTime(2026, 10, 12, 9, 12);
      expect(
        provider.getDoseStatus(rem, today, referenceNow: withinWindow),
        DoseStatus.pending,
      );

      // (D) Past 15-minute window untaken (09:20) -> Missed
      final pastWindow = DateTime(2026, 10, 12, 9, 20);
      expect(
        provider.getDoseStatus(rem, today, referenceNow: pastWindow),
        DoseStatus.missed,
      );

      // (E) Late intake confirmation: user takes dose late at 10:15
      provider.confirmIntake('rem_trans', date: today);

      expect(
        provider.getDoseStatus(rem, today, referenceNow: pastWindow),
        DoseStatus.taken,
      );
      // Actual completion timestamp recorded
      final takenAt = provider.getDoseTakenAt('rem_trans', today);
      expect(takenAt, isNotNull);
    });

    test('2. Skipped status with optional reason persists correctly', () {
      final rem = Reminder(
        id: 'rem_skip',
        name: 'Iron Supplement',
        dosage: '65mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final date = DateTime(2026, 10, 12);
      provider.skipDose(
        'rem_skip',
        date: date,
        reason: 'Upset stomach',
      );

      expect(provider.getDoseStatus(rem, date), DoseStatus.skipped);
      expect(provider.getDoseSkipped('rem_skip', date), isTrue);
      expect(provider.getDoseSkipReason('rem_skip', date), 'Upset stomach');
      expect(provider.getSkippedCountForDate(date), 1);
    });

    test('3. Unmarking a taken dose reverts it to untaken state', () {
      final rem = Reminder(
        id: 'rem_unmark',
        name: 'Aspirin',
        dosage: '81mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final date = DateTime(2026, 10, 12);
      provider.confirmIntake('rem_unmark', date: date);
      expect(provider.getDoseStatus(rem, date), DoseStatus.taken);
      expect(provider.getTakenCountForDate(date), 1);

      // Revert / unmark
      provider.unmarkDose('rem_unmark', date: date);
      expect(provider.getDoseTakenAt('rem_unmark', date), isNull);
      expect(provider.getTakenCountForDate(date), 0);
    });

    test('4. Mixed-status dates are never marked as fully completed', () {
      final med1 = Reminder(
        id: 'm1',
        name: 'Morning Med',
        dosage: '10mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0],
        createdAt: DateTime(2026, 10, 1),
      );
      final med2 = Reminder(
        id: 'm2',
        name: 'Evening Med',
        dosage: '20mg',
        time: const TimeOfDay(hour: 20, minute: 0),
        isAfterFood: true,
        section: 'Night',
        selectedDays: [0],
        createdAt: DateTime(2026, 10, 1),
      );

      provider.addReminder(med1);
      provider.addReminder(med2);

      final date = DateTime(2026, 10, 12); // Monday
      final nowMorning = DateTime(2026, 10, 12, 8, 5); // During med1 time

      // Med1 taken, Med2 upcoming
      provider.confirmIntake('m1', date: date);

      expect(provider.getDoseStatus(med1, date, referenceNow: nowMorning), DoseStatus.taken);
      expect(provider.getDoseStatus(med2, date, referenceNow: nowMorning), DoseStatus.upcoming);

      // Day status MUST NOT be completed! It must be upcoming!
      final dayStatus = provider.getDayStatus(date, referenceNow: nowMorning);
      expect(dayStatus, DayMedicationStatus.upcoming);
      expect(dayStatus, isNot(DayMedicationStatus.completed));

      // Counts verification
      expect(provider.getTotalCountForDate(date), 2);
      expect(provider.getTakenCountForDate(date, referenceNow: nowMorning), 1);
      expect(provider.getUpcomingCountForDate(date, referenceNow: nowMorning), 1);
      expect(provider.getCompletedCountForDate(date, referenceNow: nowMorning), 1);

      // Now Med2 is missed (say, it is 20:30 at night and untaken)
      final nowNightLate = DateTime(2026, 10, 12, 20, 30);
      expect(provider.getDoseStatus(med2, date, referenceNow: nowNightLate), DoseStatus.missed);

      // Day status with 1 taken and 1 missed MUST be missed (Red precedence)
      final nightDayStatus = provider.getDayStatus(date, referenceNow: nowNightLate);
      expect(nightDayStatus, DayMedicationStatus.missed);
      expect(nightDayStatus, isNot(DayMedicationStatus.completed));

      // Finally, Med2 is taken late
      provider.confirmIntake('m2', date: date);
      // Now both doses completed (2 of 2) -> ONLY NOW is day status completed!
      expect(provider.getDayStatus(date, referenceNow: nowNightLate), DayMedicationStatus.completed);
    });

    test('5. Taking one dose of a recurring medication does not complete other doses or dates', () {
      final dailyMed = Reminder(
        id: 'r_rec',
        name: 'Multivitamin',
        dosage: '1 tab',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(dailyMed);

      final monday = DateTime(2026, 10, 12);
      final tuesday = DateTime(2026, 10, 13);
      final wednesday = DateTime(2026, 10, 14);

      // Take only Monday's dose
      provider.confirmIntake('r_rec', date: monday);

      expect(provider.getDoseStatus(dailyMed, monday), DoseStatus.taken);
      // Tuesday and Wednesday MUST still be upcoming!
      expect(provider.getDoseStatus(dailyMed, tuesday), DoseStatus.upcoming);
      expect(provider.getDoseStatus(dailyMed, wednesday), DoseStatus.upcoming);

      expect(provider.getTakenCountForDate(monday), 1);
      expect(provider.getTakenCountForDate(tuesday), 0);
      expect(provider.getTakenCountForDate(wednesday), 0);
    });

    test('6. Persistence: Status changes survive reload from SharedPreferences', () async {
      final rem = Reminder(
        id: 'r_persist',
        name: 'Blood Pressure Tablet',
        dosage: '5mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final date = DateTime(2026, 10, 12);
      provider.confirmIntake('r_persist', date: date);

      // Verify SharedPreferences has the occurrence
      final prefs = await SharedPreferences.getInstance();
      final occString = prefs.getString('dose_occurrences');
      expect(occString, isNotNull);
      expect(occString, contains('r_persist_2026-10-12'));
      expect(occString, contains('"isTaken":true'));

      // Create a fresh ReminderProvider instance simulating app cold restart
      final newProvider = ReminderProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await newProvider.checkDailyReset(referenceNow: DateTime(2026, 10, 12, 8, 30));

      final loadedRem = newProvider.reminders.firstWhere((r) => r.id == 'r_persist');
      expect(newProvider.getDoseStatus(loadedRem, date), DoseStatus.taken);
      expect(newProvider.getTakenCountForDate(date), 1);

      newProvider.dispose();
    });
  });
}
