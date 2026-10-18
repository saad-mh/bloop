import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/permission_status_provider.dart';
import '../theme/tokens.dart';

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
    // Providers can't change while the tree is building.
    Future.microtask(() {
      if (mounted) ref.read(permissionStatusProvider.notifier).refresh();
    });
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
        child: CircularProgressIndicator(
          strokeWidth: 2,
          semanticsLabel: 'Loading',
          year2023: false,
        ),
      );
    }
    return Icon(
      granted
          ? CupertinoIcons.checkmark_seal_fill
          : CupertinoIcons.exclamationmark_triangle,
      color: granted
          ? BloopTokens.of(context).ink
          : BloopTokens.of(context).muted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ref.watch(permissionStatusProvider);
    final controller = ref.read(permissionStatusProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Required permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
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
                        icon: const Icon(LucideIcons.settings),
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
                        icon: const Icon(LucideIcons.settings),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
