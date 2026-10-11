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
    final dueNow = provider.getDueNowCountForDate(selectedDate);
    final upcoming = provider.getUpcomingCountForDate(selectedDate);
    final missed = provider.getMissedCountForDate(selectedDate);
    final skipped = provider.getSkippedCountForDate(selectedDate);

    final dateHeading = CalendarUtils.formatFullDate(selectedDate);

    // Build the dynamic summary string
    final List<String> parts = [
      '$total scheduled',
      '$taken taken',
      if (dueNow > 0) '$dueNow due now',
      if ((upcoming - dueNow) > 0 || (total == 0)) '${upcoming - dueNow} upcoming',
      if (missed > 0) '$missed missed',
      if (skipped > 0) '$skipped skipped',
    ];
    final summaryText = parts.join(' · ');

    return Semantics(
      container: true,
      label: '$dateHeading: $summaryText',
      child: Column(
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
          if (total > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (taken > 0)
                  _buildMiniStatChip(
                    icon: Icons.check_circle_rounded,
                    label: '$taken taken',
                    bg: Colors.green.withValues(alpha: 0.12),
                    textColor: Colors.green.shade800,
                  ),
                if (dueNow > 0)
                  _buildMiniStatChip(
                    icon: Icons.notification_important_rounded,
                    label: '$dueNow due now',
                    bg: Colors.orange.withValues(alpha: 0.15),
                    textColor: Colors.orange.shade900,
                  ),
                if (missed > 0)
                  _buildMiniStatChip(
                    icon: Icons.cancel_rounded,
                    label: '$missed missed',
                    bg: Colors.red.withValues(alpha: 0.12),
                    textColor: Colors.red.shade800,
                  ),
                if ((upcoming - dueNow) > 0)
                  _buildMiniStatChip(
                    icon: Icons.schedule_rounded,
                    label: '${upcoming - dueNow} upcoming',
                    bg: const Color(0xFF1F4D45).withValues(alpha: 0.08),
                    textColor: const Color(0xFF1F4D45),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStatChip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
