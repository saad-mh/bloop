import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/settings_screen_controller.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/tag_manager.dart';
import 'permission_settings_screen.dart';

/// Focus lengths offered as one tap; anything else is "Custom".
const _focusPresets = [15, 25, 45];

/// Stands for the Custom segment, which has no length of its own.
const _customFocus = -1;

/// Profile, focus length, tags and notifications up front; every other
/// setting lives under a collapsed Advanced section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _advancedOpen = false;

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editName(String current) async {
    final controller = ref.read(settingsScreenControllerProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'What would you like to be called?',
        label: 'Name',
        helper: 'Leave empty to be greeted as "User".',
        initial: current,
        maxLength: 30,
        capitalization: TextCapitalization.words,
      ),
    );
    if (name == null) return;
    controller.setUserName(name);
  }

  Future<void> _pickFocusLength(int choice, int current) async {
    final controller = ref.read(settingsScreenControllerProvider);
    if (choice != _customFocus) {
      controller.setDefaultFocusMinutes(choice);
      return;
    }
    final minutes = await _askMinutes(
      title: 'Custom focus length',
      label: 'Minutes',
      initial: current,
      min: 1,
      max: SettingsState.maxFocusMinutes,
    );
    if (minutes != null) controller.setDefaultFocusMinutes(minutes);
  }

  /// Asks for a whole number of minutes in [min]..[max]; null if cancelled.
  Future<int?> _askMinutes({
    required String title,
    required String label,
    required int initial,
    required int min,
    required int max,
  }) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: title,
        label: label,
        initial: '$initial',
        numeric: true,
        validate: (value) {
          final n = int.tryParse(value);
          if (n == null || n < min || n > max) {
            return 'Enter a number from $min to $max';
          }
          return null;
        },
      ),
    );
    return text == null ? null : int.tryParse(text);
  }

  Future<void> _confirm({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() onConfirmed,
    required String done,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = BloopTokens.of(context);
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: tokens.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await onConfirmed();
    if (mounted) _snack(done);
  }

  Future<void> _importData() async {
    final controller = ref.read(settingsScreenControllerProvider);
    final json = await showDialog<String>(
      context: context,
      builder: (_) => const _PromptDialog(
        title: 'Import JSON',
        label: 'Paste JSON here',
        initial: '',
        maxLines: 6,
        submitLabel: 'Import',
      ),
    );
    if (json == null || json.isEmpty) return;
    final imported = await controller.importJson(json);
    if (!mounted) return;
    _snack(imported ? 'Import completed' : 'Could not import that JSON');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsScreenControllerProvider);
    final tokens = BloopTokens.of(context);
    final theme = Theme.of(context);

    final focusMinutes = settings.defaultFocusMinutes;
    final focusChoice = _focusPresets.contains(focusMinutes)
        ? focusMinutes
        : _customFocus;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Settings',
              leading: BloopIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: BloopSpace.x8),
                children: [
                  const _GroupLabel('Profile'),
                  _Group(
                    children: [
                      ListTile(
                        title: const Text('Your name'),
                        subtitle: const Text('Shown in the greeting'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                settings.userName.isEmpty
                                    ? 'Not set'
                                    : settings.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: tokens.muted,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: tokens.muted),
                          ],
                        ),
                        onTap: () => _editName(settings.userName),
                      ),
                    ],
                  ),
                  const _GroupLabel('Focus'),
                  _Group(
                    children: [
                      _ChoiceRow(
                        title: 'Default focus length',
                        caption: focusChoice == _customFocus
                            ? 'Custom: $focusMinutes min. Used by the Focus '
                                  'button on every task'
                            : 'Used by the Focus button on every task',
                        child: SegmentedControl<int>(
                          segments: [
                            for (final m in _focusPresets)
                              Segment(value: m, label: '$m min'),
                            const Segment(value: _customFocus, label: 'Custom'),
                          ],
                          selected: focusChoice,
                          onChanged: (v) => _pickFocusLength(v, focusMinutes),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('New Focus screen'),
                        subtitle: const Text(
                          'Pick a task, one timer and three controls. No '
                          'breaks or session counts',
                        ),
                        value: settings.focusV2Enabled,
                        onChanged: controller.setFocusV2Enabled,
                      ),
                    ],
                  ),
                  const _GroupLabel('Tags'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: BloopSpace.x4),
                    child: TagManager(),
                  ),
                  const _GroupLabel('Notifications'),
                  _Group(
                    children: [
                      ListTile(
                        title: const Text('Reminder permissions'),
                        subtitle: const Text(
                          'Check and grant system permissions',
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: tokens.muted,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PermissionSettingsScreen(),
                          ),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Task reminders'),
                        subtitle: const Text('Notify me when a task is due'),
                        value: settings.notificationsEnabled,
                        onChanged: controller.setNotificationsEnabled,
                      ),
                      SwitchListTile(
                        title: const Text('Focus session notification'),
                        subtitle: const Text(
                          'Show a persistent timer while focusing',
                        ),
                        value: settings.focusSessionNotificationsEnabled,
                        onChanged:
                            controller.setFocusSessionNotificationsEnabled,
                      ),
                    ],
                  ),
                  const SizedBox(height: BloopSpace.x4),
                  SectionHeader(
                    label: 'Advanced',
                    expanded: _advancedOpen,
                    onToggle: () =>
                        setState(() => _advancedOpen = !_advancedOpen),
                  ),
                  if (_advancedOpen) ..._advanced(settings, controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _advanced(
    SettingsState settings,
    SettingsScreenController controller,
  ) {
    final tokens = BloopTokens.of(context);
    return [
      const _GroupLabel('Appearance'),
      _Group(
        children: [
          _ChoiceRow(
            title: 'Theme',
            child: SegmentedControl<ThemeMode>(
              segments: const [
                Segment(value: ThemeMode.system, label: 'System'),
                Segment(value: ThemeMode.light, label: 'Light'),
                Segment(value: ThemeMode.dark, label: 'Dark'),
              ],
              selected: settings.themeMode,
              onChanged: controller.setThemeMode,
            ),
          ),
        ],
      ),
      // Accent colour picker is hidden for 2.0 (monochrome build). The
      // seedColor setting and controller.accentColors stay for the colourful
      // build (#16).
      const _GroupLabel('Focus behaviour'),
      _Group(
        children: [
          SwitchListTile(
            title: const Text('Full-screen focus mode'),
            subtitle: const Text('Hide system UI during focus sessions'),
            value: settings.focusFullScreenEnabled,
            onChanged: controller.setFocusFullScreenEnabled,
          ),
          SwitchListTile(
            title: const Text('App pinning'),
            subtitle: const Text('Keep Bloop pinned while focusing'),
            value: settings.focusAppPinningEnabled,
            onChanged: controller.setFocusAppPinningEnabled,
          ),
          SwitchListTile(
            title: const Text('Allow overrides during focus'),
            subtitle: const Text(
              'Let the focus session sheet adjust these settings',
            ),
            value: settings.focusAllowOverrides,
            onChanged: controller.setFocusAllowOverrides,
          ),
        ],
      ),
      const _GroupLabel('Defaults for new tasks'),
      _Group(
        children: [
          ListTile(
            title: const Text('Default reminder'),
            subtitle: Text('${settings.defaultReminderMinutes} minutes before'),
            onTap: () async {
              final minutes = await _askMinutes(
                title: 'Default reminder (minutes)',
                label: 'Minutes before',
                initial: settings.defaultReminderMinutes,
                min: 0,
                max: 1440,
              );
              if (minutes != null) controller.setReminderMinutes(minutes);
            },
          ),
          ListTile(
            title: const Text('Default task time'),
            subtitle: Text(
              '${settings.defaultTaskTimeOffsetMinutes} minutes from now',
            ),
            onTap: () async {
              final minutes = await _askMinutes(
                title: 'Default task time (minutes from now)',
                label: 'Minutes from now',
                initial: settings.defaultTaskTimeOffsetMinutes,
                min: 0,
                max: 1440,
              );
              if (minutes != null) {
                controller.setDefaultTaskTimeOffsetMinutes(minutes);
              }
            },
          ),
          _ChoiceRow(
            title: 'Default priority',
            child: SegmentedControl<Priority>(
              segments: [
                for (final p in Priority.values)
                  Segment(
                    value: p,
                    label: p.name[0].toUpperCase() + p.name.substring(1),
                  ),
              ],
              selected: settings.defaultPriority,
              onChanged: controller.setPriority,
            ),
          ),
        ],
      ),
      const _GroupLabel('Data'),
      _Group(
        children: [
          ListTile(
            title: const Text('Export data'),
            subtitle: const Text('Copy JSON to clipboard'),
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: controller.exportJson()),
              );
              if (mounted) _snack('Exported to clipboard');
            },
          ),
          ListTile(
            title: const Text('Import data'),
            subtitle: const Text('Paste JSON to restore'),
            onTap: _importData,
          ),
        ],
      ),
      const _GroupLabel('Demo data and reset'),
      _Group(
        children: [
          ListTile(
            title: const Text('Add demo tasks'),
            subtitle: const Text('One of every row state, for testing'),
            onTap: () async {
              await controller.addDemoTasks();
              if (mounted) _snack('Demo tasks added');
            },
          ),
          ListTile(
            title: Text(
              'Clear all tasks',
              style: TextStyle(color: tokens.error),
            ),
            subtitle: const Text('Delete every task in the list'),
            onTap: () => _confirm(
              title: 'Clear all tasks',
              message: 'This will delete all tasks. Continue?',
              action: 'Clear',
              onConfirmed: controller.clearAllTasks,
              done: 'All tasks cleared',
            ),
          ),
          ListTile(
            title: Text(
              'Reset to defaults',
              style: TextStyle(color: tokens.error),
            ),
            subtitle: const Text('Restore all settings to defaults'),
            onTap: () => _confirm(
              title: 'Reset settings',
              message:
                  'Reset every setting to its default, including your name '
                  'and default focus length? Tasks and tags are kept.',
              action: 'Reset',
              onConfirmed: () async => controller.resetDefaults(),
              done: 'Settings reset to defaults',
            ),
          ),
        ],
      ),
    ];
  }
}

/// Small uppercase heading above a group of rows.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BloopSpace.x5,
          BloopSpace.x5,
          BloopSpace.x5,
          BloopSpace.x1,
        ),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tokens.muted,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Rows separated by hairlines, with one above and below the group.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
        const Divider(),
      ],
    );
  }
}

/// A setting chosen from a segmented control, with its title above.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BloopSpace.x4,
        BloopSpace.x3,
        BloopSpace.x4,
        BloopSpace.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.bodyLarge),
          if (caption != null)
            Text(
              caption!,
              style: textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          const SizedBox(height: BloopSpace.x2),
          child,
        ],
      ),
    );
  }
}

/// One text field in a dialog. Owns its controller so it outlives the
/// dialog's exit animation. Pops the entered text, or null if cancelled.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    this.helper,
    this.numeric = false,
    this.maxLength,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.submitLabel = 'Save',
    this.validate,
  });

  final String title;
  final String label;
  final String initial;
  final String? helper;
  final bool numeric;
  final int? maxLength;
  final int maxLines;
  final TextCapitalization capitalization;
  final String submitLabel;

  /// Returns an error to show instead of closing, or null when [value] is ok.
  final String? Function(String value)? validate;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validate?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: widget.capitalization,
        keyboardType: widget.numeric ? TextInputType.number : null,
        inputFormatters: widget.numeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        textInputAction: widget.maxLines == 1 ? TextInputAction.done : null,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
