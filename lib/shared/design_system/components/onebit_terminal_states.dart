import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// Domain-specific error states with terminal semantics.
///
/// Each widget composes the base design system states with domain-appropriate
/// icons, messages, and suggested actions. All strings are expected to be
/// localized by the caller.
abstract final class OneBitTerminalStates {
  const OneBitTerminalStates._();
}

/// [WARN] Bluetooth disabled — the mesh radio cannot start.
class OneBitBluetoothDisabledState extends StatelessWidget {
  const OneBitBluetoothDisabledState({
    required this.message,
    this.detail,
    this.onOpenSettings,
    this.settingsLabel = 'Open settings',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onOpenSettings;
  final String settingsLabel;

  @override
  Widget build(BuildContext context) {
    return OneBitPermissionState(
      title: 'Bluetooth disabled',
      message: message,
      icon: OneBitIcons.bluetoothDisabled,
      onRequest: onOpenSettings ?? () {},
      requestLabel: settingsLabel,
      denied: true,
      onOpenSettings: onOpenSettings,
      settingsLabel: settingsLabel,
    );
  }
}

/// [ERR] Mesh unavailable — the mesh radio is not running.
class OneBitMeshUnavailableState extends StatelessWidget {
  const OneBitMeshUnavailableState({
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mesh unavailable. $message',
      child: OneBitErrorState(
        message: message,
        detail: detail,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }
}

/// [ERR] Storage full — not enough space for the operation.
class OneBitStorageFullState extends StatelessWidget {
  const OneBitStorageFullState({
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Storage full. $message',
      child: OneBitErrorState(
        message: message,
        detail: detail,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }
}

/// [ERR] Transfer failed — the attachment could not be delivered.
class OneBitTransferFailedState extends StatelessWidget {
  const OneBitTransferFailedState({
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Transfer failed. $message',
      child: OneBitErrorState(
        message: message,
        detail: detail,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }
}

/// [ERR] Database error — a local storage operation failed.
class OneBitDatabaseErrorState extends StatelessWidget {
  const OneBitDatabaseErrorState({
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Database error. $message',
      child: OneBitErrorState(
        message: message,
        detail: detail,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }
}

/// [ERR] Unknown error — an unexpected failure occurred.
class OneBitUnknownErrorState extends StatelessWidget {
  const OneBitUnknownErrorState({
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Unknown error. $message',
      child: OneBitErrorState(
        message: message,
        detail: detail,
        onRetry: onRetry,
        retryLabel: retryLabel,
      ),
    );
  }
}

/// [INFO] No results — the search or filter returned nothing.
class OneBitNoResultsState extends StatelessWidget {
  const OneBitNoResultsState({
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No results. $title',
      child: OneBitEmptyState(
        icon: OneBitIcons.search,
        title: title,
        message: message,
        action: action,
      ),
    );
  }
}

/// [INFO] No nodes — keep this screen open while nearby nodes announce themselves.
class OneBitNoNodesState extends StatelessWidget {
  const OneBitNoNodesState({
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No nodes. $title',
      child: OneBitEmptyState(
        icon: OneBitIcons.shellNodes,
        title: title,
        message: message,
        action: action,
      ),
    );
  }
}

/// [INFO] No channels — no conversations yet.
class OneBitNoChannelsState extends StatelessWidget {
  const OneBitNoChannelsState({
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No channels. $title',
      child: OneBitEmptyState(
        icon: OneBitIcons.shellChannels,
        title: title,
        message: message,
        action: action,
      ),
    );
  }
}
