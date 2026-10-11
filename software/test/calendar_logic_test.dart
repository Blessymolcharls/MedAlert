import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medalert/utils/calendar_utils.dart';
import 'package:medalert/models/reminder.dart';
import 'package:medalert/models/dose_occurrence.dart';
import 'package:medalert/providers/reminder_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  group('CalendarUtils & Date Navigation Tests', () {
    test('February in leap and non-leap years (including century boundaries)', () {
      // Leap years: February must have exactly 29 days
      const leapYears = [2000, 2020, 2024, 2028, 2032];
      for (final year in leapYears) {
        expect(CalendarUtils.isLeapYear(year), isTrue, reason: '$year should be a leap year');
        expect(CalendarUtils.daysInMonth(year, 2), 29, reason: 'Feb $year must have 29 days');
      }

      // Non-leap years: February must have exactly 28 days
      const nonLeapYears = [1900, 2021, 2022, 2023, 2025, 2026, 2100];
      for (final year in nonLeapYears) {
        expect(CalendarUtils.isLeapYear(year), isFalse, reason: '$year should NOT be a leap year');
        expect(CalendarUtils.daysInMonth(year, 2), 28, reason: 'Feb $year must have 28 days');
      }
    });

    test('Correct day counts for all 12 calendar months', () {
      const expectedDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (int month = 1; month <= 12; month++) {
        expect(
          CalendarUtils.daysInMonth(2026, month),
          expectedDays[month - 1],
          reason: 'Month $month of 2026 should have ${expectedDays[month - 1]} days',
        );
      }
    });

    test('Months beginning on all 7 distinct weekdays (Monday=0 to Sunday=6)', () {
      // Monday start: June 2026 (June 1 is Monday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 6), 0);
      // Tuesday start: September 2026 (September 1 is Tuesday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 9), 1);
      // Wednesday start: April 2026 (April 1 is Wednesday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 4), 2);
      // Thursday start: October 2026 (October 1 is Thursday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 10), 3);
      // Friday start: May 2026 (May 1 is Friday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 5), 4);
      // Saturday start: August 2026 (August 1 is Saturday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 8), 5);
      // Sunday start: February 2026 (February 1 is Sunday)
      expect(CalendarUtils.startWeekdayOfMonth(2026, 2), 6);
    });

    test('Previous and next month navigation across year boundaries and day clamping', () {
      // Jan 2026 -> previous is Dec 2025
      final jan15 = DateTime(2026, 1, 15);
      final prevMonth = CalendarUtils.previousMonth(jan15);
      expect(prevMonth.year, 2025);
      expect(prevMonth.month, 12);
      expect(prevMonth.day, 15);

      // Dec 2025 -> next is Jan 2026
      final nextMonth = CalendarUtils.nextMonth(prevMonth);
      expect(nextMonth.year, 2026);
      expect(nextMonth.month, 1);
      expect(nextMonth.day, 15);

      // Clamping: March 31 -> previous is Feb 28 in 2026 (non-leap)
      final mar31 = DateTime(2026, 3, 31);
      final feb2026 = CalendarUtils.previousMonth(mar31);
      expect(feb2026.year, 2026);
      expect(feb2026.month, 2);
      expect(feb2026.day, 28);

      // Clamping: March 31 in 2024 (leap year) -> Feb 29
      final mar31Leap = DateTime(2024, 3, 31);
      final feb2024 = CalendarUtils.previousMonth(mar31Leap);
      expect(feb2024.year, 2024);
      expect(feb2024.month, 2);
      expect(feb2024.day, 29);

      // Clamping: May 31 -> previous is April 30
      final may31 = DateTime(2026, 5, 31);
      final apr30 = CalendarUtils.previousMonth(may31);
      expect(apr30.year, 2026);
      expect(apr30.month, 4);
      expect(apr30.day, 30);
    });

    test('Previous and next week navigation across year and month boundaries', () {
      // Week crossing year boundary: Jan 3, 2026 -> previous week is Dec 27, 2025
      final jan3 = DateTime(2026, 1, 3);
      final prevWeek = CalendarUtils.previousWeek(jan3);
      expect(prevWeek, DateTime(2025, 12, 27));

      // Week crossing year boundary: Dec 28, 2026 -> next week is Jan 4, 2027
      final dec28 = DateTime(2026, 12, 28);
      final nextWeek = CalendarUtils.nextWeek(dec28);
      expect(nextWeek, DateTime(2027, 1, 4));

      // Week dates generation always starts on Monday and ends on Sunday
      final weekDates = CalendarUtils.getWeekDates(DateTime(2026, 10, 14)); // Wednesday
      expect(weekDates.length, 7);
      expect(weekDates[0], DateTime(2026, 10, 12)); // Monday
      expect(weekDates[0].weekday, DateTime.monday);
      expect(weekDates[6], DateTime(2026, 10, 18)); // Sunday
      expect(weekDates[6].weekday, DateTime.sunday);
    });

    test('Previous and next day navigation across year and month boundaries', () {
      // Jan 1, 2026 -> previous day is Dec 31, 2025
      final jan1 = DateTime(2026, 1, 1);
      final prevDay = CalendarUtils.previousDay(jan1);
      expect(prevDay, DateTime(2025, 12, 31));

      // Dec 31, 2026 -> next day is Jan 1, 2027
      final dec31 = DateTime(2026, 12, 31);
      final nextDay = CalendarUtils.nextDay(dec31);
      expect(nextDay, DateTime(2027, 1, 1));

      // Mar 1, 2026 -> previous day is Feb 28, 2026
      final mar1 = DateTime(2026, 3, 1);
      expect(CalendarUtils.previousDay(mar1), DateTime(2026, 2, 28));

      // Mar 1, 2024 (leap year) -> previous day is Feb 29, 2024
      final mar1Leap = DateTime(2024, 3, 1);
      expect(CalendarUtils.previousDay(mar1Leap), DateTime(2024, 2, 29));
    });

    test('Timezone safety: date keys avoid off-by-one errors from UTC shifts', () {
      // A local DateTime near midnight must produce the exact calendar date
      final lateNight = DateTime(2026, 10, 12, 23, 59);
      final earlyMorning = DateTime(2026, 10, 12, 0, 1);

      expect(DoseOccurrence.toDateKey(lateNight), '2026-10-12');
      expect(DoseOccurrence.toDateKey(earlyMorning), '2026-10-12');
      expect(CalendarUtils.isSameDay(lateNight, earlyMorning), isTrue);
    });

    test('Locale-aware date string formatting', () {
      final date = DateTime(2026, 10, 12);
      expect(CalendarUtils.formatMonthYear(date), 'October 2026');
      expect(CalendarUtils.formatFullDate(date), 'Monday, October 12');
      expect(CalendarUtils.formatFullDateWithYear(date), 'Monday, Oct 12, 2026');
      expect(CalendarUtils.formatWeekRange(date), 'Oct 12 – 18, 2026');
    });
  });

  group('Calendar Medication Scheduling & Precedence', () {
    late ReminderProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = ReminderProvider();
      await provider.checkDailyReset(referenceNow: DateTime(2026, 10, 12, 8, 0));
    });

    tearDown(() {
      provider.dispose();
    });

    test('Scheduled medications appear on correct calendar dates matching selectedDays', () {
      // Reminder scheduled for Mondays (0) and Thursdays (3)
      final rem = Reminder(
        id: 'r_recur',
        name: 'Atorvastatin',
        dosage: '20mg',
        time: const TimeOfDay(hour: 20, minute: 0),
        isAfterFood: true,
        section: 'Night',
        selectedDays: [0, 3], // Monday, Thursday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final monday = DateTime(2026, 10, 12);
      final tuesday = DateTime(2026, 10, 13);
      final wednesday = DateTime(2026, 10, 14);
      final thursday = DateTime(2026, 10, 15);

      // Appears on Monday (0) and Thursday (3)
      expect(provider.getRemindersForDate(monday).map((r) => r.id), contains('r_recur'));
      expect(provider.getRemindersForDate(thursday).map((r) => r.id), contains('r_recur'));

      // Does NOT appear on Tuesday (1) or Wednesday (2)
      expect(provider.getRemindersForDate(tuesday), isEmpty);
      expect(provider.getRemindersForDate(wednesday), isEmpty);
    });

    test('Multiple medicines on the same date with mixed statuses adhere to precedence', () {
      final rem1 = Reminder(
        id: 'med_morning',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );

      final rem2 = Reminder(
        id: 'med_taken',
        name: 'Aspirin',
        dosage: '100mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );

      final rem3 = Reminder(
        id: 'med_afternoon',
        name: 'Multivitamin',
        dosage: '1 tablet',
        time: const TimeOfDay(hour: 14, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );

      provider.addReminder(rem1);
      provider.addReminder(rem2);
      provider.addReminder(rem3);

      final testMonday = DateTime(2026, 10, 12);
      final refTime = DateTime(2026, 10, 12, 10, 0); // 10:00 AM (past 08:00 AM window)

      // Confirm intake only for rem2
      provider.confirmIntake(rem2.id, date: testMonday);

      // Individual statuses
      expect(provider.getDoseStatus(rem1, testMonday, referenceNow: refTime), DoseStatus.missed);
      expect(provider.getDoseStatus(rem2, testMonday, referenceNow: refTime), DoseStatus.taken);
      expect(provider.getDoseStatus(rem3, testMonday, referenceNow: refTime), DoseStatus.upcoming);

      // Precedence: ANY missed -> overall day status is missed (Red)
      expect(provider.getDayStatus(testMonday, referenceNow: refTime), DayMedicationStatus.missed);

      // Counts
      expect(provider.getTotalCountForDate(testMonday), 3);
      expect(provider.getTakenCountForDate(testMonday, referenceNow: refTime), 1);
      expect(provider.getMissedCountForDate(testMonday, referenceNow: refTime), 1);
      expect(provider.getUpcomingCountForDate(testMonday, referenceNow: refTime), 1);
    });

    test('Completed day returns DayMedicationStatus.completed when all doses taken or skipped', () {
      final rem = Reminder(
        id: 'med_comp',
        name: 'Amoxicillin',
        dosage: '250mg',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [1], // Tuesday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final testTuesday = DateTime(2026, 10, 13);
      final refTime = DateTime(2026, 10, 13, 9, 30);

      // Initially missed if not taken past 15 min window
      expect(provider.getDayStatus(testTuesday, referenceNow: refTime), DayMedicationStatus.missed);

      // Mark taken -> Day completed
      provider.confirmIntake(rem.id, date: testTuesday);
      expect(provider.getDayStatus(testTuesday, referenceNow: refTime), DayMedicationStatus.completed);
    });

    test('Skipping a dose updates status and preserves skip reason', () {
      final rem = Reminder(
        id: 'med_skip',
        name: 'Omeprazole',
        dosage: '20mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [2], // Wednesday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      final wednesday = DateTime(2026, 10, 14);
      provider.skipDose(rem.id, date: wednesday, reason: "Doctor advised");

      expect(provider.getDoseStatus(rem, wednesday), DoseStatus.skipped);
      expect(provider.getDoseSkipped(rem.id, wednesday), isTrue);
      expect(provider.getDoseSkipReason(rem.id, wednesday), "Doctor advised");
      expect(provider.getSkippedCountForDate(wednesday), 1);
      expect(provider.getDayStatus(wednesday), DayMedicationStatus.completed);
    });
  });
}
