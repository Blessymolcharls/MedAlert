import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'calendar_view_selector.dart';

class CalendarHeader extends StatelessWidget {
  final String periodTitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final CalendarViewType currentView;
  final ValueChanged<CalendarViewType> onViewChanged;
  final bool isCurrentPeriod;

  const CalendarHeader({
    super.key,
    required this.periodTitle,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.currentView,
    required this.onViewChanged,
    this.isCurrentPeriod = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF1F4D45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & View Selector Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medication Calendar',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track and manage scheduled doses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            CalendarViewSelector(
              currentView: currentView,
              onViewChanged: onViewChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Navigation Toolbar Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
          child: Row(
            children: [
              // Previous Period Button
              IconButton(
                key: const Key('calendar_prev_button'),
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                color: const Color(0xFF1F4D45),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Previous period',
                onPressed: onPrevious,
              ),

              // Period Title
              Expanded(
                child: Text(
                  periodTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F4D45),
                  ),
                ),
              ),

              // Next Period Button
              IconButton(
                key: const Key('calendar_next_button'),
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                color: const Color(0xFF1F4D45),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Next period',
                onPressed: onNext,
              ),

              const SizedBox(width: 4),

              // Today Action Button
              TextButton(
                key: const Key('calendar_today_button'),
                onPressed: onToday,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  backgroundColor: isCurrentPeriod
                      ? const Color(0xFF1F4D45).withValues(alpha: 0.1)
                      : const Color(0xFF1F4D45),
                  foregroundColor:
                      isCurrentPeriod ? const Color(0xFF1F4D45) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Today',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
