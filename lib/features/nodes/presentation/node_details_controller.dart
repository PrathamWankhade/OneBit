import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/crypto/verification/verification_code.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/domain/use_cases/derive_verification_code.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/identity/presentation/trust_contacts_controller.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

/// Aggregates everything the node details screen shows for one node:
/// identity material (when the node is a contact) plus live link data
/// (when it is currently a mesh neighbor).
final class NodeDetailsModel {
  const NodeDetailsModel({required this.nodeId, this.contact, this.neighbor});

  final String nodeId;

  /// Identity material; `null` for nodes outside the contact list.
  final TrustContact? contact;

  /// Live link observation; `null` when the node is not currently seen.
  final MeshNeighbor? neighbor;

  String get name => contact?.displayName ?? nodeId;

  String? get fingerprint => contact?.fingerprintHex;

  TrustLevel? get trustLevel => contact?.trustLevel;

  DateTime? get lastSeen => neighbor?.lastSeen ?? contact?.lastSeenAt;

  /// Hop count from the neighbor observation, or null if not observed.
  int? get hopEstimate => neighbor?.hopEstimate;

  /// Whether a route is available (node is currently observed).
  bool get hasRoute => neighbor != null;
}

final class NodeDetailsView {
  const NodeDetailsView({
    required this.nodeId,
    required this.loaded,
    required this.offline,
    this.model,
    this.error,
  });

  final String nodeId;

  /// Whether the contact list and neighbor stream have resolved.
  final bool loaded;

  /// Whether the mesh engine is not running.
  final bool offline;

  /// The aggregated node, or `null` when nothing is known about it.
  final NodeDetailsModel? model;

  /// Stream failure, when the details could not load.
  final Object? error;
}

/// Renders one node's details; owns the node-level actions.
///
/// Every action delegates to an existing controller or use case: trust
/// changes and removal go through the contacts controller, conversation
/// opening through the channel repository (idempotent per peer), and
/// verification codes through the derive use case.
final nodeDetailsViewProvider = AsyncNotifierProvider.family
    .autoDispose<NodeDetailsController, NodeDetailsView, String>(
      NodeDetailsController.new,
    );

final class NodeDetailsController extends AsyncNotifier<NodeDetailsView> {
  NodeDetailsController(this.arg);

  /// The node id this controller renders.
  final String arg;

  String get _nodeId => arg;

  @override
  Future<NodeDetailsView> build() async {
    final contactsAsync = ref.watch(trustContactsControllerProvider);
    final neighborsAsync = ref.watch(meshNeighborsProvider);
    final meshAsync = ref.watch(meshStateProvider);

    final engineState = meshAsync.value?.value;
    final offline =
        engineState != null && engineState != MeshEngineState.running;

    final neighbors = <MeshNeighbor>[];
    if (neighborsAsync.hasError) {
      return NodeDetailsView(
        nodeId: _nodeId,
        loaded: true,
        offline: offline,
        error: neighborsAsync.error,
      );
    }
    final neighborsResult = neighborsAsync.value;
    if (neighborsResult != null && neighborsResult.isErr) {
      return NodeDetailsView(
        nodeId: _nodeId,
        loaded: true,
        offline: offline,
        error: neighborsResult.failure,
      );
    }
    if (neighborsResult != null) neighbors.addAll(neighborsResult.value!);

    if (contactsAsync.hasError) {
      return NodeDetailsView(
        nodeId: _nodeId,
        loaded: true,
        offline: offline,
        error: contactsAsync.error,
      );
    }

    final contacts = contactsAsync.value ?? const <TrustContact>[];
    TrustContact? contact;
    for (final candidate in contacts) {
      if (candidate.nodeId.value == _nodeId) {
        contact = candidate;
        break;
      }
    }
    MeshNeighbor? neighbor;
    for (final candidate in neighbors) {
      if (candidate.nodeId == _nodeId) {
        neighbor = candidate;
        break;
      }
    }

    return NodeDetailsView(
      nodeId: _nodeId,
      loaded: true,
      offline: offline,
      model: NodeDetailsModel(
        nodeId: _nodeId,
        contact: contact,
        neighbor: neighbor,
      ),
    );
  }

  /// Re-runs the registry streams (error recovery).
  void retry() {
    ref.invalidate(trustContactsControllerProvider);
    ref.invalidate(meshNeighborsProvider);
  }

  /// Applies a new trust posture through the contacts controller.
  Future<bool> setTrustLevel(TrustLevel level) async {
    final controller = ref.read(trustContactsControllerProvider.notifier);
    await controller.setTrustLevel(_nodeId, level);
    return true;
  }

  /// Removes the node from the contact list.
  Future<bool> removeContact() async {
    final controller = ref.read(trustContactsControllerProvider.notifier);
    await controller.remove(_nodeId);
    return true;
  }

  /// Opens (or creates) the private conversation with this node. Returns
  /// the channel id, or `null` on failure.
  Future<String?> openConversation() async {
    final name = state.value?.model?.name;
    final result = await ref
        .read(channelRepositoryProvider)
        .create(
          CreateChannelParams(
            type: ChannelType.private,
            peer: _nodeId,
            title: name,
          ),
        );
    return result.isOk ? result.value!.channelId : null;
  }

  /// Derives the out-of-band verification code for this node's identity.
  Future<Result<VerificationCode>> verificationCode() {
    final fingerprint = state.value?.model?.fingerprint;
    if (fingerprint == null) {
      return Future.value(
        const Err(IdentityFailure(code: 'no_fingerprint', message: '')),
      );
    }
    return ref
        .read(deriveVerificationCodeProvider)
        .call(DeriveVerificationCodeParams(fingerprint));
  }
}
