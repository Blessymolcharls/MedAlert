import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medalert/models/reminder.dart';
import 'package:medalert/providers/reminder_provider.dart';
import 'package:medalert/widgets/reminder_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  testWidgets('ReminderCard displays delete button and confirms deletion', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final reminder = Reminder(
      id: 'test-123',
      name: 'Aspirin',
      dosage: '100mg',
      time: const TimeOfDay(hour: 9, minute: 0),
      isAfterFood: true,
      section: 'Morning',
      selectedDays: [0, 1, 2, 3, 4, 5, 6],
      createdAt: DateTime.now(),
    );

    final provider = ReminderProvider();
    provider.addReminder(reminder);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ReminderProvider>.value(
            value: provider,
            child: ReminderCard(reminder: reminder),
          ),
        ),
      ),
    );

    // Verify reminder details and delete button exist
    expect(find.text('Aspirin'), findsOneWidget);
    expect(find.byKey(const Key('delete_reminder_test-123')), findsOneWidget);

    // Tap the delete button
    await tester.tap(find.byKey(const Key('delete_reminder_test-123')));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('Delete Task'), findsOneWidget);
    expect(
      find.text("Are you sure you want to delete 'Aspirin'?"),
      findsOneWidget,
    );

    // Tap Delete button in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify reminder is removed from provider
    expect(provider.reminders.any((r) => r.id == 'test-123'), isFalse);

    provider.dispose();
  });
}
