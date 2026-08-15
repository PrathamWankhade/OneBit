import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_state.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';

/// Result of the last `send` attempt, for the developer panels.
final class PacketSendView {
  const PacketSendView({this.lastResult, this.lastError});

  /// Human-readable success summary (frames sent etc.).
  final String? lastResult;

  /// The typed failure of the last attempt, when it failed.
  final String? lastError;

  bool get isIdle => lastResult == null && lastError == null;
}

/// Drives outbound sends through the packet repository.
///
/// The dev screen keeps the payload in a local text field; the controller
/// turns it into a typed packet send and mirrors the outcome.
final class PacketSendController extends Notifier<PacketSendView> {
  @override
  PacketSendView build() => const PacketSendView();

  /// Sends [text] to [destination] as a [type]/[priority] packet.
  Future<void> send({
    required String destination,
    required String text,
    PacketType type = PacketType.message,
    PacketPriority priority = PacketPriority.normal,
    bool ackRequested = false,
  }) async {
    final result = await ref
        .read(packetRepositoryProvider)
        .send(
          destination: destination,
          payload: text.codeUnits,
          type: type,
          priority: priority,
          ackRequested: ackRequested,
        );
    state = result.isOk
        ? PacketSendView(
            lastResult:
                'sent to $destination: ${text.length} bytes '
                '(${type.name}/${priority.name})',
          )
        : PacketSendView(lastError: result.failure.toString());
  }
}

/// The send controller provider.
final NotifierProvider<PacketSendController, PacketSendView>
packetSendControllerProvider =
    NotifierProvider<PacketSendController, PacketSendView>(
      PacketSendController.new,
    );

/// Mirrors the engine's live fragment queue for the fragment-tab table.
final class PacketFragmentQueueController
    extends Notifier<List<ReassemblySession>> {
  @override
  List<ReassemblySession> build() {
    ref.listen(packetFragmentQueueProvider, (previous, next) {
      state = next.value ?? const [];
    });
    return ref.read(packetEngineProvider).reassembly.sessions;
  }

  /// Re-reads the engine's sessions directly (post-timeout refresh).
  void refresh() {
    state = ref.read(packetEngineProvider).reassembly.sessions;
  }
}

/// The fragment queue controller provider.
final NotifierProvider<PacketFragmentQueueController, List<ReassemblySession>>
packetFragmentQueueControllerProvider =
    NotifierProvider<PacketFragmentQueueController, List<ReassemblySession>>(
      PacketFragmentQueueController.new,
    );
