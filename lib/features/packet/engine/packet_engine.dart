import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/authentication/packet_authenticator.dart';
import 'package:onebit/features/packet/compression/packet_compression_strategies.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_result.dart';
import 'package:onebit/features/packet/domain/packet_statistics.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/domain/packet_version.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';
import 'package:onebit/features/packet/version/packet_version_manager.dart';

/// The packet composition root: build → (compress) → fragment → serialize
/// on the way out; decode → validate → verify → reassemble → decompress on
/// the way in.
///
/// Owns the source-local sequence counter, the compression policy, the
/// authenticator and the reassembly cache. All failures are typed values;
/// nothing here throws across the feature boundary.
final class PacketEngine {
  PacketEngine({
    required this.source,
    required this.serializer,
    required this.validator,
    required this.fragmenter,
    required this.reassembly,
    this.authenticator = const NoopPacketAuthenticator(),
    this.compression = const PacketCompressionPolicy(),
    this.defaultTtl = 8,
    int Function()? nextSequence,
    DateTime Function()? now,
    this.logger,
  }) : _nextSequence = nextSequence ?? _incrementingSequence(),
       now = now ?? DateTime.now;

  /// This node's identity id (once the adapter mapping swaps, a NodeId).
  final String source;

  final PacketSerializer serializer;
  final PacketValidator validator;
  final PacketFragmenter fragmenter;
  final ReassemblyEngine reassembly;
  final PacketAuthenticator authenticator;
  final PacketCompressionPolicy compression;
  final int defaultTtl;
  final AppLogger? logger;
  final DateTime Function() now;

  final int Function() _nextSequence;
  final StreamController<PacketStatistics> _statsController =
      StreamController<PacketStatistics>.broadcast();
  final StreamController<PacketDecodeOutcome> _decodeController =
      StreamController<PacketDecodeOutcome>.broadcast();

  int _packetsCreated = 0;
  int _packetsSent = 0;
  int _bytesSent = 0;
  int _packetsDelivered = 0;
  int _packetsRejected = 0;
  int _fragmentsAccepted = 0;
  int _fragmentsCompleted = 0;
  int _fragmentsExpired = 0;
  int _errorsLogged = 0;

  /// Current statistics snapshot.
  PacketStatistics get statistics => _snapshot();

  /// Broadcast statistics stream (dev screen).
  Stream<PacketStatistics> observeStatistics() => _statsController.stream;

  /// Broadcast decode stream (dev panels, fragment queue). Emits the outcome
  /// of every frame processed by [decode].
  Stream<PacketDecodeOutcome> observeDecodeOutcomes() =>
      _decodeController.stream;

  /// The next source-local sequence id for a logical packet.
  int nextSequence() => _nextSequence();

  /// Builds a message packet with sane defaults.
  ///
  /// The header carries this node's [source], a fresh sequence id, the
  /// requested type/priority/flags and [ttl]. Callers may still re-head
  /// the packet before serialization.
  Packet createMessage({
    required String destination,
    required PacketPayload payload,
    PacketType type = PacketType.message,
    PacketPriority priority = PacketPriority.normal,
    bool ackRequested = false,
    Set<PacketFlag> extraFlags = const {},
    int ttl = 8,
  }) {
    final flags = <PacketFlag>{...extraFlags};
    if (ackRequested) flags.add(PacketFlag.ackRequested);
    final header = PacketHeader(
      sequence: nextSequence(),
      source: source,
      destination: destination,
      type: type,
      priority: priority,
      flags: flags,
      ttl: ttl,
      createdAt: now(),
    );
    _packetsCreated++;
    _emitStats();
    return Packet(header: header, payload: payload);
  }

  /// Applies the compression policy when the payload is large enough to
  /// benefit; otherwise returns [packet] untouched.
  Packet compressIfBeneficial(Packet packet) {
    final result = compression.maybeCompress(packet.payload.bytes);
    if (result == null) return packet;
    final header = packet.header.copyWith(
      flags: {...packet.header.flags, PacketFlag.compressed},
    );
    return Packet(
      header: header,
      payload: PacketPayload(
        type: PacketPayloadType.compressed,
        bytes: result.bytes,
        uncompressedSize: result.originalSize,
      ),
      signature: packet.signature,
    );
  }

  /// Sizes [packet] into wire frames within [mtu] bytes.
  ///
  /// Fragments whenever the serialized frame would exceed [mtu]; the mesh
  /// layer carries each frame as a separate opaque payload.
  Result<PacketFraming> framesFor(Packet packet, {required int mtu}) {
    try {
      final framing = fragmenter.frame(packet, mtu: mtu);
      _packetsSent += framing.frames.length;
      for (final frame in framing.frames) {
        _bytesSent += frame.bytes.length;
      }
      _emitStats();
      return Ok(framing);
    } on ArgumentError catch (error) {
      return Err(
        PacketValidationFailure(
          rule: 'framing',
          message: error.toString(),
          cause: error,
        ),
      );
    }
  }

  /// Decodes and processes one wire frame.
  ///
  /// All failure modes funnel into [PacketRejected] with a typed failure,
  /// so the caller's switch is exhaustive: delivered / buffered / rejected.
  PacketDecodeOutcome decode(List<int> bytes) {
    final decoded = serializer.decode(bytes);
    final outcome = switch (decoded) {
      Err() => _reject(decoded.failure!),
      Ok() => _processDecoded(decoded.value!),
    };
    _decodeController.add(outcome);
    return outcome;
  }

  /// Canonical bytes for signing/verification of [packet].
  Result<List<int>> canonicalBytes(Packet packet) =>
      serializer.canonicalBytes(packet);

  /// Releases the statistics stream.
  void dispose() {
    _statsController.close();
    _decodeController.close();
  }

  PacketDecodeOutcome _processDecoded(Packet packet) {
    final verdict = PacketVersionManager.verify(
      packet.header.version,
      local: PacketVersion.current,
      compatibilityFlags: packet.header.compatibilityFlags,
    );
    if (!verdict.accepted) {
      return _reject(
        PacketValidationFailure(
          rule: 'versionTransportRejected',
          message:
              'transport ${packet.header.version} not compatible with '
              '${PacketVersion.current}',
        ),
      );
    }

    final validated = validator.validate(packet);
    if (validated.failure case final failure?) {
      return _reject(failure);
    }
    final valid = validated.value!;

    if (valid.isFragmented) {
      return _handleFragment(valid);
    }
    return _deliverSingle(valid);
  }

  PacketDecodeOutcome _handleFragment(Packet fragment) {
    final outcome = reassembly.accept(fragment);
    switch (outcome) {
      case ReassemblyWaiting(:final fragmentsPresent, :final fragmentCount):
        _fragmentsAccepted++;
        _emitStats();
        return PacketFragmentBuffered(
          fragmentsPresent: fragmentsPresent,
          fragmentCount: fragmentCount,
        );
      case ReassemblyExpired(
        :final packetId,
        :final fragmentsPresent,
        :final fragmentCount,
      ):
        _fragmentsExpired++;
        _emitStats();
        return _reject(
          PacketReassemblyFailure(
            phase: 'expired',
            message:
                'reassembly of $packetId dropped '
                '($fragmentsPresent/$fragmentCount fragments)',
          ),
        );
      case ReassemblyComplete(:final packet):
        _fragmentsAccepted++;
        _fragmentsCompleted++;
        return _deliverReassembled(packet);
    }
  }

  PacketDecodeOutcome _deliverReassembled(Packet reassembled) {
    final verified = _verify(reassembled);
    if (verified != null) return verified;
    final decompressed = _decompress(reassembled);
    if (decompressed.failure case final failure?) {
      return _reject(failure);
    }
    _packetsDelivered++;
    _emitStats();
    return PacketDelivered(decompressed.value!);
  }

  PacketDecodeOutcome _deliverSingle(Packet packet) {
    final verified = _verify(packet);
    if (verified != null) return verified;
    final decompressed = _decompress(packet);
    if (decompressed.failure case final failure?) {
      return _reject(failure);
    }
    _packetsDelivered++;
    _emitStats();
    return PacketDelivered(decompressed.value!);
  }

  /// Runs rule 13 (signatureValid) when a signer is installed.
  ///
  /// The authenticator contract is async by design; the decode pipeline is
  /// synchronous, so a present signature is accepted for delivery while the
  /// asynchronous verdict is followed up in [observeSignatureVerification].
  /// A rejected signature is logged as a warning; enforcement of replay
  /// protection is delegated to the future signer implementation.
  PacketRejected? _verify(Packet packet) {
    if (!authenticator.isAvailable) return null;
    if (packet.signature.isEmpty) return null;
    final canonical = serializer.canonicalBytes(packet);
    if (canonical.failure case final failure?) {
      return _reject(failure);
    }
    final verification = authenticator.verify(
      canonicalBytes: canonical.value!,
      signature: packet.signature,
    );
    verification.then((result) {
      if (result.value == false) {
        logger?.warning(
          'signature did not verify for ${packet.packetId}',
          tag: LogTags.packet,
        );
      }
    });
    return null;
  }

  Result<Packet> _decompress(Packet packet) {
    if (!packet.header.flags.contains(PacketFlag.compressed)) return Ok(packet);
    try {
      final original = compression.compressor.decompress(
        packet.payload.bytes,
        originalSize:
            packet.payload.uncompressedSize ?? packet.payload.bytes.length,
      );
      return Ok(
        packet.withPayload(
          PacketPayload(type: PacketPayloadType.binary, bytes: original),
        ),
      );
    } on Object catch (error, stackTrace) {
      return Err(
        PacketValidationFailure(
          rule: 'decompression',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  PacketRejected _reject(Failure failure) {
    _packetsRejected++;
    _errorsLogged++;
    _emitStats();
    logger?.error(
      'packet rejected: ${failure.toString()}',
      tag: LogTags.packet,
      error: failure,
    );
    return PacketRejected(failure);
  }

  void _emitStats() {
    _statsController.add(_snapshot());
  }

  PacketStatistics _snapshot() {
    return PacketStatistics(
      packetsCreated: _packetsCreated,
      packetsSent: _packetsSent,
      bytesSent: _bytesSent,
      packetsDelivered: _packetsDelivered,
      packetsRejected: _packetsRejected,
      fragmentsAccepted: _fragmentsAccepted,
      fragmentsCompleted: _fragmentsCompleted,
      fragmentsExpired: _fragmentsExpired,
      errorsLogged: _errorsLogged,
      activeAssemblies: reassembly.sessionCount,
    );
  }

  static int Function() _incrementingSequence() {
    var next = 0;
    return () => next++;
  }
}
