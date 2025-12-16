enum Recurrence { none, daily, weekly, monthly, yearly }

extension RecurrenceNext on Recurrence {
  DateTime? next(DateTime? from) {
    if (from == null) return null;
    switch (this) {
      case Recurrence.none:
        return null;
      case Recurrence.daily:
        return from.add(const Duration(days: 1));
      case Recurrence.weekly:
        return from.add(const Duration(days: 7));
      case Recurrence.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour,
            from.minute, from.second, from.millisecond, from.microsecond);
      case Recurrence.yearly:
        return DateTime(from.year + 1, from.month, from.day, from.hour,
            from.minute, from.second, from.millisecond, from.microsecond);
    }
  }
}
