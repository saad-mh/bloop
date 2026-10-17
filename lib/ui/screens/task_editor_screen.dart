import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/recurrence.dart';
import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tags_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/date_utils.dart';
import '../theme/tokens.dart';
import '../widgets/action_buttons.dart';
import '../widgets/choice_chip.dart';
import '../widgets/segmented_control.dart';

/// Full-screen page for adding a task, or editing [task].
///
/// Only the title is required. Notes, repeat, several reminders and delete
/// live behind "More options" so the basic flow stays short.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  static const _reminderOptions = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(days: 1),
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  DateTime? _dueDateTime;
  bool _allDay = false;
  Recurrence _recurrence = Recurrence.none;
  Priority _priority = Priority.medium;
  final List<Duration> _reminders = [];
  final List<String> _tags = [];

  bool _titleMissing = false;
  bool _moreOpen = false;
  bool _saving = false;

  /// Set once the user turns Remind me on or off, so picking a time no longer
  /// switches the default reminder on for them.
  bool _reminderTouched = false;

  // What the page opened with, to tell whether closing would lose anything.
  late final String _initialTitle;
  late final String _initialNotes;
  late final DateTime? _initialDue;
  late final bool _initialAllDay;
  late final Recurrence _initialRecurrence;
  late final Priority _initialPriority;
  late final List<int> _initialReminders;
  late final List<String> _initialTags;

  bool get _hasDate => _dueDateTime != null;
  bool get _hasTime => _dueDateTime != null && !_allDay;
  int get _maxReminders => _hasTime ? 2 : 3;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '')
      ..addListener(_onTextChanged);
    _notesController = TextEditingController(text: task?.notes ?? '')
      ..addListener(_onTextChanged);
    _dueDateTime = task?.dueDateTime;
    _allDay = task?.allDay ?? false;
    _recurrence = task?.recurrence ?? Recurrence.none;
    _priority = task?.priority ?? ref.read(settingsProvider).defaultPriority;
    _reminders.addAll(task?.remindersBefore ?? []);
    _tags.addAll(task?.tags ?? []);

    _initialTitle = _titleController.text;
    _initialNotes = _notesController.text;
    _initialDue = _dueDateTime;
    _initialAllDay = _allDay;
    _initialRecurrence = _recurrence;
    _initialPriority = _priority;
    _initialReminders = [for (final r in _reminders) r.inMinutes];
    _initialTags = List<String>.from(_tags);

    // Open the extras when the task already uses them.
    _moreOpen =
        _initialNotes.trim().isNotEmpty ||
        _recurrence != Recurrence.none ||
        _reminders.length > 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Rebuild so the discard guard follows the text, and drop the title error
    // once there is something to save.
    setState(() {
      if (_titleController.text.trim().isNotEmpty) _titleMissing = false;
    });
  }

  bool get _isDirty =>
      _titleController.text != _initialTitle ||
      _notesController.text != _initialNotes ||
      _dueDateTime != _initialDue ||
      _allDay != _initialAllDay ||
      _recurrence != _initialRecurrence ||
      _priority != _initialPriority ||
      !_sameList(
        _reminders.map((r) => r.inMinutes).toList(),
        _initialReminders,
      ) ||
      !_sameList(_tags, _initialTags);

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---- When ---------------------------------------------------------------

  TimeOfDay _defaultTimeOfDay() {
    final settings = ref.read(settingsProvider);
    final now = DateTime.now().add(
      Duration(minutes: settings.defaultTaskTimeOffsetMinutes),
    );
    return TimeOfDay.fromDateTime(now);
  }

  Duration _defaultReminder() {
    final minutes = ref.read(settingsProvider).defaultReminderMinutes;
    return Duration(minutes: minutes > 0 ? minutes : 15);
  }

  /// Keeps the time of day when there is one; otherwise the task is all-day.
  void _setDate(DateTime date) {
    setState(() {
      final due = _dueDateTime;
      if (due != null && !_allDay) {
        _dueDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          due.hour,
          due.minute,
        );
      } else {
        _dueDateTime = DateTime(date.year, date.month, date.day);
        _allDay = true;
      }
    });
  }

  void _clearDate() {
    setState(() {
      _dueDateTime = null;
      _allDay = false;
      // Reminders count back from the due date, so they go with it.
      _reminders.clear();
    });
  }

  void _setTime(TimeOfDay time) {
    setState(() {
      final hadTime = _hasTime;
      final base = _dueDateTime ?? DateTime.now();
      _allDay = false;
      _dueDateTime = DateTime(
        base.year,
        base.month,
        base.day,
        time.hour,
        time.minute,
      );
      // Honour the default-reminder setting the first time a time is chosen.
      if (!hadTime &&
          !_reminderTouched &&
          _reminders.isEmpty &&
          ref.read(settingsProvider).defaultReminderMinutes > 0) {
        _reminders.add(_defaultReminder());
      }
    });
  }

  void _setAllDay(bool allDay) {
    final due = _dueDateTime;
    if (due == null) return;
    if (allDay) {
      setState(() {
        _allDay = true;
        _dueDateTime = DateTime(due.year, due.month, due.day);
      });
    } else {
      _setTime(_defaultTimeOfDay());
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    _setDate(picked);
  }

  Future<void> _pickTime() async {
    final due = _dueDateTime;
    final initial = due != null && !_allDay
        ? TimeOfDay.fromDateTime(due)
        : _defaultTimeOfDay();
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null || !mounted) return;
    _setTime(time);
  }

  void _toggleRemindMe(bool on) {
    setState(() {
      _reminderTouched = true;
      if (on) {
        if (_reminders.isEmpty) _reminders.add(_defaultReminder());
      } else {
        _reminders.clear();
      }
    });
  }

  // ---- Tags ---------------------------------------------------------------

  void _toggleTag(String tag, bool on) {
    setState(() {
      if (on) {
        if (!_tags.contains(tag)) _tags.add(tag);
      } else {
        _tags.remove(tag);
      }
    });
  }

  Future<void> _newTag() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _NewTagDialog(),
    );
    if (result == null || result.isEmpty || !mounted) return;
    // Store it so it shows up in the picker (and the home filter) next time.
    await ref.read(tagsProvider.notifier).addTag(result);
    if (!mounted) return;
    _toggleTag(result, true);
  }

  // ---- Closing, saving, deleting ------------------------------------------

  Future<bool> _confirmDiscard() async {
    final editing = widget.task != null;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing ? 'Discard changes?' : 'Discard this task?'),
        content: Text(
          editing
              ? 'Your changes to this task will be lost.'
              : 'What you entered will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('"${task.title}" will be removed for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(taskListProvider.notifier).delete(task);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleMissing = true);
      return;
    }

    final hasTime = _hasTime;
    final reminders = <Duration>[];
    final seen = <int>{};
    for (final r in _reminders) {
      if (!_hasDate) break;
      if (seen.add(r.inMinutes)) reminders.add(r);
      if (reminders.length >= _maxReminders) break;
    }

    // Only check the schedule when there is something to notify about, and
    // when it changed: otherwise an overdue task couldn't even be renamed.
    final scheduleChanged =
        widget.task == null ||
        _dueDateTime != _initialDue ||
        _allDay != _initialAllDay ||
        !_sameList(
          reminders.map((r) => r.inMinutes).toList(),
          _initialReminders,
        );
    if (scheduleChanged && (hasTime || reminders.isNotEmpty)) {
      final due = _dueDateTime!;
      final now = DateTime.now();
      final times = [
        if (hasTime) due,
        for (final r in reminders) due.subtract(r),
      ];
      if (!times.any((t) => t.isAfter(now))) {
        _snack('That time has already passed. Choose a later one.');
        return;
      }
    }

    final notes = _notesController.text.trim();
    final task = (widget.task ?? Task(title: title)).copyWith(
      title: title,
      notes: notes,
      clearNotes: notes.isEmpty,
      dueDateTime: _dueDateTime,
      clearDueDateTime: _dueDateTime == null,
      allDay: _allDay,
      recurrence: _recurrence,
      remindersBefore: reminders,
      priority: _priority,
      tags: List<String>.from(_tags),
      updatedAt: DateTime.now().toUtc(),
    );

    setState(() => _saving = true);
    final newIds = await ref.read(taskListProvider.notifier).addOrUpdate(task);
    if (!mounted) return;
    if (newIds == null && (hasTime || reminders.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
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

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final theme = Theme.of(context);
    final editing = widget.task != null;

    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: BloopSpace.x1),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: BloopSpace.x1),
                    Expanded(
                      child: Text(
                        editing ? 'Edit task' : 'New task',
                        style: theme.textTheme.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    BloopSpace.x5,
                    BloopSpace.x2,
                    BloopSpace.x5,
                    BloopSpace.x6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleField(theme),
                      const SizedBox(height: BloopSpace.x5),
                      _buildWhen(tokens),
                      const SizedBox(height: BloopSpace.x6),
                      _buildPriority(),
                      const SizedBox(height: BloopSpace.x6),
                      _buildTags(tokens),
                      const SizedBox(height: BloopSpace.x4),
                      _buildMoreOptions(tokens, theme),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(tokens, editing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return TextField(
      controller: _titleController,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Title',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        errorText: _titleMissing ? 'Add a title to save this task' : null,
      ),
    );
  }

  Widget _buildWhen(BloopTokens tokens) {
    final due = _dueDateTime;
    final isToday = due != null && isSameDay(due, DateTime.now());
    final isTomorrow =
        due != null &&
        isSameDay(due, DateTime.now().add(const Duration(days: 1)));
    final isCustom = due != null && !isToday && !isTomorrow;
    final canRemind = _hasTime || _reminders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'When',
          optional: true,
          trailing: _hasDate
              ? TextButton(onPressed: _clearDate, child: const Text('Clear'))
              : null,
        ),
        Wrap(
          spacing: BloopSpace.x2,
          children: [
            BloopChoiceChip(
              label: 'Today',
              selected: isToday,
              onSelected: (on) => on ? _setDate(DateTime.now()) : _clearDate(),
            ),
            BloopChoiceChip(
              label: 'Tomorrow',
              selected: isTomorrow,
              onSelected: (on) => on
                  ? _setDate(DateTime.now().add(const Duration(days: 1)))
                  : _clearDate(),
            ),
            BloopChoiceChip(
              label: isCustom
                  ? DateFormat('EEE d MMM').format(due)
                  : 'Pick date',
              icon: Icons.calendar_today_outlined,
              selected: isCustom,
              // Always opens the picker; Clear removes the date.
              onSelected: (_) => _pickDate(),
            ),
          ],
        ),
        Wrap(
          spacing: BloopSpace.x2,
          children: [
            BloopChoiceChip(
              label: _hasTime ? formatShortTime(due!) : 'Add time',
              icon: Icons.schedule,
              selected: _hasTime,
              onSelected: (_) => _pickTime(),
            ),
            BloopChoiceChip(
              label: 'Remind me',
              icon: Icons.notifications_none,
              selected: _reminders.isNotEmpty,
              // Needs a time to count back from.
              onSelected: canRemind ? _toggleRemindMe : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriority() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Priority'),
        SegmentedControl<Priority>(
          segments: const [
            Segment(value: Priority.low, label: 'Low'),
            Segment(value: Priority.medium, label: 'Normal'),
            Segment(value: Priority.high, label: 'High'),
          ],
          selected: _priority,
          onChanged: (p) => setState(() => _priority = p),
        ),
      ],
    );
  }

  Widget _buildTags(BloopTokens tokens) {
    final stored = ref.watch(tagsProvider).valueOrNull ?? const <String>[];
    // A tag already on the task stays pickable even if it left the list.
    final all = [
      ...stored,
      for (final tag in _tags)
        if (!stored.contains(tag)) tag,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Tags', optional: true),
        Wrap(
          spacing: BloopSpace.x2,
          children: [
            for (final tag in all)
              BloopChoiceChip(
                label: tag,
                selected: _tags.contains(tag),
                onSelected: (on) => _toggleTag(tag, on),
              ),
            BloopChoiceChip(
              label: 'New tag',
              icon: Icons.add,
              selected: false,
              onSelected: (_) => _newTag(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoreOptions(BloopTokens tokens, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: tokens.border),
        Semantics(
          button: true,
          expanded: _moreOpen,
          excludeSemantics: true,
          label: 'More options',
          onTap: () => setState(() => _moreOpen = !_moreOpen),
          child: InkWell(
            onTap: () => setState(() => _moreOpen = !_moreOpen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kBloopMinTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'More options',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(_moreOpen ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        if (_moreOpen) ...[
          const SizedBox(height: BloopSpace.x2),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: BloopSpace.x4),
          SwitchListTile(
            value: _allDay,
            contentPadding: EdgeInsets.zero,
            title: const Text('All day'),
            subtitle: _hasDate ? null : const Text('Pick a date first'),
            onChanged: _hasDate ? _setAllDay : null,
          ),
          const SizedBox(height: BloopSpace.x2),
          DropdownButtonFormField<Recurrence>(
            initialValue: _recurrence,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: [
              for (final r in Recurrence.values)
                DropdownMenuItem(value: r, child: Text(_recurrenceLabel(r))),
            ],
            onChanged: (r) =>
                setState(() => _recurrence = r ?? Recurrence.none),
          ),
          const SizedBox(height: BloopSpace.x4),
          ..._buildReminders(),
          if (widget.task != null) ...[
            const SizedBox(height: BloopSpace.x4),
            OutlineActionButton(
              label: 'Delete task',
              icon: Icons.delete_outline,
              onPressed: _delete,
              expand: true,
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _buildReminders() {
    if (!_hasDate) {
      return [
        Text(
          'Pick a date to add reminders.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BloopTokens.of(context).muted),
        ),
      ];
    }
    final shown = _reminders.isEmpty
        ? 1
        : (_reminders.length >= _maxReminders
              ? _maxReminders
              : _reminders.length + 1);
    return [
      for (var i = 0; i < shown; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: BloopSpace.x3),
          child: Row(
            children: [
              Expanded(child: _buildReminderField(i)),
              if (i > 0 && i < _reminders.length)
                IconButton(
                  tooltip: 'Remove reminder',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _reminderTouched = true;
                      _reminders.removeAt(i);
                    });
                  },
                ),
            ],
          ),
        ),
    ];
  }

  Widget _buildReminderField(int i) {
    final current = i < _reminders.length ? _reminders[i] : null;
    final options = <Duration>{
      // Keep a value from an older task or the settings pickable.
      if (current != null) current,
      ..._reminderOptions.where((o) => !_reminders.contains(o)),
    }.toList()..sort();

    return DropdownButtonFormField<Duration?>(
      // Rebuild with the new value; initialValue is read only once.
      key: ValueKey('reminder-$i-${current?.inMinutes}'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: i == 0 ? 'Reminder' : 'Reminder ${i + 1}',
      ),
      items: [
        const DropdownMenuItem<Duration?>(
          value: null,
          child: Text('No reminder'),
        ),
        for (final option in options)
          DropdownMenuItem<Duration?>(
            value: option,
            child: Text(_formatReminder(option)),
          ),
      ],
      onChanged: (value) {
        setState(() {
          _reminderTouched = true;
          if (value == null) {
            if (i < _reminders.length) _reminders.removeAt(i);
          } else if (i < _reminders.length) {
            _reminders[i] = value;
          } else if (_reminders.length < _maxReminders) {
            _reminders.add(value);
          }
        });
      },
    );
  }

  Widget _buildBottomBar(BloopTokens tokens, bool editing) {
    return Container(
      padding: const EdgeInsets.all(BloopSpace.x4),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: PrimaryButton(
        label: editing ? 'Save' : 'Add task',
        onPressed: _saving ? null : _save,
        expand: true,
      ),
    );
  }

  static String _recurrenceLabel(Recurrence r) => switch (r) {
    Recurrence.none => 'Never',
    Recurrence.daily => 'Daily',
    Recurrence.weekly => 'Weekly',
    Recurrence.monthly => 'Monthly',
    Recurrence.yearly => 'Yearly',
  };

  static String _formatReminder(Duration d) {
    String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'} before';
    if (d.inMinutes % Duration.minutesPerDay == 0) {
      return unit(d.inDays, 'day');
    }
    if (d.inMinutes % Duration.minutesPerHour == 0) {
      return unit(d.inHours, 'hour');
    }
    return unit(d.inMinutes, 'minute');
  }
}

/// Small caps heading for a group of controls.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.optional = false, this.trailing});

  final String text;
  final bool optional;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: tokens.ink, letterSpacing: 0.7);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BloopSpace.x8),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text.toUpperCase(),
                children: [
                  if (optional)
                    TextSpan(
                      text: '  · optional',
                      style: style?.copyWith(
                        color: tokens.muted,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
              style: style,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Asks for a tag name. Owns its controller so it outlives the dialog's exit
/// animation.
class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog();

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New tag'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Tag'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
