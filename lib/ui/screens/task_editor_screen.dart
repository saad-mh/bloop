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
  Duration? _reminder;
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
    _reminder = task?.reminderBefore;
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
    final reminder = _reminder ??
        (settings.defaultReminderMinutes > 0
            ? Duration(minutes: settings.defaultReminderMinutes)
            : null);

    final task = (widget.task ?? Task(title: title)).copyWith(
      title: title,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dueDateTime: _dueDateTime,
      allDay: _allDay,
      recurrence: _recurrence,
      reminderBefore: reminder,
      priority: _priority,
      tags: List<String>.from(_tags),
      updatedAt: DateTime.now().toUtc(),
    );

    final newId = await ref.read(taskListProvider.notifier).addOrUpdate(task);
    if (!mounted) return;
    if (newId == null) {
      final snack = ScaffoldMessenger.of(context);
      snack.showSnackBar(
        SnackBar(
          content: const Text('Reminder not scheduled — check permissions'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
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
            DropdownButtonFormField<Duration?>(
              initialValue: _reminder,
              items: const [
                DropdownMenuItem(value: null, child: Text('No reminder')),
                DropdownMenuItem(
                    value: Duration(minutes: 5), child: Text('5 minutes before')),
                DropdownMenuItem(
                    value: Duration(minutes: 15), child: Text('15 minutes before')),
                DropdownMenuItem(
                    value: Duration(minutes: 30), child: Text('30 minutes before')),
                DropdownMenuItem(
                    value: Duration(hours: 1), child: Text('1 hour before')),
              ],
              onChanged: (d) => setState(() => _reminder = d),
              decoration: const InputDecoration(labelText: 'Reminder'),
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
}
