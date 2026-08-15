import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_connection_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/features/nearby/presentation/nearby_controller.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Nearby tab: live Bluetooth discovery.
///
/// Renders exclusively from [nearbyViewProvider]; scan and permission
/// actions delegate to the existing Bluetooth controllers. Peer identifiers
/// and signal values render in the technical family.
class NearbyScreen extends ConsumerWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(nearbyViewProvider);
    final scanning = view.value?.scanning ?? false;

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.nearbyTitle),
        actions: [
          OneBitIconButton(
            icon: OneBitIcons.radar,
            tooltip: l10n.nearbyScanToggle,
            onPressed: scanning
                ? () => unawaited(
                    ref.read(nearbyViewProvider.notifier).stopScan(),
                  )
                : () => unawaited(
                    ref.read(nearbyViewProvider.notifier).startScan(),
                  ),
          ),
          OneBitIconButton(
            icon: OneBitIcons.shellSettings,
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(AppRoutePaths.settings),
          ),
        ],
      ),
      body: _body(context, ref, view),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NearbyView> view,
  ) {
    final l10n = context.l10n;
    if (view.hasError) {
      return OneBitErrorState(
        message: l10n.nearbyLoadError,
        detail: view.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.invalidate(nearbyViewProvider),
      );
    }
    final value = view.value;
    if (value == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (value.error != null && value.isEmpty) {
      return OneBitErrorState(
        message: l10n.nearbyLoadError,
        detail: value.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.read(nearbyViewProvider.notifier).retry(),
      );
    }

    switch (value.radio) {
      case BluetoothRadioState.off:
        return OneBitOfflineState(
          title: l10n.nearbyRadioOffTitle,
          message: l10n.nearbyRadioOffMessage,
        );
      case BluetoothRadioState.unavailable:
        return OneBitOfflineState(
          title: l10n.nearbyRadioUnavailableTitle,
          message: l10n.nearbyRadioUnavailableMessage,
        );
      case BluetoothRadioState.unknown:
      case BluetoothRadioState.initializing:
      case BluetoothRadioState.ready:
        break;
    }

    if (!value.permission.isGranted) {
      final permanentlyDenied =
          value.permission == BluetoothPermissionState.denied ||
          value.permission == BluetoothPermissionState.deniedForever;
      return OneBitPermissionState(
        title: l10n.nearbyPermissionTitle,
        message: permanentlyDenied
            ? l10n.nearbyPermissionDeniedMessage
            : l10n.nearbyPermissionMessage,
        requestLabel: permanentlyDenied ? l10n.commonRetry : l10n.nearbyScan,
        onRequest: permanentlyDenied
            ? () => unawaited(
                ref.read(nearbyViewProvider.notifier).recoverPermission(),
              )
            : () => unawaited(
                ref.read(nearbyViewProvider.notifier).requestPermission(),
              ),
      );
    }

    if (value.isEmpty) {
      return OneBitEmptyState(
        icon: OneBitIcons.shellNearby,
        title: l10n.nearbyEmpty,
        message: l10n.nearbyEmptyMessage,
      );
    }
    return _peerList(context, ref, value);
  }

  Widget _peerList(BuildContext context, WidgetRef ref, NearbyView view) {
    final l10n = context.l10n;
    final colors = context.oneBitColors;
    final links = ref.watch(bluetoothLinkControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OneBitSpacing.m,
            OneBitSpacing.m,
            OneBitSpacing.m,
            0,
          ),
          child: OneBitSectionHeader(
            title: l10n.nearbyPeersTitle,
            subtitle: view.scanning
                ? l10n.nearbyScanning
                : l10n.nearbyPeerCount(view.peers.length),
            trailing: view.scanning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.info,
                    ),
                  )
                : null,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            itemCount: view.peers.length,
            itemBuilder: (context, index) {
              final peer = view.peers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: OneBitSpacing.s),
                child: _PeerCard(
                  peer: peer,
                  connection: links.connections[peer.peerId],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One discovered device: technical id, RSSI, link stage and last seen.
final class _PeerCard extends ConsumerWidget {
  const _PeerCard({required this.peer, this.connection});

  final NearbyPeer peer;

  /// Latest known link stage; `null` when the transport never connected.
  final BluetoothConnectionState? connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return OneBitCard(
      onTap: () => context.go(AppRoutePaths.nodeOf(peer.peerId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  peer.peerId,
                  style: OneBitTypography.technicalStyle(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (connection != null) ...[
                const SizedBox(width: OneBitSpacing.s),
                OneBitStatusChip.preset(connectionPresetFor(connection!)),
              ],
            ],
          ),
          const SizedBox(height: OneBitSpacing.m),
          Row(
            children: [
              Icon(
                OneBitIcons.signal,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OneBitSpacing.s),
              Text(
                '${peer.rssiDb} dBm',
                style: OneBitTypography.technicalStyle(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${l10n.nodeLastSeen} ${relativeTimeLabel(l10n, peer.lastSeen)}',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Relative "last seen" text ("just now", "5 min ago", …).
String relativeTimeLabel(AppLocalizations l10n, DateTime time) =>
    RelativeTime.of(time).label(l10n);
