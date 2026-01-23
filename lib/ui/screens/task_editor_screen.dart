import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../models/recurrence.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/date_utils.dart';
import '../../services/notification_service.dart';

class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  DateTime? _dueDateTime;
  bool _allDay = false;
  Recurrence _recurrence = Recurrence.none;
  Priority _priority = Priority.medium;
  final List<Duration> _reminders = [];
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _dueDateTime = task?.dueDateTime;
    _allDay = task?.allDay ?? false;
    _recurrence = task?.recurrence ?? Recurrence.none;
    _priority = task?.priority ?? Priority.medium;
    _reminders.addAll(task?.remindersBefore ?? []);
    _tags.addAll(task?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  TimeOfDay _defaultTimeOfDay() {
    final settings = ref.read(settingsProvider);
    final now = DateTime.now()
        .add(Duration(minutes: settings.defaultTaskTimeOffsetMinutes));
    return TimeOfDay.fromDateTime(now);
  }

  DateTime _applyDefaultTime(DateTime date) {
    final time = _defaultTimeOfDay();
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      if (_allDay) {
        _dueDateTime = DateTime(picked.year, picked.month, picked.day);
        return;
      }
      final time = _dueDateTime != null
          ? TimeOfDay.fromDateTime(_dueDateTime!)
          : _defaultTimeOfDay();
      _dueDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final initial = _dueDateTime != null
        ? TimeOfDay.fromDateTime(_dueDateTime!)
        : _defaultTimeOfDay();
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      final baseDate = _dueDateTime ?? DateTime.now();
      _allDay = false;
      _dueDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required'), behavior: SnackBarBehavior.floating,));
      return;
    }
    final settings = ref.read(settingsProvider);
    final hasDueTime = _dueDateTime != null && !_allDay;
    final maxReminders = hasDueTime ? 2 : 3;
    final defaultReminder = settings.defaultReminderMinutes > 0
      ? Duration(minutes: settings.defaultReminderMinutes)
      : null;
    // Only use the default reminder when a due date is set. This allows
    // creating tasks with no due date even if the user has a default
    // reminder configured in settings.
    final selectedReminders = _reminders.isNotEmpty
      ? List<Duration>.from(_reminders)
      : ((_dueDateTime != null && defaultReminder != null)
        ? [defaultReminder]
        : <Duration>[]);
    final uniqueReminders = <int>{};
    final reminders = <Duration>[];
    for (final r in selectedReminders) {
      if (uniqueReminders.add(r.inMinutes)) {
        reminders.add(r);
      }
      if (reminders.length >= maxReminders) break;
    }

    if (_dueDateTime == null && reminders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a due date to schedule reminders.'), behavior: SnackBarBehavior.floating,),
      );
      return;
    }

    final task = (widget.task ?? Task(title: title)).copyWith(
      title: title,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dueDateTime: _dueDateTime,
      allDay: _allDay,
      recurrence: _recurrence,
      remindersBefore: reminders,
      priority: _priority,
      tags: List<String>.from(_tags),
      updatedAt: DateTime.now().toUtc(),
    );

    if (task.dueDateTime != null) {
      final now = DateTime.now();
      final scheduledTimes = <DateTime>[];
      if (hasDueTime) {
        scheduledTimes.add(task.dueDateTime!);
      }
      for (final reminder in reminders) {
        scheduledTimes.add(task.dueDateTime!.subtract(reminder));
      }
      final hasFutureTime = scheduledTimes.any((t) => t.isAfter(now));
      if (!hasFutureTime) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications are in the past. Please choose a future time.'), behavior: SnackBarBehavior.floating,),
        );
        return;
      }
    }

    final newIds = await ref.read(taskListProvider.notifier).addOrUpdate(task);
    if (!mounted) return;
    if (newIds == null && (hasDueTime || reminders.isNotEmpty)) {
      final snack = ScaffoldMessenger.of(context);
      snack.showSnackBar(
        SnackBar(
          content: const Text('Some required permissions are missing.'),
          action: SnackBarAction(
            label: 'gimme permissions',
            onPressed: () async {
              await NotificationService.instance.requestExactAlarmPermission();
              await NotificationService.instance.openNotificationSettings();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateText = _dueDateTime == null
      ? 'No date chosen'
        : formatDueDate(_dueDateTime, allDay: true);
    final timeText = _dueDateTime == null
      ? 'No time chosen'
        : (_allDay ? 'All day' : formatShortTime(_dueDateTime!));
    final reminderOptions = <Duration>[
      const Duration(minutes: 5),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(days: 1),
    ];
    final hasDueTime = _dueDateTime != null && !_allDay;
    final maxReminders = hasDueTime ? 2 : 3;
    final shownReminderCount = _reminders.isEmpty
        ? 1
        : (_reminders.length >= maxReminders
            ? maxReminders
            : _reminders.length + 1);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save Task'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: inputDecoration.copyWith(labelText: 'Title'),
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      decoration: inputDecoration.copyWith(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickDate,
                            child: Text(dateText),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickTime,
                            child: Text(timeText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: _allDay,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        setState(() {
                          _allDay = v;
                          if (_dueDateTime == null) return;
                          if (v) {
                            _dueDateTime = DateTime(
                              _dueDateTime!.year,
                              _dueDateTime!.month,
                              _dueDateTime!.day,
                            );
                          } else {
                            _dueDateTime = _applyDefaultTime(_dueDateTime!);
                          }
                        });
                      },
                      title: const Text('All day'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      
                      spacing: 8,
                      runSpacing: 8,
                      children: Priority.values.map((priority) {
                        final selected = _priority == priority;
                        return ChoiceChip(
                          label: Text(priority.name),
                          selected: selected,
                          onSelected: (_) => setState(() => _priority = priority),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 14),
                    DropdownButtonFormField<Recurrence>(
                      initialValue: _recurrence,
                      items: Recurrence.values
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.name),
                              ))
                          .toList(),
                      onChanged: (r) =>
                          setState(() => _recurrence = r ?? Recurrence.none),
                      decoration: inputDecoration.copyWith(labelText: 'Repeat'),
                      icon: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < shownReminderCount; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<Duration?>(
                                value: i < _reminders.length ? _reminders[i] : null,
                                items: [
                                  const DropdownMenuItem<Duration?>(
                                    value: null,
                                    child: Text('No reminder'),
                                  ),
                                  ...reminderOptions
                                      .where((option) =>
                                          !_reminders.contains(option) ||
                                          (i < _reminders.length &&
                                              _reminders[i] == option))
                                      .map((option) => DropdownMenuItem<Duration?>(
                                            value: option,
                                            child: Text(_formatReminder(option)),
                                          )),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    if (value == null) {
                                      if (i < _reminders.length) {
                                        _reminders.removeAt(i);
                                      }
                                      return;
                                    }
                                    if (i < _reminders.length) {
                                      _reminders[i] = value;
                                    } else if (_reminders.length < maxReminders) {
                                      _reminders.add(value);
                                    }
                                  });
                                },
                                decoration: inputDecoration.copyWith(
                                  labelText: i == 0 ? 'Reminder' : 'Reminder ${i + 1}',
                                ),
                                icon: const Icon(Icons.expand_more),
                              ),
                            ),
                            if (i > 0 && i < _reminders.length)
                              IconButton(
                                tooltip: 'Remove reminder',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _reminders.removeAt(i)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _tags)
                        Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                      ActionChip(
                        label: const Text('Add tag'),
                        onPressed: () async {
                          final controller = TextEditingController();
                          final result = await showDialog<String>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('New tag'),
                              content: TextField(
                                controller: controller,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Tag',
                                  fillColor: colorScheme.surface,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, controller.text.trim()),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            setState(() => _tags.add(result));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReminder(Duration duration) {
    if (duration.inDays >= 1) return '${duration.inDays} day before';
    if (duration.inHours >= 1) return '${duration.inHours} hour before';
    return '${duration.inMinutes} minutes before';
  }
}
