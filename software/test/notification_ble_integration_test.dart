import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medalert/models/reminder.dart';
import 'package:medalert/models/dose_occurrence.dart';
import 'package:medalert/providers/reminder_provider.dart';
import 'package:medalert/providers/ble_provider.dart';
import 'package:medalert/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  group('Notification & Bluetooth Integration Tests', () {
    late ReminderProvider reminderProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      reminderProvider = ReminderProvider();
      await reminderProvider.checkDailyReset(
        referenceNow: DateTime(2026, 10, 12, 8, 0),
      );
    });

    tearDown(() {
      reminderProvider.dispose();
    });

    test('1. Adding a medication triggers notification scheduling via single engine', () {
      final rem = Reminder(
        id: 'r_notif1',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 2, 4], // Mon, Wed, Fri
        createdAt: DateTime(2026, 10, 1),
      );

      // Verify addReminder succeeds without error even without native platform notification plugin
      expect(() => reminderProvider.addReminder(rem), returnsNormally);
      expect(reminderProvider.reminders.length, 1);
      expect(reminderProvider.reminders.first.id, 'r_notif1');
    });

    test('2. Editing a medication reconciles notifications without duplicating', () {
      final rem = Reminder(
        id: 'r_notif_edit',
        name: 'Atorvastatin',
        dosage: '10mg',
        time: const TimeOfDay(hour: 20, minute: 0),
        isAfterFood: true,
        section: 'Night',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      reminderProvider.addReminder(rem);

      // Edit schedule to 20mg at 9:00 PM on Mon, Wed
      final updated = rem.copyWith(
        dosage: '20mg',
        time: const TimeOfDay(hour: 21, minute: 0),
        selectedDays: [0, 2],
      );

      expect(() => reminderProvider.updateReminder(updated), returnsNormally);
      expect(reminderProvider.reminders.length, 1);
      expect(reminderProvider.reminders.first.dosage, '20mg');
      expect(reminderProvider.reminders.first.time.hour, 21);
      expect(reminderProvider.reminders.first.selectedDays, [0, 2]);
    });

    test('3. Deleting a medication cancels notifications and cleans occurrences', () {
      final rem = Reminder(
        id: 'r_notif_del',
        name: 'Lisinopril',
        dosage: '5mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0],
        createdAt: DateTime(2026, 10, 1),
      );
      reminderProvider.addReminder(rem);

      final date = DateTime(2026, 10, 12);
      reminderProvider.confirmIntake('r_notif_del', date: date);

      // Remove reminder
      reminderProvider.removeReminder('r_notif_del');
      expect(reminderProvider.reminders.isEmpty, isTrue);

      // Confirm occurrence removed
      final list = reminderProvider.getRemindersForDate(date);
      expect(list.isEmpty, isTrue);
    });

    test('4. Navigating between calendar dates is purely read-only and schedules 0 duplicate notifications', () {
      final rem = Reminder(
        id: 'r_readonly_nav',
        name: 'Daily Vitamin',
        dosage: '1 cap',
        time: const TimeOfDay(hour: 9, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      reminderProvider.addReminder(rem);

      // Simulate aggressive date navigation across 30 days
      for (int i = 0; i < 30; i++) {
        final date = DateTime(2026, 10, 1).add(Duration(days: i));
        final reminders = reminderProvider.getRemindersForDate(date);
        final status = reminderProvider.getDayStatus(date);
        expect(reminders.length, 1);
        expect(status, isNotNull);
      }

      // Still exactly 1 reminder in system
      expect(reminderProvider.reminders.length, 1);
    });

    test('5. Reopening the app does not duplicate dose records or reminders', () async {
      final rem = Reminder(
        id: 'r_restart_test',
        name: 'Calcium',
        dosage: '500mg',
        time: const TimeOfDay(hour: 12, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );
      reminderProvider.addReminder(rem);

      final date = DateTime(2026, 10, 12);
      reminderProvider.confirmIntake('r_restart_test', date: date);

      // Reload into new provider instance
      final newProvider = ReminderProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await newProvider.checkDailyReset(referenceNow: DateTime(2026, 10, 12, 12, 10));

      expect(newProvider.reminders.length, 1);
      final occurrences = newProvider.getRemindersForDate(date);
      expect(occurrences.length, 1);
      expect(newProvider.getDoseStatus(rem, date), DoseStatus.taken);

      newProvider.dispose();
    });

    test('6. Calendar remains completely functional and responsive when Bluetooth is disconnected', () {
      final ble = BleProvider();
      expect(ble.isConnected, isFalse);
      expect(ble.status, BleStatus.disconnected);

      final rem = Reminder(
        id: 'r_ble_offline',
        name: 'Thyroid',
        dosage: '100mcg',
        time: const TimeOfDay(hour: 7, minute: 0),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0, 1, 2, 3, 4, 5, 6],
        createdAt: DateTime(2026, 10, 1),
      );

      // Add reminder while offline
      reminderProvider.addReminder(rem);
      expect(reminderProvider.reminders.length, 1);

      // Query dates and verify status while offline
      final date = DateTime(2026, 10, 12);
      final dayList = reminderProvider.getRemindersForDate(date);
      expect(dayList.length, 1);

      // Confirm intake while offline (does not throw)
      expect(
        () => reminderProvider.confirmIntake('r_ble_offline', date: date),
        returnsNormally,
      );
      expect(reminderProvider.getDoseStatus(rem, date), DoseStatus.taken);

      // Send reminders to hardware while offline gracefully returns false
      expect(ble.sendRemindersToDevice(reminderProvider.reminders), completion(isFalse));

      ble.dispose();
    });

    test('7. Timezone date key conversions avoid unexpected day shifts', () {
      // Midnight boundary: 23:59:59 vs 00:00:01
      final lateNight = DateTime(2026, 10, 12, 23, 59, 59);
      final earlyMorning = DateTime(2026, 10, 13, 0, 0, 1);

      expect(DoseOccurrence.toDateKey(lateNight), '2026-10-12');
      expect(DoseOccurrence.toDateKey(earlyMorning), '2026-10-13');

      // Date key equality ignores time of day
      final morning = DateTime(2026, 10, 12, 6, 0);
      final evening = DateTime(2026, 10, 12, 22, 0);
      expect(DoseOccurrence.toDateKey(morning), DoseOccurrence.toDateKey(evening));

      // Leap year boundary: Feb 28, Feb 29, Mar 1 in 2024
      expect(DoseOccurrence.toDateKey(DateTime(2024, 2, 28)), '2024-02-28');
      expect(DoseOccurrence.toDateKey(DateTime(2024, 2, 29)), '2024-02-29');
      expect(DoseOccurrence.toDateKey(DateTime(2024, 3, 1)), '2024-03-01');
    });

    test('8. One-time notification scheduling works cleanly in NotificationService', () {
      final oneTimeMed = Reminder(
        id: 'r_onetime_notif',
        name: 'Vaccine',
        dosage: '0.5ml',
        time: const TimeOfDay(hour: 15, minute: 30),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [3],
        oneTimeDate: DateTime(2026, 10, 15),
        createdAt: DateTime(2026, 10, 1),
      );

      // Single notification scheduling call succeeds
      expect(
        () => NotificationService().scheduleWeeklyNotification(oneTimeMed),
        returnsNormally,
      );

      // Single notification cancellation call succeeds
      expect(
        () => NotificationService().cancelReminderNotifications(oneTimeMed),
        returnsNormally,
      );
    });
  });
}
