import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/reminder.dart';
import '../../models/dose_occurrence.dart';
import '../../providers/reminder_provider.dart';
import '../../utils/calendar_utils.dart';

class MedicationDetailsDialog extends StatelessWidget {
  final Reminder reminder;
  final DateTime occurrenceDate;

  const MedicationDetailsDialog({
    super.key,
    required this.reminder,
    required this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final status = provider.getDoseStatus(reminder, occurrenceDate);
    final takenAt = provider.getDoseTakenAt(reminder.id, occurrenceDate);
    final skipReason = provider.getDoseSkipReason(reminder.id, occurrenceDate);

    Color statusBadgeColor;
    Color statusTextColor;
    switch (status) {
      case DoseStatus.taken:
        statusBadgeColor = Colors.green.shade50;
        statusTextColor = Colors.green.shade800;
        break;
      case DoseStatus.missed:
        statusBadgeColor = Colors.red.shade50;
        statusTextColor = Colors.red.shade800;
        break;
      case DoseStatus.pending:
        statusBadgeColor = Colors.orange.shade50;
        statusTextColor = Colors.orange.shade900;
        break;
      case DoseStatus.upcoming:
        statusBadgeColor = Colors.blue.shade50;
        statusTextColor = Colors.blue.shade800;
        break;
      case DoseStatus.skipped:
        statusBadgeColor = Colors.grey.shade200;
        statusTextColor = Colors.grey.shade800;
        break;
    }

    final scheduledTimeStr = reminder.time.format(context);
    final dateStr = CalendarUtils.formatFullDateWithYear(occurrenceDate);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F4D45).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: Color(0xFF1F4D45),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F4D45),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(
              icon: Icons.scale_outlined,
              label: 'Dosage',
              value: reminder.dosage,
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Schedule Date',
              value: dateStr,
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Scheduled Time',
              value: scheduledTimeStr,
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.restaurant_outlined,
              label: 'Food Instruction',
              value: reminder.isAfterFood ? 'After Food' : 'Before Food',
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.info_outline,
              label: 'Dose Status',
              widgetValue: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBadgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
              isDark: isDark,
            ),
            if (status == DoseStatus.taken && takenAt != null) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.check_circle_outline,
                label: 'Completed At',
                value: TimeOfDay.fromDateTime(takenAt).format(context),
                isDark: isDark,
              ),
            ],
            if (status == DoseStatus.skipped && skipReason != null) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.not_interested,
                label: 'Skip Reason',
                value: skipReason,
                isDark: isDark,
              ),
            ],
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.repeat_rounded,
              label: 'Active Days',
              value: reminder.selectedDays
                  .map((d) => CalendarUtils.shortWeekdayNames[d])
                  .join(', '),
              isDark: isDark,
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F4D45),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Close',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? widgetValue,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        if (widgetValue != null)
          widgetValue
        else
          Text(
            value ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F4D45),
            ),
          ),
      ],
    );
  }
}
