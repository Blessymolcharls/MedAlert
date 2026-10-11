import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/reminder_provider.dart';
import '../../models/reminder.dart';
import 'medication_timeline_card.dart';
import 'empty_schedule_state.dart';

class DayMedicationAgenda extends StatelessWidget {
  final DateTime selectedDate;

  const DayMedicationAgenda({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ReminderProvider>(context);

    final reminders = provider.getRemindersForDate(selectedDate);
    final total = provider.getTotalCountForDate(selectedDate);
    final taken = provider.getTakenCountForDate(selectedDate);
    final upcoming = provider.getUpcomingCountForDate(selectedDate);
    final missed = provider.getMissedCountForDate(selectedDate);

    if (reminders.isEmpty) {
      return EmptyScheduleState(date: selectedDate);
    }

    final double progress = total > 0 ? (taken / total) : 0.0;
    final int percent = (progress * 100).round();

    // Group reminders by section/time of day
    final Map<String, List<Reminder>> sections = {
      'Morning': [],
      'Noon': [],
      'Night': [],
    };

    for (var r in reminders) {
      if (r.time.hour < 12) {
        sections['Morning']!.add(r);
      } else if (r.time.hour < 17) {
        sections['Noon']!.add(r);
      } else {
        sections['Night']!.add(r);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Progress Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$taken of $total doses completed',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F4D45),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F4D45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : const Color(0xFF1F4D45).withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1F4D45),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Status summary chips
              Row(
                children: [
                  _buildStatusPill(
                    '$taken Taken',
                    Colors.green.shade50,
                    Colors.green.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(
                    '$upcoming Upcoming',
                    Colors.orange.shade50,
                    Colors.orange.shade900,
                  ),
                  if (missed > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatusPill(
                      '$missed Missed',
                      Colors.red.shade50,
                      Colors.red.shade800,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sectioned Timeline
        ...sections.entries.where((e) => e.value.isNotEmpty).map((entry) {
          final sectionName = entry.key;
          final sectionReminders = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sectionName == 'Morning'
                          ? Icons.wb_sunny_outlined
                          : (sectionName == 'Noon'
                              ? Icons.wb_twilight_outlined
                              : Icons.nightlight_outlined),
                      size: 18,
                      color: const Color(0xFF1F4D45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sectionName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F4D45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...sectionReminders.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: MedicationTimelineCard(
                      reminder: r,
                      occurrenceDate: selectedDate,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusPill(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
