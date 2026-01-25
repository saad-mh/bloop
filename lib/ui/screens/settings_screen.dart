import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/permission_status_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/settings_screen_controller.dart';
import 'package:flutter/cupertino.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsScreenControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Appearance'),
                  ),
                ),
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(switch (settings.themeMode) {
                    ThemeMode.system => 'System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }),
                  onTap: () async {
                    final result = await showDialog<ThemeMode>(
                      context: context,
                      builder: (_) => SimpleDialog(
                        insetPadding: const EdgeInsets.all(24),
                        shape: dialogShape,
                        title: const Text('Theme'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, ThemeMode.system),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.settings),
                                      SizedBox(width: 12),
                                      Text('System'),
                                    ],
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, ThemeMode.light),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.wb_sunny),
                                      SizedBox(width: 12),
                                      Text('Light'),
                                    ],
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, ThemeMode.dark),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.nights_stay),
                                      SizedBox(width: 12),
                                      Text('Dark'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      controller.setThemeMode(result);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme updated'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15,),
                ListTile(
                  title: const Text('Accent color'),
                  // subtitle: Text('#${settings.seedColor.toRadixString(16).padLeft(8, '0').toUpperCase()}'),
                  onTap: () async {
                    final colors = controller.accentColors;
                    final result = await showDialog<int>(
                      context: context,
                      builder: (_) => SimpleDialog(
                        insetPadding: const EdgeInsets.all(24),
                        shape: dialogShape,
                        title: const Text('Accent color'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final c in colors)
                                  InkWell(
                                    onTap: () => Navigator.pop(context, c),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Color(c),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: settings.seedColor == c
                                              ? (settings.themeMode ==
                                                      ThemeMode.dark
                                                  ? Colors.white
                                                  : Colors.black)
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      controller.setSeedColor(result);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Accent color updated'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Focus session'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Full-screen focus mode'),
                  subtitle: const Text('Hide system UI during focus sessions'),
                  value: settings.focusFullScreenEnabled,
                  onChanged: controller.setFocusFullScreenEnabled,
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('App pinning'),
                  subtitle: const Text('Keep Bloop pinned while focusing'),
                  value: settings.focusAppPinningEnabled,
                  onChanged: controller.setFocusAppPinningEnabled,
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Allow overrides during focus'),
                  subtitle: const Text('Let the focus session sheet adjust these settings'),
                  value: settings.focusAllowOverrides,
                  onChanged: controller.setFocusAllowOverrides,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('General'),
                  ),
                ),
                ListTile(
                  title: const Text('Reset to defaults'),
                  subtitle: const Text('Restore all settings to defaults'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: dialogShape,
                        title: const Text('Reset settings'),
                        content: const Text(
                          'Are you sure you want to reset all settings to defaults?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ButtonStyle(
                              elevation: MaterialStateProperty.all(5),
                              foregroundColor:
                                  MaterialStateProperty.all(Colors.red),
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      controller.resetDefaults();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings reset to defaults'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Required permissions'),
                  subtitle: const Text('Review and grant app permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionSettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                SwitchListTile(
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotificationsEnabled,
                  title: const Text('Notifications'),
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                SwitchListTile(
                  value: settings.focusSessionNotificationsEnabled,
                  onChanged: controller.setFocusSessionNotificationsEnabled,
                  title: const Text('Focus session notification'),
                  subtitle:
                      const Text('Show a persistent timer while focusing'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Defaults'),
                  ),
                ),
                ListTile(
                  title: const Text('Default reminder'),
                  subtitle:
                      Text('${settings.defaultReminderMinutes} minutes before'),
                  onTap: () async {
                    final textController = TextEditingController(
                      text: settings.defaultReminderMinutes.toString(),
                    );
                    final result = await showDialog<int>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: dialogShape,
                        title: const Text('Default reminder (minutes)'),
                        content: TextField(
                          controller: textController,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              int.tryParse(textController.text.trim()),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      controller.setReminderMinutes(result.clamp(0, 1440));
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Default task time'),
                  subtitle: Text(
                    '${settings.defaultTaskTimeOffsetMinutes} minutes from now',
                  ),
                  onTap: () async {
                    final textController = TextEditingController(
                      text: settings.defaultTaskTimeOffsetMinutes.toString(),
                    );
                    final result = await showDialog<int>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: dialogShape,
                        title:
                            const Text('Default task time (minutes from now)'),
                        content: TextField(
                          controller: textController,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              int.tryParse(textController.text.trim()),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      controller.setDefaultTaskTimeOffsetMinutes(
                        result.clamp(0, 1440),
                      );
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Default priority'),
                  subtitle: Text(settings.defaultPriority.name),
                  onTap: () async {
                    final result = await showDialog<Priority>(
                      context: context,
                      builder: (_) => SimpleDialog(
                        shape: dialogShape,
                        insetPadding: const EdgeInsets.symmetric(horizontal: 15),
                        title: const Text('Default priority'),
                        children: [
                          for (final p in Priority.values)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, p),
                              child: Text(p.name),
                            ),
                        ],
                      ),
                    );
                    if (result != null) {
                      controller.setPriority(result);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Debug - THESE ARE NOT FOR YOU'),
                  ),
                ),
                ListTile(
                  title: const Text('Add demo tasks'),
                  subtitle: const Text(
                    'Overdue, today, and future tasks with mixed priorities',
                  ),
                  onTap: () async {
                    await controller.addDemoTasks();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Demo tasks added'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Clear all tasks'),
                  subtitle: const Text('Delete every task in the list'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: dialogShape,
                        title: const Text('Clear all tasks'),
                        content:
                            const Text('This will delete all tasks. Continue?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await controller.clearAllTasks();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All tasks cleared'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Data'),
                  ),
                ),
                ListTile(
                  title: const Text('Export data'),
                  subtitle: const Text('Copy JSON to clipboard'),
                  onTap: () async {
                    final data = controller.exportJson();
                    await Clipboard.setData(ClipboardData(text: data));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exported to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Import data'),
                  subtitle: const Text('Paste JSON to restore'),
                  onTap: () async {
                    final textController = TextEditingController();
                    final json = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: dialogShape,
                        title: const Text('Import JSON'),
                        content: TextField(
                          controller: textController,
                          decoration: inputDecoration.copyWith(
                            hintText: 'Paste JSON here',
                          ),
                          maxLines: 6,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, textController.text.trim()),
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                    );
                    if (json != null && json.isNotEmpty) {
                      await controller.importJson(json);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Import completed'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionSettingsScreen extends ConsumerStatefulWidget {
  const PermissionSettingsScreen({super.key});

  @override
  ConsumerState<PermissionSettingsScreen> createState() =>
      _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState
    extends ConsumerState<PermissionSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(permissionStatusProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionStatusProvider.notifier).refresh();
    }
    super.didChangeAppLifecycleState(state);
  }

  Widget _statusIcon(PermissionStatusState status, bool? granted) {
    if (status.isLoading || granted == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Loading', year2023: false,),
      );
    }
    return Icon(
      granted ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_triangle,
      color: granted ? Colors.green : Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ref.watch(permissionStatusProvider);
    final controller = ref.read(permissionStatusProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Required permissions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Notifications'),
                  subtitle: const Text('Allow reminders to alert you'),
                  trailing: _statusIcon(status, status.notificationsGranted),
                ),
                if (status.isAndroid && status.notificationsGranted == false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await controller.openNotificationSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Open settings'),
                      ),
                    ),
                  ),
                Divider(height: 1, indent: 15, endIndent: 15),
                ListTile(
                  title: const Text('Exact alarms'),
                  subtitle: const Text('Deliver reminders at the exact time'),
                  trailing: _statusIcon(status, status.exactAlarmGranted),
                ),
                if (status.isAndroid && status.exactAlarmGranted == false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await controller.requestExactAlarmPermission();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Open settings'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!status.isAndroid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Permissions are managed by the system on this platform.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
