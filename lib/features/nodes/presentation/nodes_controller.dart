import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/presentation/trust_contacts_controller.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';

/// Presentation mapping of a mesh link lifecycle to a status chip preset;
/// `null` for nodes with no live observation.
OneBitStatusPreset? connectionPresetFor(MeshLinkState? state) =>
    switch (state) {
      MeshLinkState.connected => OneBitStatusPreset.online,
      MeshLinkState.connecting => OneBitStatusPreset.connecting,
      MeshLinkState.disconnecting => OneBitStatusPreset.connecting,
      MeshLinkState.advertising => OneBitStatusPreset.pending,
      MeshLinkState.disconnected => OneBitStatusPreset.offline,
      null => null,
    };

/// Presentation mapping of a trust posture to a status chip preset.
OneBitStatusPreset? verificationPresetFor(TrustLevel? level) => switch (level) {
  TrustLevel.verified => OneBitStatusPreset.verified,
  TrustLevel.known => OneBitStatusPreset.unverified,
  TrustLevel.blocked => OneBitStatusPreset.failed,
  null => null,
};

/// A trusted contact, augmented with live link data when the same node is
/// currently observed as a mesh neighbor.
final class TrustedNodeRow {
  const TrustedNodeRow({required this.contact, this.neighbor});

  /// Identity material from the local contact list.
  final TrustContact contact;

  /// Live link observation, when the node is currently a mesh neighbor.
  final MeshNeighbor? neighbor;

  String get nodeId => contact.nodeId.value;

  String get name => contact.displayName;

  String get fingerprint => contact.fingerprintHex;

  TrustLevel get trustLevel => contact.trustLevel;

  DateTime? get lastSeen => neighbor?.lastSeen ?? contact.lastSeenAt;

  /// Hop count from the neighbor observation, or null if not observed.
  int? get hopEstimate => neighbor?.hopEstimate;

  /// Whether a route is available (node is currently observed).
  bool get hasRoute => neighbor != null;
}

/// A mesh neighbor that is not (yet) a trusted contact.
final class NearbyNodeRow {
  const NearbyNodeRow({required this.neighbor});

  /// Live link observation from the mesh engine.
  final MeshNeighbor neighbor;

  String get nodeId => neighbor.nodeId;

  /// Hop count from the neighbor observation.
  int get hopEstimate => neighbor.hopEstimate;

  /// Distance estimate in meters, if available.
  double? get distanceEstimate => neighbor.distanceEstimateMeters;

  /// Whether a route is available (always true for observed neighbors).
  bool get hasRoute => true;
}

/// Renders the node registry: trusted contacts and live nearby nodes.
///
/// Presentation-only aggregation: trusted entries come from the identity
/// contacts controller, nearby entries from the mesh neighbor stream.
/// Every action (trust changes, removal, conversation) is delegated to the
/// existing controllers and use cases.
final AsyncNotifierProvider<NodesController, NodesView> nodesViewProvider =
    AsyncNotifierProvider<NodesController, NodesView>(NodesController.new);

final class NodesView {
  const NodesView({
    required this.trusted,
    required this.nearby,
    required this.offline,
    required this.loaded,
    this.error,
  });

  /// Contacts with identity material, most recently seen first.
  final List<TrustedNodeRow> trusted;

  /// Live neighbors outside the contact list, strongest signal first.
  final List<NearbyNodeRow> nearby;

  /// Whether the mesh engine is not running (list stays usable).
  final bool offline;

  /// Whether the underlying streams have emitted at least once.
  final bool loaded;

  /// Stream failure, when the registry could not load.
  final Object? error;

  bool get isEmpty => trusted.isEmpty && nearby.isEmpty;
}

final class NodesController extends AsyncNotifier<NodesView> {
  @override
  Future<NodesView> build() async {
    final contactsAsync = ref.watch(trustContactsControllerProvider);
    final neighborsAsync = ref.watch(meshNeighborsProvider);
    final meshAsync = ref.watch(meshStateProvider);

    final engineState = meshAsync.value?.value;
    final offline =
        engineState != null && engineState != MeshEngineState.running;

    final neighbors = <MeshNeighbor>[];
    if (neighborsAsync.hasError) {
      return NodesView(
        trusted: const [],
        nearby: const [],
        offline: offline,
        loaded: true,
        error: neighborsAsync.error,
      );
    }
    final neighborsResult = neighborsAsync.value;
    if (neighborsResult != null && neighborsResult.isErr) {
      return NodesView(
        trusted: const [],
        nearby: const [],
        offline: offline,
        loaded: true,
        error: neighborsResult.failure,
      );
    }
    if (neighborsResult != null) neighbors.addAll(neighborsResult.value!);

    if (contactsAsync.hasError) {
      return NodesView(
        trusted: const [],
        nearby: const [],
        offline: offline,
        loaded: true,
        error: contactsAsync.error,
      );
    }
    final contacts = contactsAsync.value ?? const <TrustContact>[];
    final loaded = contactsAsync.hasValue && neighborsAsync.hasValue;

    final neighborById = {for (final n in neighbors) n.nodeId: n};
    final knownIds = {for (final c in contacts) c.nodeId.value};

    final trusted = <TrustedNodeRow>[
      for (final contact in contacts)
        TrustedNodeRow(
          contact: contact,
          neighbor: neighborById[contact.nodeId.value],
        ),
    ]..sort((a, b) => _compareLastSeen(b.lastSeen, a.lastSeen));

    final nearby =
        <NearbyNodeRow>[
          for (final neighbor in neighbors)
            if (!knownIds.contains(neighbor.nodeId))
              NearbyNodeRow(neighbor: neighbor),
        ]..sort(
          (a, b) =>
              b.neighbor.smoothedRssiDb.compareTo(a.neighbor.smoothedRssiDb),
        );

    return NodesView(
      trusted: trusted,
      nearby: nearby,
      offline: offline,
      loaded: loaded,
    );
  }

  static int _compareLastSeen(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  /// Re-runs the registry streams (error recovery).
  void retry() {
    ref.invalidate(trustContactsControllerProvider);
    ref.invalidate(meshNeighborsProvider);
  }
}
