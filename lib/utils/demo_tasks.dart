import '../models/recurrence.dart';
import '../models/task.dart';

/// Tasks for the Settings "Add demo tasks" button, laid out around [now] so
/// every row state is on screen at once: each section, NOW, soon, late by one
/// and several days, flag and bell in every combination, all-day, repeating,
/// tags (one long, one extra), a long title and completed history.
///
/// Each note says what the task is there to exercise. Times are relative, so
/// run it late in the evening and the "later today" rows drop out, and just
/// after midnight the "earlier today" row lands in Overdue.
List<Task> buildDemoTasks(DateTime now) {
  DateTime today(int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day, hour, minute);
  DateTime day(int offset, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);
  DateTime ago({int days = 0, int hours = 0, int minutes = 0}) =>
      now.subtract(Duration(days: days, hours: hours, minutes: minutes));
  DateTime ahead({int hours = 0, int minutes = 0}) =>
      now.add(Duration(hours: hours, minutes: minutes));

  return <Task>[
    // Overdue
    Task(
      title: 'Submit the DBMS lab record',
      notes: 'Late by 2 days: bold meta, filled flag, bell.',
      dueDateTime: day(-2, 9, 30),
      priority: Priority.high,
      reminderMinutes: 30,
      tags: ['college'],
    ),
    Task(
      title: 'Pay hostel mess fee',
      notes: 'Late by 1 day: singular wording, no flag, no bell.',
      dueDateTime: day(-1, 17),
      tags: ['personal'],
    ),
    Task(
      title: 'Return the borrowed oscilloscope',
      notes: 'All-day and late: no time, just the date and days late.',
      dueDateTime: day(-3, 0),
      allDay: true,
      priority: Priority.high,
      tags: ['robotics'],
    ),

    // Today
    Task(
      title: 'Reply to Prof. Sen about the minor project',
      notes: 'NOW: due 10 minutes ago. Grey fill, NOW tag, bold title.',
      dueDateTime: ago(minutes: 10),
      reminderMinutes: 0,
      tags: ['college'],
    ),
    Task(
      title: 'Robotics Club budget sheet',
      notes:
          'Soon: 18 minutes ahead. Lighter fill, bold "In 18 min". '
          'Reminder fires 5 minutes before.',
      dueDateTime: ahead(minutes: 18),
      priority: Priority.high,
      reminderMinutes: 5,
      tags: ['robotics'],
    ),
    Task(
      title: 'Book a lab slot for Friday',
      notes: 'Soon: 55 minutes ahead, still inside the 60 minute window.',
      dueDateTime: ahead(minutes: 55),
      tags: ['college'],
    ),
    if (now.hour >= 3)
      Task(
        title: 'Morning standup notes',
        notes: 'Earlier today, outside NOW: plain time, not late.',
        dueDateTime: ago(hours: 2, minutes: 30),
        reminderMinutes: 10,
      ),
    if (now.isBefore(today(21)))
      Task(
        title: 'Laundry before the hostel curfew',
        notes: 'Later today: time only.',
        dueDateTime: today(21, 30),
        priority: Priority.high,
        tags: ['personal'],
      ),
    Task(
      title: 'Water the plants',
      notes: 'Repeats daily: complete it and it moves to tomorrow.',
      dueDateTime: now.isBefore(today(22)) ? today(22) : day(1, 22),
      recurrence: Recurrence.daily,
      reminderMinutes: 15,
      tags: ['personal'],
    ),

    // Upcoming
    Task(
      title: 'Prepare slides for the eHMI review',
      notes: 'Tomorrow, timed. Two tags: only the first shows on the row.',
      dueDateTime: day(1, 10),
      priority: Priority.high,
      reminderMinutes: 60,
      tags: ['college', 'robotics'],
    ),
    Task(
      title: 'OS assignment 4',
      notes: 'Weekday + date + time, flag and bell together.',
      dueDateTime: day(3, 23, 59),
      priority: Priority.high,
      reminderMinutes: 1440,
      tags: ['college'],
    ),
    Task(
      title: 'Renew library books',
      notes: 'All-day: date only.',
      dueDateTime: day(4, 0),
      allDay: true,
      tags: ['personal'],
    ),
    Task(
      title: 'Weekly review',
      notes: 'Repeats weekly.',
      dueDateTime: day(6, 18),
      recurrence: Recurrence.weekly,
      reminderMinutes: 30,
    ),

    // Whenever
    Task(
      title: 'Read two papers for the eHMI review',
      notes: 'Undated: "Anytime".',
      tags: ['college'],
    ),
    Task(
      title: 'Sort out the photo backup',
      notes: 'Undated with a high-priority flag and no bell.',
      priority: Priority.high,
    ),
    Task(
      title:
          'Finish the write-up for the departmental robotics showcase '
          'including the circuit diagrams and the bill of materials',
      notes:
          'Very long title and a long tag, to check the row ellipsises '
          'instead of overflowing at large text sizes.',
      tags: ['college-robotics-club-showcase'],
    ),
    Task(title: 'Buy a birthday gift'),

    // Completed, newest first on the Completed screen
    Task(
      title: 'Email the project abstract',
      dueDateTime: ago(hours: 5),
      isCompleted: true,
      completedAt: ago(hours: 1),
      tags: ['college'],
    ),
    Task(
      title: 'Renew the gym membership',
      dueDateTime: day(-2, 12),
      isCompleted: true,
      completedAt: ago(days: 2),
      tags: ['personal'],
    ),
  ];
}
