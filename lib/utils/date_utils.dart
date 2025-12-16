import 'package:intl/intl.dart';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime date) => isSameDay(date, DateTime.now());

bool isYesterday(DateTime date) =>
    isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

bool isTomorrow(DateTime date) =>
    isSameDay(date, DateTime.now().add(const Duration(days: 1)));

String formatDueDate(DateTime? date, {bool allDay = false}) {
  if (date == null) return 'No date';
  if (allDay) {
    return DateFormat.yMMMd().format(date);
  }
  return DateFormat.yMMMd().add_jm().format(date);
}

String formatShortTime(DateTime date) => DateFormat.jm().format(date);
