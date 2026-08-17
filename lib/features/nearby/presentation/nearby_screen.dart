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
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/features/nearby/presentation/nearby_controller.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_page_header.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
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
    final view = ref.watch(nearbyViewProvider);
    final scanning = view.value?.scanning ?? false;

    return OneBitScaffold(
      body: _body(context, ref, view, scanning),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NearbyView> view,
    bool scanning,
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

    final headerActions = [
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
        onPressed: () => context.go(AppRoutePaths.nearbySettings),
      ),
    ];

    Widget body;
    final radioOff =
        value.radio == BluetoothRadioState.off ||
        value.radio == BluetoothRadioState.unavailable;
    final permissionDenied = !value.permission.isGranted;
    final permanentlyDenied =
        value.permission == BluetoothPermissionState.denied ||
        value.permission == BluetoothPermissionState.deniedForever;

    if (radioOff) {
      body = OneBitOfflineState(
        title: value.radio == BluetoothRadioState.off
            ? l10n.nearbyRadioOffTitle
            : l10n.nearbyRadioUnavailableTitle,
        message: value.radio == BluetoothRadioState.off
            ? l10n.nearbyRadioOffMessage
            : l10n.nearbyRadioUnavailableMessage,
      );
    } else if (permissionDenied) {
      body = OneBitPermissionState(
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
    } else if (value.isEmpty) {
      body = OneBitEmptyState(
        icon: OneBitIcons.shellNearby,
        title: l10n.nearbyEmpty,
        message: l10n.nearbyEmptyMessage,
        secondaryInfo: value.scanning ? const _ScanningPulse() : null,
      );
    } else {
      body = _peerList(context, ref, value, scanning);
    }

    final colors = context.oneBitColors;
    return Column(
      children: [
        OneBitPageHeader.status(
          title: l10n.nearbyTitle,
          status: value.scanning ? l10n.nearbyScanning : '${value.peers.length}',
          statusColor: value.scanning ? colors.warning : colors.info,
          actions: headerActions,
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _peerList(
    BuildContext context,
    WidgetRef ref,
    NearbyView view,
    bool scanning,
  ) {
    final l10n = context.l10n;
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
            trailing: view.scanning ? const _ScanningPulse() : null,
          ),
        ),
        Expanded(
          child: context.isTablet
              ? _tabletPeerGrid(context, view, links)
              : _phonePeerList(context, view, links, scanning),
        ),
      ],
    );
  }

  Widget _phonePeerList(
    BuildContext context,
    NearbyView view,
    BluetoothLinksView links,
    bool scanning,
  ) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitScrollClearance.bottom(context),
      ),
      itemCount: view.peers.length,
      itemBuilder: (context, index) {
        final peer = view.peers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: OneBitSpacing.s),
          child: _AnimatedPeerCard(
            peer: peer,
            connection: links.connections[peer.peerId],
          ),
        );
      },
    );
  }

  Widget _tabletPeerGrid(
    BuildContext context,
    NearbyView view,
    BluetoothLinksView links,
  ) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitScrollClearance.bottom(context),
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 2.5,
        crossAxisSpacing: OneBitSpacing.m,
        mainAxisSpacing: OneBitSpacing.s,
      ),
      itemCount: view.peers.length,
      itemBuilder: (context, index) {
        final peer = view.peers[index];
        return _AnimatedPeerCard(
          peer: peer,
          connection: links.connections[peer.peerId],
        );
      },
    );
  }
}

/// Animated wrapper around [_PeerCard] that plays a subtle slide+fade
/// entrance when a new peer appears. Duration: 200ms (within 180–240ms).
///
/// Each card owns its own [AnimationController] so new entries animate
/// independently without affecting existing items.
class _AnimatedPeerCard extends StatefulWidget {
  const _AnimatedPeerCard({required this.peer, this.connection});

  final NearbyPeer peer;
  final BluetoothConnectionState? connection;

  @override
  State<_AnimatedPeerCard> createState() => _AnimatedPeerCardState();
}

class _AnimatedPeerCardState extends State<_AnimatedPeerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _controller = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: OneBitMotion.emphasized,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: OneBitMotion.emphasized,
      ),
    );
    if (!_reduceMotion) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return _PeerCard(
        peer: widget.peer,
        connection: widget.connection,
      );
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _PeerCard(
          peer: widget.peer,
          connection: widget.connection,
        ),
      ),
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

/// Pulsing scanning indicator — a small animated dot that communicates
/// active discovery without dominating the screen.
class _ScanningPulse extends StatefulWidget {
  const _ScanningPulse();

  @override
  State<_ScanningPulse> createState() => _ScanningPulseState();
}

class _ScanningPulseState extends State<_ScanningPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _controller = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : OneBitMotion.statusPulse,
    );
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (!_reduceMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    if (_reduceMotion) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: colors.info,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Opacity(
          opacity: _pulse.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.info,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Relative "last seen" text ("just now", "5 min ago", …).
String relativeTimeLabel(AppLocalizations l10n, DateTime time) =>
    RelativeTime.of(time).label(l10n);
