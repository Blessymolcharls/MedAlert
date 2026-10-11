import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/dose_occurrence.dart';
import '../../providers/reminder_provider.dart';
import '../../utils/calendar_utils.dart';

class MonthCalendarGrid extends StatelessWidget {
  final DateTime displayMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const MonthCalendarGrid({
    super.key,
    required this.displayMonth,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDays = CalendarUtils.daysInMonth(
      displayMonth.year,
      displayMonth.month,
    );
    final firstWeekday = CalendarUtils.startWeekdayOfMonth(
      displayMonth.year,
      displayMonth.month,
    ); // 0=Mon, 6=Sun

    return Container(
      padding: const EdgeInsets.all(12),
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        children: [
          // Weekday Labels Row (Mon - Sun)
          _buildWeekdayHeader(isDark),
          const SizedBox(height: 8),

          // Days Grid
          _buildDaysGrid(context, totalDays, firstWeekday, isDark),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(bool isDark) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: labels.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid(
    BuildContext context,
    int totalDays,
    int firstWeekday,
    bool isDark,
  ) {
    final provider = Provider.of<ReminderProvider>(context);
    final now = DateTime.now();

    // Total cells in the grid (multiples of 7)
    final totalSlots = ((firstWeekday + totalDays + 6) ~/ 7) * 7;
    final List<Widget> dayCells = [];

    for (int i = 0; i < totalSlots; i++) {
      final dayNumber = i - firstWeekday + 1;

      if (dayNumber < 1 || dayNumber > totalDays) {
        // Empty offset cell
        dayCells.add(const Expanded(child: SizedBox(height: 48)));
      } else {
        final cellDate = DateTime(
          displayMonth.year,
          displayMonth.month,
          dayNumber,
        );
        final isSelected = CalendarUtils.isSameDay(cellDate, selectedDate);
        final isToday = CalendarUtils.isSameDay(cellDate, now);

        final doseStatuses = provider.getDoseStatusesForDate(cellDate);
        final dayStatus = provider.getDayStatus(cellDate);

        dayCells.add(
          Expanded(
            child: _buildDayCell(
              context: context,
              date: cellDate,
              dayNumber: dayNumber,
              isSelected: isSelected,
              isToday: isToday,
              doseStatuses: doseStatuses,
              dayStatus: dayStatus,
              isDark: isDark,
            ),
          ),
        );
      }
    }

    // Group into rows of 7
    final List<Widget> rows = [];
    for (int i = 0; i < dayCells.length; i += 7) {
      final rowChildren = dayCells.sublist(i, i + 7);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(children: rowChildren),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell({
    required BuildContext context,
    required DateTime date,
    required int dayNumber,
    required bool isSelected,
    required bool isToday,
    required List<DoseStatus> doseStatuses,
    required DayMedicationStatus dayStatus,
    required bool isDark,
  }) {
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color cellBg = Colors.transparent;

    if (isSelected) {
      textColor = Colors.white;
      cellBg = const Color(0xFF1F4D45); // Deep forest green
    } else if (isToday) {
      cellBg = const Color(0xFF1F4D45).withValues(alpha: 0.12);
      textColor = const Color(0xFF1F4D45);
    }

    return GestureDetector(
      key: Key('calendar_day_${date.year}_${date.month}_${date.day}'),
      onTap: () => onDateSelected(date),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday && !isSelected
                ? const Color(0xFF1F4D45)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            _buildDoseIndicators(doseStatuses, isSelected),
          ],
        ),
      ),
    );
  }

  /// Compact indicators for scheduled doses.
  /// Shows individual dots (up to 3) colored by dose state,
  /// plus a "+" indicator if more than 3 doses are scheduled.
  Widget _buildDoseIndicators(List<DoseStatus> statuses, bool isSelected) {
    if (statuses.isEmpty) {
      return const SizedBox(height: 5);
    }

    final maxDots = statuses.take(3).toList();
    final hasOverflow = statuses.length > 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...maxDots.map((status) {
          Color dotColor;
          switch (status) {
            case DoseStatus.taken:
            case DoseStatus.skipped:
              dotColor = isSelected
                  ? const Color(0xFF81C784)
                  : const Color(0xFF2E7D32);
              break;
            case DoseStatus.missed:
              dotColor = isSelected
                  ? const Color(0xFFFF8A80)
                  : const Color(0xFFD32F2F);
              break;
            case DoseStatus.pending:
            case DoseStatus.upcoming:
              dotColor = isSelected
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFFF57F17);
              break;
          }

          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          );
        }),
        if (hasOverflow)
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(left: 1),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white70 : Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
