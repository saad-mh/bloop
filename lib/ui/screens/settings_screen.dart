import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
      ),
      body: ListView(
        children: [
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
                  title: const Text('Theme'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, ThemeMode.system),
                            child: Row(
                              children: const [
                                Icon(Icons.settings),
                                SizedBox(width: 12),
                                Text('System'),
                              ],
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, ThemeMode.light),
                            child: Row(
                              children: const [
                                Icon(Icons.wb_sunny),
                                SizedBox(width: 12),
                                Text('Light'),
                              ],
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, ThemeMode.dark),
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
                ref.read(settingsProvider.notifier).setThemeMode(result);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme updated')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Accent color'),
            // subtitle: Text('#${settings.seedColor.toRadixString(16).padLeft(8, '0').toUpperCase()}'),
            onTap: () async {
              final colors = <int>[
                0xFF607D8B, // Blue Grey
                0xFF3F51B5, // Indigo
                0xFF009688, // Teal
                0xFFFF5722, // Deep Orange
                0xFF9C27B0, // Purple
                0xFF4CAF50, // Green
              ];
              final result = await showDialog<int>(
                context: context,
                builder: (_) => SimpleDialog(
                  insetPadding: const EdgeInsets.all(24),
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
                                        ? (settings.themeMode == ThemeMode.dark ? Colors.white : Colors.black)
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
                ref.read(settingsProvider.notifier).setSeedColor(result);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Accent color updated')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset to defaults'),
            subtitle: const Text('Restore all settings to defaults'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reset settings'),
                  content: const Text('Are you sure you want to reset all settings to defaults?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(settingsProvider.notifier).resetDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                }
              }
            },
          ),
          SwitchListTile(
            value: settings.notificationsEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
            title: const Text('Notifications'),
          ),
          ListTile(
            title: const Text('Default reminder'),
            subtitle: Text('${settings.defaultReminderMinutes} minutes before'),
            onTap: () async {
              final controller = TextEditingController(
                  text: settings.defaultReminderMinutes.toString());
              final result = await showDialog<int>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Default reminder (minutes)'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        int.tryParse(controller.text.trim()),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (result != null) {
                ref
                    .read(settingsProvider.notifier)
                    .setReminderMinutes(result.clamp(0, 1440));
              }
            },
          ),
          ListTile(
            title: const Text('Default priority'),
            subtitle: Text(settings.defaultPriority.name),
            onTap: () async {
              final result = await showDialog<Priority>(
                context: context,
                builder: (_) => SimpleDialog(
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
                ref.read(settingsProvider.notifier).setPriority(result);
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Export data'),
            subtitle: const Text('Copy JSON to clipboard'),
            onTap: () async {
              final data = ref.read(taskListProvider.notifier).exportJson();
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exported to clipboard')),
                );
              }
            },
          ),
          ListTile(
            title: const Text('Import data'),
            subtitle: const Text('Paste JSON to restore'),
            onTap: () async {
              final controller = TextEditingController();
              final json = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Import JSON'),
                  content: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: 'Paste JSON here'),
                    maxLines: 6,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );
              if (json != null && json.isNotEmpty) {
                await ref.read(taskListProvider.notifier).importJson(json);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Import completed')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
