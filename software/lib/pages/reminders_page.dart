import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../models/reminder.dart';
import '../widgets/reminder_card.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, child) {
        final grouped = provider.getRemindersGroupedByDay();
        final isEmpty = provider.reminders.isEmpty;

        return Scaffold(
          backgroundColor: Colors.transparent, // inherited from shell
          body: SafeArea(
            child: isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 80,
                          color: Colors.green.shade100,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No reminders added yet",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F4D45),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Weekly Planner",
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F4D45),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ..._buildWeeklySections(context, grouped),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  List<Widget> _buildWeeklySections(
    BuildContext context,
    Map<int, List<Reminder>> grouped,
  ) {
    final List<String> days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    final int todayIndex = DateTime.now().weekday - 1; // 0 for Monday
    final List<Widget> sections = [];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    for (int i = 0; i < 7; i++) {
      final dayName = days[i];
      final dayReminders = grouped[i] ?? [];
      final isToday = i == todayIndex;

      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isToday)
                  Container(
                    width: 4,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                Text(
                  dayName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.green.shade700
                        : (isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF1F4D45)),
                  ),
                ),
                if (isToday)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Today",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (dayReminders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, left: 12.0),
                child: Text(
                  "No reminders",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...dayReminders.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ReminderCard(reminder: r),
                ),
              ),
            if (dayReminders.isNotEmpty) const SizedBox(height: 8),
          ],
        ),
      );
    }

    return sections;
  }
}
