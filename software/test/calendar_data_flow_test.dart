import 'dart:convert';
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

  group('Calendar Data Flow & Persistence Integration Tests', () {
    late ReminderProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = ReminderProvider();
      await provider.checkDailyReset(
        referenceNow: DateTime(2026, 10, 12, 9, 0),
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Existing medications appear on their scheduled dates', () {
      // Monday is weekday 1 -> index 0. Wednesday is weekday 3 -> index 2.
      final mondayAndWedMed = Reminder(
        id: 'med_mw',
        name: 'Atorvastatin',
        dosage: '20mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 2], // Mon, Wed
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(mondayAndWedMed);

      // Oct 12, 2026 is Monday
      final monday = DateTime(2026, 10, 12);
      final tuesday = DateTime(2026, 10, 13);
      final wednesday = DateTime(2026, 10, 14);

      final mondayList = provider.getRemindersForDate(monday);
      final tuesdayList = provider.getRemindersForDate(tuesday);
      final wednesdayList = provider.getRemindersForDate(wednesday);

      expect(mondayList.map((r) => r.id), contains('med_mw'));
      expect(tuesdayList.map((r) => r.id), isNot(contains('med_mw')));
      expect(wednesdayList.map((r) => r.id), contains('med_mw'));
    });

    test('2. Multiple medications and multiple doses appear on the same date', () {
      final morningMed = Reminder(
        id: 'med_morn',
        name: 'Omeprazole',
        dosage: '20mg',
        time: const TimeOfDay(hour: 7, minute: 30),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      final noonMed = Reminder(
        id: 'med_noon',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 12, minute: 30),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      final nightMed = Reminder(
        id: 'med_night',
        name: 'Melatonin',
        dosage: '3mg',
        time: const TimeOfDay(hour: 21, minute: 0),
        isAfterFood: true,
        section: 'Night',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );

      provider.addReminder(nightMed);
      provider.addReminder(morningMed);
      provider.addReminder(noonMed);

      final date = DateTime(2026, 10, 12);
      final list = provider.getRemindersForDate(date);

      expect(list.length, 3);
      // Verify chronological sort: Morning (7:30) -> Noon (12:30) -> Night (21:00)
      expect(list[0].id, 'med_morn');
      expect(list[1].id, 'med_noon');
      expect(list[2].id, 'med_night');
    });

    test('3. Recurring schedules expand into the correct calendar occurrences', () {
      final weekendMed = Reminder(
        id: 'med_weekend',
        name: 'Vitamin D Weekly',
        dosage: '50000 IU',
        time: const TimeOfDay(hour: 10, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [5, 6], // Saturday, Sunday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(weekendMed);

      // Check week from Oct 12 (Mon) to Oct 18 (Sun), 2026
      for (int i = 0; i < 7; i++) {
        final day = DateTime(2026, 10, 12 + i);
        final dayList = provider.getRemindersForDate(day);
        if (i == 5 || i == 6) {
          // Sat, Sun
          expect(dayList.map((r) => r.id), contains('med_weekend'),
              reason: 'Should be scheduled on ${day.toIso8601String()}');
        } else {
          expect(dayList.map((r) => r.id), isNot(contains('med_weekend')),
              reason: 'Should NOT be scheduled on ${day.toIso8601String()}');
        }
      }
    });

    test('4. One-time reminders appear only on their intended dates', () {
      final oneTimeDate = DateTime(2026, 10, 15); // Thursday
      final oneTimeMed = Reminder(
        id: 'med_onetime',
        name: 'Antibiotic Booster',
        dosage: '1 vial',
        time: const TimeOfDay(hour: 14, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [3], // Thursday
        oneTimeDate: oneTimeDate,
        createdAt: DateTime(2026, 10, 10),
      );
      provider.addReminder(oneTimeMed);

      expect(oneTimeMed.isOneTime, isTrue);

      // Intended date
      expect(provider.getRemindersForDate(oneTimeDate).map((r) => r.id),
          contains('med_onetime'));

      // Day before (Wednesday Oct 14)
      expect(
          provider
              .getRemindersForDate(DateTime(2026, 10, 14))
              .map((r) => r.id),
          isNot(contains('med_onetime')));

      // Day after (Friday Oct 16)
      expect(
          provider
              .getRemindersForDate(DateTime(2026, 10, 16))
              .map((r) => r.id),
          isNot(contains('med_onetime')));

      // Next Thursday (Oct 22, 2026) - must NOT recur!
      expect(
          provider
              .getRemindersForDate(DateTime(2026, 10, 22))
              .map((r) => r.id),
          isNot(contains('med_onetime')));
    });

    test('5. Editing a recurring schedule updates appropriate future occurrences', () {
      final med = Reminder(
        id: 'med_edit',
        name: 'Blood Pressure Med',
        dosage: '10mg',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 2, 4], // Mon, Wed, Fri
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(med);

      // Verify Friday Oct 16 is scheduled
      final fridayOct16 = DateTime(2026, 10, 16);
      expect(provider.getRemindersForDate(fridayOct16).map((r) => r.id),
          contains('med_edit'));

      // Edit schedule to Tuesday and Thursday only [1, 3]
      final updated = med.copyWith(
        selectedDays: [1, 3], // Tue, Thu
      );
      provider.updateReminder(updated);

      // Friday Oct 16 should no longer have this reminder
      expect(provider.getRemindersForDate(fridayOct16).map((r) => r.id),
          isNot(contains('med_edit')));

      // Tuesday Oct 13 should now have this reminder
      final tuesdayOct13 = DateTime(2026, 10, 13);
      expect(provider.getRemindersForDate(tuesdayOct13).map((r) => r.id),
          contains('med_edit'));
    });

    test('6. Historical dose records are preserved even after schedule edit', () {
      final med = Reminder(
        id: 'med_hist',
        name: 'Thyroid Medication',
        dosage: '50mcg',
        time: const TimeOfDay(hour: 6, minute: 30),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6], // Daily
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(med);

      // Past date: Sunday Oct 11, 2026 (day before Oct 12)
      final pastDate = DateTime(2026, 10, 11, 6, 35);
      provider.confirmIntake('med_hist', date: pastDate);

      // Confirm status on past date is taken
      expect(provider.getDoseStatus(med, pastDate), DoseStatus.taken);
      expect(provider.getDoseTakenAt('med_hist', pastDate), isNotNull);

      // Now edit the reminder schedule to Weekdays only [0, 1, 2, 3, 4] (excluding Sunday)
      final editedMed = med.copyWith(
        selectedDays: [0, 1, 2, 3, 4],
      );
      provider.updateReminder(editedMed);

      // Future Sunday (Oct 18) must NOT be scheduled
      final futureSunday = DateTime(2026, 10, 18);
      expect(provider.getRemindersForDate(futureSunday).map((r) => r.id),
          isNot(contains('med_hist')));

      // Past Sunday (Oct 11) MUST preserve historical taken status!
      final pastSundayReminders = provider.getRemindersForDate(pastDate);
      expect(pastSundayReminders.map((r) => r.id), contains('med_hist'));
      expect(provider.getDoseStatus(editedMed, pastDate), DoseStatus.taken);
    });

    test('7. Refreshing or repeatedly querying calendar does not create duplicate occurrences', () {
      final med = Reminder(
        id: 'med_idempotent',
        name: 'Zinc',
        dosage: '50mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(med);

      final monday = DateTime(2026, 10, 12);

      // Query multiple times simulating calendar navigation / re-renders
      for (int i = 0; i < 10; i++) {
        final list = provider.getRemindersForDate(monday);
        expect(list.length, 1);
        final status = provider.getDoseStatus(med, monday);
        expect(status, isNotNull);
      }

      // Check that only 1 occurrence key exists in provider
      final occ = provider.getOccurrence('med_idempotent', monday);
      expect(occ.reminderId, 'med_idempotent');
      expect(occ.dateString, '2026-10-12');
    });

    test('8. Changes are reflected consistently across Home and Calendar views', () {
      final med = Reminder(
        id: 'med_consistency',
        name: 'Aspirin',
        dosage: '81mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(med);

      final today = DateTime(2026, 10, 12, 8, 5);

      // Both Home (getTodayReminders) and Calendar (getRemindersForDate) return med
      final homeReminders = provider.getTodayReminders(referenceDate: today);
      final calendarReminders = provider.getRemindersForDate(today);
      expect(homeReminders.length, calendarReminders.length);
      expect(homeReminders.first.id, calendarReminders.first.id);

      // Confirm intake
      provider.confirmIntake('med_consistency', date: today);

      // Counts match across both
      expect(provider.getTodayTakenCount(referenceDate: today), 1);
      expect(provider.getTakenCountForDate(today, referenceNow: today), 1);
      expect(provider.getTodayTotalCount(referenceDate: today), 1);
      expect(provider.getTotalCountForDate(today), 1);
    });

    test('9. Data remains correct after application restart simulation', () async {
      // 1. Setup initial reminders and dose intakes
      final med1 = Reminder(
        id: 'restart_med1',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      final med2OneTime = Reminder(
        id: 'restart_med2',
        name: 'Special Injection',
        dosage: '1 dose',
        time: const TimeOfDay(hour: 15, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0],
        oneTimeDate: DateTime(2026, 10, 12),
        createdAt: DateTime(2026, 10, 1),
      );

      provider.addReminder(med1);
      provider.addReminder(med2OneTime);

      final oct12 = DateTime(2026, 10, 12, 8, 10);
      provider.confirmIntake('restart_med1', date: oct12);
      provider.skipDose('restart_med2', date: oct12, reason: 'Doctor advised postponement');

      // 2. Read what was persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final remindersRaw = prefs.getString('reminders');
      final occurrencesRaw = prefs.getString('dose_occurrences');

      expect(remindersRaw, isNotNull);
      expect(occurrencesRaw, isNotNull);

      // Verify JSON content has the new fields backward-compatibly
      final List<dynamic> decodedReminders = jsonDecode(remindersRaw!);
      expect(decodedReminders.length, 2);
      final med2Map = decodedReminders.firstWhere((r) => r['id'] == 'restart_med2');
      expect(med2Map['oneTimeDate'], isNotNull);

      // 3. Simulate new app lifecycle session: create a new ReminderProvider
      final restartedProvider = ReminderProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await restartedProvider.checkDailyReset(referenceNow: oct12);

      // Verify all reminders restored
      expect(restartedProvider.reminders.length, 2);
      final loadedMed1 = restartedProvider.reminders.firstWhere((r) => r.id == 'restart_med1');
      final loadedMed2 = restartedProvider.reminders.firstWhere((r) => r.id == 'restart_med2');

      expect(loadedMed1.name, 'Metformin');
      expect(loadedMed2.isOneTime, isTrue);
      expect(loadedMed2.oneTimeDate, DateTime(2026, 10, 12));

      // Verify dose occurrences restored
      expect(restartedProvider.getDoseStatus(loadedMed1, oct12), DoseStatus.taken);
      expect(restartedProvider.getDoseStatus(loadedMed2, oct12), DoseStatus.skipped);
      expect(restartedProvider.getDoseSkipReason('restart_med2', oct12), 'Doctor advised postponement');

      restartedProvider.dispose();
    });
  });
}
