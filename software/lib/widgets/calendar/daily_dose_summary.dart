import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/reminder_provider.dart';
import '../../utils/calendar_utils.dart';

class DailyDoseSummary extends StatelessWidget {
  final DateTime selectedDate;

  const DailyDoseSummary({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ReminderProvider>(context);

    final total = provider.getTotalCountForDate(selectedDate);
    final taken = provider.getTakenCountForDate(selectedDate);
    final upcoming = provider.getUpcomingCountForDate(selectedDate);
    final missed = provider.getMissedCountForDate(selectedDate);
    final skipped = provider.getSkippedCountForDate(selectedDate);

    final dateHeading = CalendarUtils.formatFullDate(selectedDate);

    // Build the dynamic summary string
    final List<String> parts = [
      '$total scheduled',
      '$taken taken',
      if (upcoming > 0 || total == 0) '$upcoming upcoming',
      if (missed > 0) '$missed missed',
      if (skipped > 0) '$skipped skipped',
    ];
    final summaryText = parts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Heading
        Text(
          dateHeading,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F4D45),
          ),
        ),
        const SizedBox(height: 4),

        // Summary Text
        Text(
          summaryText,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
