import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum CalendarViewType { month, week, day }

class CalendarViewSelector extends StatelessWidget {
  final CalendarViewType currentView;
  final ValueChanged<CalendarViewType> onViewChanged;

  const CalendarViewSelector({
    super.key,
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    const activeColor = Color(0xFF1F4D45);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment('Month', CalendarViewType.month, activeColor),
          _buildSegment('Week', CalendarViewType.week, activeColor),
          _buildSegment('Day', CalendarViewType.day, activeColor),
        ],
      ),
    );
  }

  Widget _buildSegment(
    String label,
    CalendarViewType viewType,
    Color activeColor,
  ) {
    final isSelected = currentView == viewType;

    return GestureDetector(
      onTap: () => onViewChanged(viewType),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
