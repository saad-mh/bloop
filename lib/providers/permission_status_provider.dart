import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

@immutable
class PermissionStatusState {
  const PermissionStatusState({
    required this.isAndroid,
    required this.isLoading,
    this.notificationsGranted,
    this.exactAlarmGranted,
  });

  final bool isAndroid;
  final bool isLoading;
  final bool? notificationsGranted;
  final bool? exactAlarmGranted;

  PermissionStatusState copyWith({
    bool? isAndroid,
    bool? isLoading,
    bool? notificationsGranted,
    bool? exactAlarmGranted,
  }) {
    return PermissionStatusState(
      isAndroid: isAndroid ?? this.isAndroid,
      isLoading: isLoading ?? this.isLoading,
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      exactAlarmGranted: exactAlarmGranted ?? this.exactAlarmGranted,
    );
  }

  static PermissionStatusState initial() {
    return PermissionStatusState(
      isAndroid: Platform.isAndroid,
      isLoading: true,
      notificationsGranted: null,
      exactAlarmGranted: null,
    );
  }
}

class PermissionStatusNotifier extends StateNotifier<PermissionStatusState> {
  PermissionStatusNotifier() : super(PermissionStatusState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, isAndroid: Platform.isAndroid);

    if (!Platform.isAndroid) {
      state = state.copyWith(
        notificationsGranted: true,
        exactAlarmGranted: true,
        isLoading: false,
      );
      return;
    }

    try {
      final notif =
          await NotificationService.instance.hasNotificationPermission();
      final exact =
          await NotificationService.instance.checkExactAlarmAllowed();

      state = state.copyWith(
        notificationsGranted: notif == true,
        exactAlarmGranted: exact == true,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        notificationsGranted: false,
        exactAlarmGranted: false,
        isLoading: false,
      );
    }
  }

  Future<void> openNotificationSettings() async {
    await NotificationService.instance.openNotificationSettings();
  }

  Future<void> requestExactAlarmPermission() async {
    await NotificationService.instance.requestExactAlarmPermission();
  }
}

final permissionStatusProvider =
    StateNotifierProvider<PermissionStatusNotifier, PermissionStatusState>((ref) {
  return PermissionStatusNotifier();
});
