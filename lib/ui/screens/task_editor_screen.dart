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
    if (_allDay) {
      setState(() => _dueDateTime = DateTime(picked.year, picked.month, picked.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: _dueDateTime != null
          ? TimeOfDay.fromDateTime(_dueDateTime!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      _dueDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required')));
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
        const SnackBar(content: Text('Pick a due date to schedule reminders.')),
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
          const SnackBar(content: Text('All notifications are in the past. Please choose a future time.')),
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
            label: 'Open settings',
            onPressed: () async {
              await NotificationService.instance.requestExactAlarmPermission();
              await NotificationService.instance.openNotificationSettings();
            },
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dueDateTime == null
        ? 'No date'
        : formatDueDate(_dueDateTime, allDay: _allDay);
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
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Due: $dateText')),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Pick'),
                ),
              ],
            ),
            SwitchListTile(
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
              title: const Text('All day'),
            ),
            DropdownButtonFormField<Recurrence>(
              initialValue: _recurrence,
              items: Recurrence.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.name),
                      ))
                  .toList(),
              onChanged: (r) => setState(() => _recurrence = r ?? Recurrence.none),
              decoration: const InputDecoration(labelText: 'Repeat'),
            ),
            DropdownButtonFormField<Priority>(
              initialValue: _priority,
              items: Priority.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (p) => setState(() => _priority = p ?? Priority.medium),
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
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
                                  (i < _reminders.length && _reminders[i] == option))
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
                        decoration: InputDecoration(
                          labelText: i == 0 ? 'Reminder' : 'Reminder ${i + 1}',
                        ),
                      ),
                    ),
                    if (i > 0 && i < _reminders.length)
                      IconButton(
                        tooltip: 'Remove reminder',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _reminders.removeAt(i)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Align(
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
                            decoration: const InputDecoration(hintText: 'Tag'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                  context, controller.text.trim()),
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
