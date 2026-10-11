import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/dose_occurrence.dart';
import '../../providers/reminder_provider.dart';
import '../../utils/calendar_utils.dart';

class WeekDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekDates = CalendarUtils.getWeekDates(selectedDate);
    final now = DateTime.now();
    final provider = Provider.of<ReminderProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDates.map((date) {
          final isSelected = CalendarUtils.isSameDay(date, selectedDate);
          final isToday = CalendarUtils.isSameDay(date, now);
          final doseStatuses = provider.getDoseStatusesForDate(date);
          final weekdayShort = CalendarUtils.shortWeekdayNames[date.weekday - 1];

          final semanticLabel =
              '$weekdayShort, ${date.day}${isToday ? ", today" : ""}'
              '${doseStatuses.isEmpty ? ", no doses scheduled" : ", ${doseStatuses.length} doses scheduled"}';

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: semanticLabel,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('week_day_${date.year}_${date.month}_${date.day}'),
                  onTap: () => onDateSelected(date),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    constraints: const BoxConstraints(minHeight: 64),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1F4D45)
                          : (isToday
                              ? const Color(0xFF1F4D45).withValues(alpha: 0.1)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday && !isSelected
                            ? const Color(0xFF1F4D45)
                            : (isSelected
                                ? const Color(0xFF1F4D45)
                                : Colors.transparent),
                        width: isToday && !isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        if (isSelected && !isDark)
                          BoxShadow(
                            color: const Color(0xFF1F4D45).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Weekday Short Name
                        Text(
                          weekdayShort,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? Colors.white70
                                : (isToday
                                    ? const Color(0xFF1F4D45)
                                    : Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Date Number
                        Text(
                          '${date.day}',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Dose Indicators
                        _buildDoseIndicators(doseStatuses, isSelected),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
