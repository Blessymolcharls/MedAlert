import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medalert/models/reminder.dart';
import 'package:medalert/providers/reminder_provider.dart';
import 'package:medalert/pages/reminders_page.dart';
import 'package:medalert/widgets/calendar/calendar_view_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  group('Medication Calendar Widget Tests', () {
    late ReminderProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = ReminderProvider();
      await provider.checkDailyReset(referenceNow: DateTime(2026, 10, 12, 8, 0));
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestApp({CalendarViewType initialView = CalendarViewType.month}) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ReminderProvider>.value(
            value: provider,
            child: RemindersPage(
              initialView: initialView,
              initialDate: DateTime(2026, 10, 12), // Monday
            ),
          ),
        ),
      );
    }

    testWidgets('Renders Month view with calendar grid, summary, and medication cards', (
      WidgetTester tester,
    ) async {
      // Add a test reminder scheduled for Monday (0)
      final rem = Reminder(
        id: 'r_mon',
        name: 'Metformin',
        dosage: '500mg',
        time: const TimeOfDay(hour: 8, minute: 0),
        isAfterFood: true,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(rem);

      await tester.pumpWidget(createTestApp(initialView: CalendarViewType.month));
      await tester.pumpAndSettle();

      // Check Header & Screen Title
      expect(find.text('Medication Calendar'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);

      // Check Summary & Medication Card for Oct 12
      expect(find.text('Monday, October 12'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('500mg'), findsOneWidget);
      expect(find.text('After Food'), findsOneWidget);
    });

    testWidgets('Switching views preserves the synchronized selected date', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(initialView: CalendarViewType.month));
      await tester.pumpAndSettle();

      // Select date 14 (Wednesday, Oct 14) in Month grid
      final day14Finder = find.byKey(const Key('calendar_day_2026_10_14'));
      expect(day14Finder, findsOneWidget);
      await tester.tap(day14Finder);
      await tester.pumpAndSettle();

      // Summary heading updates to Wednesday, October 14
      expect(find.text('Wednesday, October 14'), findsOneWidget);

      // Switch to Week View
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      // Week view should still have Oct 14 active and selected
      expect(find.text('Wednesday, October 14'), findsOneWidget);
      expect(find.byKey(const Key('week_day_2026_10_14')), findsOneWidget);

      // Switch to Day View
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      // Day view agenda displays Wednesday, Oct 14, 2026 with empty state
      expect(find.text('Wednesday, Oct 14, 2026'), findsOneWidget);
      expect(find.text('No medications scheduled'), findsOneWidget);
    });

    testWidgets('Day View displays progress indicator and section grouping', (
      WidgetTester tester,
    ) async {
      final remMorning = Reminder(
        id: 'r_morn',
        name: 'Thyroxine',
        dosage: '50mcg',
        time: const TimeOfDay(hour: 7, minute: 0),
        isAfterFood: false,
        section: 'Morning',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );
      final remNoon = Reminder(
        id: 'r_noon',
        name: 'Calcium',
        dosage: '500mg',
        time: const TimeOfDay(hour: 13, minute: 0),
        isAfterFood: true,
        section: 'Noon',
        selectedDays: [0], // Monday
        createdAt: DateTime(2026, 10, 1),
      );
      provider.addReminder(remMorning);
      provider.addReminder(remNoon);

      await tester.pumpWidget(createTestApp(initialView: CalendarViewType.day));
      await tester.pumpAndSettle();

      // Initial progress: 0 of 2 completed
      expect(find.text('0 of 2 doses completed'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Noon'), findsOneWidget);

      // Mark morning dose taken
      provider.confirmIntake('r_morn', date: DateTime(2026, 10, 12));
      await tester.pumpAndSettle();

      // Updated progress: 1 of 2 doses completed (50%)
      expect(find.text('1 of 2 doses completed'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('Empty date displays friendly EmptyScheduleState with Add Reminder action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(initialView: CalendarViewType.month));
      await tester.pumpAndSettle();

      // Tap on day 15 (Thursday, Oct 15) which has no reminders
      await tester.tap(find.byKey(const Key('calendar_day_2026_10_15')));
      await tester.pumpAndSettle();

      // Verify empty state widget
      expect(find.text('No medications scheduled'), findsOneWidget);
      expect(find.byKey(const Key('empty_state_add_button')), findsOneWidget);
    });

    testWidgets('Navigation toolbar Today button returns to current local date', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(initialView: CalendarViewType.month));
      await tester.pumpAndSettle();

      // Navigate to previous month
      await tester.tap(find.byKey(const Key('calendar_prev_button')));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);

      // Tap Today button
      await tester.tap(find.byKey(const Key('calendar_today_button')));
      await tester.pumpAndSettle();

      // Returns to current month
      expect(find.text('October 2026'), findsOneWidget);
    });
  });
}
