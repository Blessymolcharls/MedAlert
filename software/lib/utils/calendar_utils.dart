/// Pure utilities for calendar arithmetic, formatting, and navigation.
class CalendarUtils {
  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> shortWeekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Returns true if [year] is a leap year.
  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Returns the number of days in the specified [month] of [year].
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      return isLeapYear(year) ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  /// Returns the 0-indexed weekday of the 1st of [month] in [year] (0 = Monday, 6 = Sunday).
  static int startWeekdayOfMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday - 1; // DateTime.weekday is 1 (Mon) to 7 (Sun)
  }

  /// Returns the Monday representing the start of the week for [date].
  static DateTime getMondayOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final daysToSubtract = clean.weekday - 1; // 0 for Mon, 6 for Sun
    return clean.subtract(Duration(days: daysToSubtract));
  }

  /// Returns all 7 [DateTime] instances from Monday to Sunday for the week of [date].
  static List<DateTime> getWeekDates(DateTime date) {
    final monday = getMondayOfWeek(date);
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Safely navigates to the previous month, crossing year boundaries.
  static DateTime previousMonth(DateTime date) {
    if (date.month == 1) {
      final targetYear = date.year - 1;
      final maxDays = daysInMonth(targetYear, 12);
      final day = date.day > maxDays ? maxDays : date.day;
      return DateTime(targetYear, 12, day);
    } else {
      final targetMonth = date.month - 1;
      final maxDays = daysInMonth(date.year, targetMonth);
      final day = date.day > maxDays ? maxDays : date.day;
      return DateTime(date.year, targetMonth, day);
    }
  }

  /// Safely navigates to the next month, crossing year boundaries.
  static DateTime nextMonth(DateTime date) {
    if (date.month == 12) {
      final targetYear = date.year + 1;
      final maxDays = daysInMonth(targetYear, 1);
      final day = date.day > maxDays ? maxDays : date.day;
      return DateTime(targetYear, 1, day);
    } else {
      final targetMonth = date.month + 1;
      final maxDays = daysInMonth(date.year, targetMonth);
      final day = date.day > maxDays ? maxDays : date.day;
      return DateTime(date.year, targetMonth, day);
    }
  }

  /// Navigates to the previous week (7 days earlier).
  static DateTime previousWeek(DateTime date) {
    return date.subtract(const Duration(days: 7));
  }

  /// Navigates to the next week (7 days later).
  static DateTime nextWeek(DateTime date) {
    return date.add(const Duration(days: 7));
  }

  /// Navigates to the previous day (1 day earlier).
  static DateTime previousDay(DateTime date) {
    return date.subtract(const Duration(days: 1));
  }

  /// Navigates to the next day (1 day later).
  static DateTime nextDay(DateTime date) {
    return date.add(const Duration(days: 1));
  }

  /// Checks if two [DateTime] instances represent the same calendar day.
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Formats month and year: e.g. "October 2026"
  static String formatMonthYear(DateTime date) {
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  /// Formats a week range: e.g. "Oct 12 – Oct 18, 2026"
  static String formatWeekRange(DateTime date) {
    final monday = getMondayOfWeek(date);
    final sunday = monday.add(const Duration(days: 6));

    final monMonth = shortMonthNames[monday.month - 1];
    final sunMonth = shortMonthNames[sunday.month - 1];

    if (monday.year != sunday.year) {
      return '$monMonth ${monday.day}, ${monday.year} – $sunMonth ${sunday.day}, ${sunday.year}';
    } else if (monday.month != sunday.month) {
      return '$monMonth ${monday.day} – $sunMonth ${sunday.day}, ${monday.year}';
    } else {
      return '$monMonth ${monday.day} – ${sunday.day}, ${monday.year}';
    }
  }

  /// Formats full day heading: e.g. "Monday, October 12"
  static String formatFullDate(DateTime date) {
    final weekday = weekdayNames[date.weekday - 1];
    final month = monthNames[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  /// Formats full date with year: e.g. "Monday, Oct 12, 2026"
  static String formatFullDateWithYear(DateTime date) {
    final weekday = weekdayNames[date.weekday - 1];
    final month = shortMonthNames[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }
}
