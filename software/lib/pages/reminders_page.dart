import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/calendar_utils.dart';
import '../widgets/calendar/calendar_header.dart';
import '../widgets/calendar/calendar_view_selector.dart';
import '../widgets/calendar/month_calendar_grid.dart';
import '../widgets/calendar/week_date_selector.dart';
import '../widgets/calendar/daily_dose_summary.dart';
import '../widgets/calendar/day_medication_agenda.dart';
import '../widgets/calendar/medication_timeline_card.dart';
import '../widgets/calendar/empty_schedule_state.dart';

class RemindersPage extends StatefulWidget {
  final CalendarViewType initialView;
  final DateTime? initialDate;

  const RemindersPage({
    super.key,
    this.initialView = CalendarViewType.month,
    this.initialDate,
  });

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  late CalendarViewType _currentView;
  late DateTime _selectedDate;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
    final now = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _displayMonth = DateTime(now.year, now.month, 1);
  }

  void _onViewChanged(CalendarViewType newView) {
    setState(() {
      _currentView = newView;
      _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _displayMonth = DateTime(date.year, date.month, 1);
    });
  }

  void _onPrevious() {
    setState(() {
      switch (_currentView) {
        case CalendarViewType.month:
          _displayMonth = CalendarUtils.previousMonth(_displayMonth);
          final maxDays = CalendarUtils.daysInMonth(
            _displayMonth.year,
            _displayMonth.month,
          );
          final day = _selectedDate.day > maxDays ? maxDays : _selectedDate.day;
          _selectedDate = DateTime(_displayMonth.year, _displayMonth.month, day);
          break;
        case CalendarViewType.week:
          _selectedDate = CalendarUtils.previousWeek(_selectedDate);
          _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
          break;
        case CalendarViewType.day:
          _selectedDate = CalendarUtils.previousDay(_selectedDate);
          _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
          break;
      }
    });
  }

  void _onNext() {
    setState(() {
      switch (_currentView) {
        case CalendarViewType.month:
          _displayMonth = CalendarUtils.nextMonth(_displayMonth);
          final maxDays = CalendarUtils.daysInMonth(
            _displayMonth.year,
            _displayMonth.month,
          );
          final day = _selectedDate.day > maxDays ? maxDays : _selectedDate.day;
          _selectedDate = DateTime(_displayMonth.year, _displayMonth.month, day);
          break;
        case CalendarViewType.week:
          _selectedDate = CalendarUtils.nextWeek(_selectedDate);
          _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
          break;
        case CalendarViewType.day:
          _selectedDate = CalendarUtils.nextDay(_selectedDate);
          _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
          break;
      }
    });
  }

  void _onToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayMonth = DateTime(now.year, now.month, 1);
    });
  }

  String _getPeriodTitle() {
    switch (_currentView) {
      case CalendarViewType.month:
        return CalendarUtils.formatMonthYear(_displayMonth);
      case CalendarViewType.week:
        return CalendarUtils.formatWeekRange(_selectedDate);
      case CalendarViewType.day:
        return CalendarUtils.formatFullDateWithYear(_selectedDate);
    }
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    switch (_currentView) {
      case CalendarViewType.month:
        return _displayMonth.year == now.year &&
            _displayMonth.month == now.month;
      case CalendarViewType.week:
        final mondaySelected = CalendarUtils.getMondayOfWeek(_selectedDate);
        final mondayNow = CalendarUtils.getMondayOfWeek(now);
        return CalendarUtils.isSameDay(mondaySelected, mondayNow);
      case CalendarViewType.day:
        return CalendarUtils.isSameDay(_selectedDate, now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReminderProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F4D45)),
            ),
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom + 48.0;

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherited from MainShell
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Navigation Toolbar
              CalendarHeader(
                periodTitle: _getPeriodTitle(),
                onPrevious: _onPrevious,
                onNext: _onNext,
                onToday: _onToday,
                currentView: _currentView,
                onViewChanged: _onViewChanged,
                isCurrentPeriod: _isCurrentPeriod(),
              ),
              const SizedBox(height: 16),
              if (provider.errorMessage != null) ...[
                Container(
                  key: const Key('calendar_error_banner'),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF5350)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('calendar_error_dismiss'),
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFFC62828)),
                        onPressed: provider.clearError,
                        tooltip: 'Dismiss error',
                      ),
                    ],
                  ),
                ),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentView),
                  child: _currentView == CalendarViewType.month
                      ? _buildMonthView(context)
                      : (_currentView == CalendarViewType.week
                          ? _buildWeekView(context)
                          : DayMedicationAgenda(selectedDate: _selectedDate)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monthly Calendar Grid
        MonthCalendarGrid(
          displayMonth: _displayMonth,
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
        ),
        const SizedBox(height: 20),

        // Selected-Day Summary
        DailyDoseSummary(selectedDate: _selectedDate),
        const SizedBox(height: 14),

        // Selected Day Medication Timeline
        _buildMedicationTimeline(context),
      ],
    );
  }

  Widget _buildWeekView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 7-Day Date Selector
        WeekDateSelector(
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
        ),
        const SizedBox(height: 20),

        // Selected-Day Summary
        DailyDoseSummary(selectedDate: _selectedDate),
        const SizedBox(height: 14),

        // Selected Day Medication Timeline
        _buildMedicationTimeline(context),
      ],
    );
  }

  Widget _buildMedicationTimeline(BuildContext context) {
    final provider = Provider.of<ReminderProvider>(context);
    final reminders = provider.getRemindersForDate(_selectedDate);

    if (reminders.isEmpty) {
      return EmptyScheduleState(date: _selectedDate);
    }

    return Column(
      children: reminders.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: MedicationTimelineCard(
            key: Key('timeline_card_${r.id}_${_selectedDate.day}'),
            reminder: r,
            occurrenceDate: _selectedDate,
          ),
        );
      }).toList(),
    );
  }
}
