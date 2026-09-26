import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/nearby/presentation/peer_card.dart';
import 'package:onebit/features/ui/components/one_bit_components.dart';

/// F5 — Peer Discovery / BLE Mesh Experience.
///
/// Shows nearby OneBit nodes, signal strength, connection state,
/// and mesh topology. Communicates decentralized peer discovery.
class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen>
    with TickerProviderStateMixin {
  final Map<String, ResolvedBleDevice> _resolvedDevices = {};
  StreamSubscription<ResolvedBleDevice>? _resolvedSub;
  BleStateNotifier? _notifier;
  late AnimationController _pulseController;

  /// Whether discoverability has been started automatically.
  ///
  /// Being visible to other nodes was previously a manual action hidden
  /// behind a button at the bottom of the screen, so a phone that nobody
  /// remembered to put into advertise mode simply never showed up in anyone
  /// else's list. Start it as soon as the radio and permissions allow.
  ///
  /// Scanning is deliberately *not* started automatically — it is the
  /// state this screen is built around ("Scan again") and stays under the
  /// user's control.
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(bleStateProvider.notifier);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
  }

  @override
  void dispose() {
    _resolvedSub?.cancel();
    _notifier?.stopScan();
    _notifier?.stopAdvertising();
    _pulseController.dispose();
    super.dispose();
  }

  void _startListening() {
    _resolvedSub?.cancel();
    setState(() => _resolvedDevices.clear());
    final resolver = ref.read(bleIdentityResolverProvider);
    _resolvedSub = resolver.resolvedStream.listen((resolved) {
      if (!mounted) return;
      setState(() {
        _resolvedDevices[resolved.device.deviceId] = resolved;
      });
    });
  }

  /// Makes this device discoverable once BLE is ready.
  ///
  /// Called after the first frame and re-checked whenever the screen
  /// rebuilds, because radio and permission state only settle once
  /// `getState` has answered. It no-ops until BLE is operational and only
  /// ever starts once.
  Future<void> _maybeAutoStart() async {
    if (_autoStarted || !mounted) return;
    final notifier = _notifier;
    if (notifier == null) return;
    if (!ref.read(bleStateProvider).isOperational) return;
    _autoStarted = true;

    // Advertising carries the local public key, so wait for the identity to
    // load — without it, peers only ever see an anonymous "OneBit device".
    try {
      await ref.read(localIdentityProvider.future);
    } catch (e) {
      AppLogger.warning('Nearby: identity unavailable before advertising: $e');
    }
    if (!mounted) return;
    await _startAdvertising();
  }

  Future<void> _startScan() async {
    final notifier = ref.read(bleStateProvider.notifier);
    try {
      await notifier.startScan();
      _startListening();
    } on BleScanException {
      // Error state is reflected via bleStateProvider.
    }
  }

  Future<void> _stopScan() async {
    final notifier = ref.read(bleStateProvider.notifier);
    await notifier.stopScan();
    _resolvedSub?.cancel();
    _resolvedSub = null;
  }

  Future<void> _startAdvertising() async {
    final notifier = ref.read(bleStateProvider.notifier);
    final identityAsync = ref.read(localIdentityProvider);
    final identity = identityAsync.valueOrNull;
    try {
      await notifier.startAdvertising(
        identityPublicKeyBytes: identity?.publicKeyBytes,
      );
    } on BleAdvertisingException {
      // Error state is reflected via bleStateProvider.
    }
  }

  Future<void> _stopAdvertising() async {
    final notifier = ref.read(bleStateProvider.notifier);
    await notifier.stopAdvertising();
  }

  Future<void> _connectDevice(String deviceId) async {
    final notifier = ref.read(bleStateProvider.notifier);
    try {
      await notifier.connect(deviceId);
    } on BleConnectionException {
      // Error state is reflected via bleStateProvider.
    }
  }

  Future<void> _disconnectDevice(String deviceId) async {
    final notifier = ref.read(bleStateProvider.notifier);
    await notifier.disconnect(deviceId);
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleStateProvider);
    if (!_autoStarted) {
      // Radio and permission state only settle after the first frame has
      // been requested, so retry once this frame has actually rendered.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
    }
    final isScanning = bleState.isScanning;
    final devices = _resolvedDevices.values.toList();

    return Scaffold(
      appBar: _NearbyAppBar(
        isScanning: isScanning,
        deviceCount: devices.length,
        onRefresh: isScanning ? _stopScan : _startScan,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildBody(bleState, isScanning, devices),
          ),
          _BottomActions(
            isAdvertising: bleState.isAdvertising,
            onStartAdvertising: _startAdvertising,
            onStopAdvertising: _stopAdvertising,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BleState bleState,
    bool isScanning,
    List<ResolvedBleDevice> devices,
  ) {
    if (bleState.needsBluetoothEnable) {
      return _BluetoothDisabledState(
        onOpenSettings: () async {
          await ref.read(bleStateProvider.notifier).openBluetoothSettings();
          await _maybeAutoStart();
        },
      );
    }

    if (bleState.needsPermissionRequest || bleState.needsManualRecovery) {
      return _PermissionRequiredState(
        onRequest: () async {
          await ref.read(bleStateProvider.notifier).requestPermissions();
          await _maybeAutoStart();
        },
        onRecover: bleState.needsManualRecovery
            ? () async {
                await ref.read(bleStateProvider.notifier).recoverPermissions();
                await _maybeAutoStart();
              }
            : null,
      );
    }

    if (bleState.scan == BleScanState.error) {
      return _ErrorState(onRetry: _startScan);
    }

    if (isScanning) {
      return _ScanningState(
        devices: devices,
        pulseController: _pulseController,
        connections: bleState.connections,
        onConnect: _connectDevice,
        onDisconnect: _disconnectDevice,
      );
    }

    if (devices.isEmpty) {
      return _NoPeersState(onScan: _startScan);
    }

    return _PeersFoundState(
      devices: devices,
      connections: bleState.connections,
      onConnect: _connectDevice,
      onDisconnect: _disconnectDevice,
      onScan: _startScan,
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────

class _NearbyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NearbyAppBar({
    required this.isScanning,
    required this.onRefresh,
    this.deviceCount = 0,
  });

  final bool isScanning;
  final VoidCallback onRefresh;
  final int deviceCount;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nearby'),
          if (deviceCount > 0)
            Text(
              '$deviceCount device${deviceCount == 1 ? '' : 's'} found',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
        ],
      ),
      actions: [
        if (isScanning)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, size: 24, color: AppTheme.textSecondary),
            onPressed: onRefresh,
            tooltip: 'Scan again',
          ),
      ],
    );
  }
}

// ── Scanning State ─────────────────────────────────────────────────

class _ScanningState extends StatelessWidget {
  const _ScanningState({
    required this.devices,
    required this.pulseController,
    required this.connections,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<ResolvedBleDevice> devices;
  final AnimationController pulseController;
  final Map<String, BleConnectionInfo> connections;
  final void Function(String) onConnect;
  final void Function(String) onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (devices.isEmpty)
          Expanded(
            child: _ScanningAnimation(pulseController: pulseController),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '${devices.length} nearby',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _PeerList(
              devices: devices,
              connections: connections,
              onConnect: onConnect,
              onDisconnect: onDisconnect,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Scanning Animation ─────────────────────────────────────────────

class _ScanningAnimation extends StatelessWidget {
  const _ScanningAnimation({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PulsePainter(
                      progress: pulseController.value,
                      color: AppTheme.accent,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_tethering,
                        size: 48,
                        color: AppTheme.accent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          const Text(
            'Scanning for peers',
            style: AppTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Looking for nearby OneBit devices via Bluetooth',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space16),
          // Mesh hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.meshMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.mesh.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_tethering, size: 14, color: AppTheme.mesh),
                SizedBox(width: 6),
                Text(
                  'No internet required — mesh only',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for pulse rings animation.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      final radius = 20.0 + (t * 40.0);
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── Peers Found State ──────────────────────────────────────────────

class _PeersFoundState extends StatelessWidget {
  const _PeersFoundState({
    required this.devices,
    required this.connections,
    required this.onConnect,
    required this.onDisconnect,
    required this.onScan,
  });

  final List<ResolvedBleDevice> devices;
  final Map<String, BleConnectionInfo> connections;
  final void Function(String) onConnect;
  final void Function(String) onDisconnect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${devices.length} nearby',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PeerList(
            devices: devices,
            connections: connections,
            onConnect: onConnect,
            onDisconnect: onDisconnect,
          ),
        ),
      ],
    );
  }
}

// ── No Peers State ─────────────────────────────────────────────────

class _NoPeersState extends StatelessWidget {
  const _NoPeersState({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return OneBitEmptyState(
      icon: Icons.wifi_tethering_off,
      title: 'No peers nearby',
      subtitle: 'Make sure other OneBit users are nearby and scanning. '
          'Devices must be within Bluetooth range (~10m).',
      actionLabel: 'Scan again',
      onAction: onScan,
    );
  }
}

// ── Peer List ──────────────────────────────────────────────────────

class _PeerList extends StatelessWidget {
  const _PeerList({
    required this.devices,
    required this.connections,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<ResolvedBleDevice> devices;
  final Map<String, BleConnectionInfo> connections;
  final void Function(String) onConnect;
  final void Function(String) onDisconnect;

  @override
  Widget build(BuildContext context) {
    final sorted = List<ResolvedBleDevice>.from(devices)
      ..sort((a, b) {
        if (a.status == BlePeerStatus.knownPeer &&
            b.status != BlePeerStatus.knownPeer) {
          return -1;
        }
        if (a.status != BlePeerStatus.knownPeer &&
            b.status == BlePeerStatus.knownPeer) {
          return 1;
        }
        return b.device.rssi.compareTo(a.device.rssi);
      });

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final resolved = sorted[index];
        final connState =
            connections[resolved.device.deviceId]?.state ?? BleConnectionState.disconnected;
        final isConnected = connState == BleConnectionState.connected;
        final isVerified =
            resolved.status == BlePeerStatus.knownPeer;

        return RepaintBoundary(
          key: ValueKey(resolved.device.deviceId),
          child: PeerCard(
            name: resolved.displayName,
            initials: resolved.displayName.isNotEmpty
                ? resolved.displayName[0].toUpperCase()
                : '?',
            rssi: resolved.device.rssi,
            isVerified: isVerified,
            isConnected: isConnected,
            lastSeen: _formatLastSeen(resolved.device.timestamp),
            onTap: () {
              if (!isConnected) {
                onConnect(resolved.device.deviceId);
              }
            },
          ),
        );
      },
    );
  }

  String _formatLastSeen(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestampMs;
    if (diff < 5000) return 'Just now';
    if (diff < 60000) return '${diff ~/ 1000}s ago';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    return 'A while ago';
  }
}

// ── Bottom Actions ─────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isAdvertising,
    required this.onStartAdvertising,
    required this.onStopAdvertising,
  });

  final bool isAdvertising;
  final VoidCallback onStartAdvertising;
  final VoidCallback onStopAdvertising;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgBase,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isAdvertising ? onStopAdvertising : onStartAdvertising,
              icon: Icon(
                isAdvertising ? Icons.stop_circle_outlined : Icons.wifi_tethering,
                size: 18,
              ),
              label: Text(isAdvertising ? 'Stop advertising' : 'Advertise'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OneBitEmptyState(
      icon: Icons.error_outline,
      title: 'Scan failed',
      subtitle: 'Bluetooth scanning encountered an error. '
          'Check that Bluetooth is enabled and try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

// ── Bluetooth Disabled State ───────────────────────────────────────

class _BluetoothDisabledState extends StatelessWidget {
  const _BluetoothDisabledState({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return OneBitEmptyState(
      icon: Icons.bluetooth_disabled,
      title: 'Bluetooth is off',
      subtitle: 'Enable Bluetooth to discover and connect to nearby OneBit peers.',
      actionLabel: 'Open settings',
      onAction: onOpenSettings,
    );
  }
}

// ── Permission Required State ──────────────────────────────────────

class _PermissionRequiredState extends StatelessWidget {
  const _PermissionRequiredState({
    required this.onRequest,
    this.onRecover,
  });

  final VoidCallback onRequest;
  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) {
    return OneBitEmptyState(
      icon: Icons.bluetooth_searching,
      title: 'Permission needed',
      subtitle: 'Bluetooth permission is required to discover nearby OneBit devices. '
          'This is used only for peer-to-peer mesh communication.',
      actionLabel: 'Grant permission',
      onAction: onRecover ?? onRequest,
    );
  }
}
