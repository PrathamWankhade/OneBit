import 'package:flutter/material.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_repository.dart';

// RSSI thresholds for signal strength classification.
const _rssiExcellent = -50;
const _rssiStrong = -65;
const _rssiGood = -75;
const _rssiFair = -85;

// Time thresholds for "last seen" formatting (milliseconds).
const _justNowMs = 5000;
const _oneMinuteMs = 60000;
const _oneHourMs = 3600000;

class DiscoveredDeviceTile extends StatelessWidget {
  const DiscoveredDeviceTile({
    super.key,
    required this.device,
    this.connectionState,
    this.onConnect,
    this.onDisconnect,
  });

  /// The resolved BLE device (includes peer identity if available).
  final DiscoveredOneBitDevice device;
  final BleConnectionInfo? connectionState;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = device.name ?? 'OneBit device';
    final signalLabel = _signalLabel(device.rssi);
    final signalIcon = _signalIcon(device.rssi);
    final lastSeen = _formatLastSeen(device.timestamp);

    final connState = connectionState?.state ?? BleConnectionState.disconnected;
    final isConnecting = connState == BleConnectionState.connecting;
    final isConnected = connState == BleConnectionState.connected;
    final isDisconnecting = connState == BleConnectionState.disconnecting;

    return ListTile(
      leading: CircleAvatar(
        child: Icon(signalIcon),
      ),
      title: Text(displayName),
      subtitle: Text(
        'Signal: $signalLabel \u00b7 $lastSeen',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: _buildTrailing(context, connState, isConnecting, isConnected,
          isDisconnecting),
    );
  }

  Widget? _buildTrailing(
    BuildContext context,
    BleConnectionState connState,
    bool isConnecting,
    bool isConnected,
    bool isDisconnecting,
  ) {
    if (isConnecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isConnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onDisconnect,
            child: const Text('Disconnect'),
          ),
        ],
      );
    }
    if (isDisconnecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (connState == BleConnectionState.error) {
      return TextButton(
        onPressed: onConnect,
        child: const Text('Retry'),
      );
    }
    if (onConnect != null) {
      return TextButton(
        onPressed: onConnect,
        child: const Text('Connect'),
      );
    }
    return null;
  }

  String _signalLabel(int rssi) {
    if (rssi >= _rssiExcellent) return 'Excellent';
    if (rssi >= _rssiStrong) return 'Strong';
    if (rssi >= _rssiGood) return 'Good';
    if (rssi >= _rssiFair) return 'Fair';
    return 'Weak';
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= _rssiExcellent) return Icons.signal_cellular_4_bar;
    if (rssi >= _rssiStrong) return Icons.signal_cellular_alt;
    if (rssi >= _rssiGood) return Icons.signal_cellular_alt_2_bar;
    if (rssi >= _rssiFair) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_off;
  }

  String _formatLastSeen(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestampMs;
    if (diff < _justNowMs) return 'Just now';
    if (diff < _oneMinuteMs) return '${(diff ~/ 1000)}s ago';
    if (diff < _oneHourMs) return '${(diff ~/ 60000)}m ago';
    return 'A while ago';
  }
}

/// Identity-aware tile for displaying a resolved BLE device.
///
/// Shows the peer's display name if known, or the BLE device name.
/// Shows identity status (Known / Unknown) and fingerprint for known peers.
class ResolvedDeviceTile extends StatelessWidget {
  const ResolvedDeviceTile({
    super.key,
    required this.resolved,
    this.connectionState,
    this.onConnect,
    this.onDisconnect,
  });

  final ResolvedBleDevice resolved;
  final BleConnectionInfo? connectionState;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = resolved.device;
    final peer = resolved.peer;

    final signalLabel = _signalLabel(device.rssi);
    final signalIcon = _signalIcon(device.rssi);
    final lastSeen = _formatLastSeen(device.timestamp);

    final connState = connectionState?.state ?? BleConnectionState.disconnected;
    final isConnecting = connState == BleConnectionState.connecting;
    final isConnected = connState == BleConnectionState.connected;
    final isDisconnecting = connState == BleConnectionState.disconnecting;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _avatarColor(theme, resolved.status),
        child: Icon(signalIcon, color: theme.colorScheme.onPrimary),
      ),
      title: Text(resolved.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(resolved.status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _statusColor(theme, resolved.status),
            ),
          ),
          if (resolved.status == BlePeerStatus.identityChanged &&
              resolved.identityChange != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'This device presents a different cryptographic identity '
                'than previously associated.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (peer != null && peer.identityId != null)
            FutureBuilder<String>(
              future: _computeFingerprint(peer.identityId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('...', style: TextStyle(fontSize: 11));
                }
                return Text(
                  fingerprintCompact(snapshot.data!),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          Text(
            'Signal: $signalLabel \u00b7 $lastSeen',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      isThreeLine: peer != null ||
          resolved.status == BlePeerStatus.identityChanged,
      trailing: _buildTrailing(connState, isConnecting, isConnected,
          isDisconnecting),
    );
  }

  Widget? _buildTrailing(
    BleConnectionState connState,
    bool isConnecting,
    bool isConnected,
    bool isDisconnecting,
  ) {
    if (isConnecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isConnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onDisconnect,
            child: const Text('Disconnect'),
          ),
        ],
      );
    }
    if (isDisconnecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (connState == BleConnectionState.error) {
      return TextButton(
        onPressed: onConnect,
        child: const Text('Retry'),
      );
    }
    if (onConnect != null) {
      return TextButton(
        onPressed: onConnect,
        child: const Text('Connect'),
      );
    }
    return null;
  }

  Color _avatarColor(ThemeData theme, BlePeerStatus status) {
    switch (status) {
      case BlePeerStatus.knownPeer:
        return theme.colorScheme.primary;
      case BlePeerStatus.selfIdentity:
        return theme.colorScheme.tertiary;
      case BlePeerStatus.unknownIdentity:
        return theme.colorScheme.secondary;
      case BlePeerStatus.noIdentity:
        return theme.colorScheme.surfaceContainerHighest;
      case BlePeerStatus.identityChanged:
        return theme.colorScheme.error;
    }
  }

  String _statusLabel(BlePeerStatus status) {
    switch (status) {
      case BlePeerStatus.knownPeer:
        return 'Known';
      case BlePeerStatus.selfIdentity:
        return 'You';
      case BlePeerStatus.unknownIdentity:
        return 'Unknown';
      case BlePeerStatus.noIdentity:
        return 'Nearby';
      case BlePeerStatus.identityChanged:
        return 'Identity Changed';
    }
  }

  Color _statusColor(ThemeData theme, BlePeerStatus status) {
    switch (status) {
      case BlePeerStatus.knownPeer:
        return theme.colorScheme.primary;
      case BlePeerStatus.selfIdentity:
        return theme.colorScheme.tertiary;
      case BlePeerStatus.unknownIdentity:
        return theme.colorScheme.onSurfaceVariant;
      case BlePeerStatus.noIdentity:
        return theme.colorScheme.onSurfaceVariant;
      case BlePeerStatus.identityChanged:
        return theme.colorScheme.error;
    }
  }

  Future<String> _computeFingerprint(String identityIdHex) async {
    final bytes = IdentityRepository.hexToBytes(identityIdHex);
    return computeFingerprint(bytes);
  }

  String _signalLabel(int rssi) {
    if (rssi >= _rssiExcellent) return 'Excellent';
    if (rssi >= _rssiStrong) return 'Strong';
    if (rssi >= _rssiGood) return 'Good';
    if (rssi >= _rssiFair) return 'Fair';
    return 'Weak';
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= _rssiExcellent) return Icons.signal_cellular_4_bar;
    if (rssi >= _rssiStrong) return Icons.signal_cellular_alt;
    if (rssi >= _rssiGood) return Icons.signal_cellular_alt_2_bar;
    if (rssi >= _rssiFair) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_off;
  }

  String _formatLastSeen(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestampMs;
    if (diff < _justNowMs) return 'Just now';
    if (diff < _oneMinuteMs) return '${(diff ~/ 1000)}s ago';
    if (diff < _oneHourMs) return '${(diff ~/ 60000)}m ago';
    return 'A while ago';
  }
}
