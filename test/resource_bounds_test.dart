import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/conversations/models/attachment_prep.dart';
import 'package:onebit/features/conversations/models/reply_tag.dart';
import 'package:onebit/features/crypto/replay_protection.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/protocol/attachment_segment.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/reliable/reliable_transfer_manager.dart';
import 'package:onebit/features/routing/routing_limits.dart';

/// I9.16.a — the bounds audit.
///
/// Every number that keeps memory, radio time, or the queue finite
/// is pinned here with the reason it is that number. Changing one is
/// a design decision, so it should fail a test that names what the
/// bound was for — not slip through a diff unnoticed.
///
/// The relationships matter more than the values: a bound that
/// drifts out of relationship with what it protects is worse than
/// no bound at all.
void main() {
  group('outbox and seen-set', () {
    test('a maximum attachment fits an empty outbox', () {
      // The queue cap was sized for exactly this: [SegTag.maxSlices]
      // rows plus the manifest, checked before the insert loop, so a
      // whole file never strands half-written (I9.8.a).
      expect(
        MessageTransport.defaultMaxQueuedMessages,
        greaterThanOrEqualTo(SegTag.maxSlices + 1),
      );
    });

    test('the seen-set outnumbers the outbox it protects', () {
      // A few thousand recent wire ids — years of traffic at this
      // app's pace — shed oldest-first (I9.12.a).
      expect(AppDatabase.defaultMaxSeenIds, 4096);
      expect(
        AppDatabase.defaultMaxSeenIds,
        greaterThan(MessageTransport.defaultMaxQueuedMessages),
      );
    });

    test('held receipts are bounded in count and patience', () {
      expect(MessageTransport.defaultMaxHeldReceipts, 32);
      expect(MessageTransport.defaultMaxReceiptAttempts, 4);
    });
  });

  group('packets, frames, envelopes', () {
    test('the packet budget adds up', () {
      expect(PacketConstants.headerSize, 5);
      expect(PacketConstants.maxPacketSize, 260);
      expect(
        PacketConstants.maxPayloadSize,
        PacketConstants.maxPacketSize - PacketConstants.headerSize,
      );
    });

    test('the envelope budget adds up', () {
      expect(maxMessagePayloadSize, 4096);
      expect(
        maxEncodedEnvelopeSize,
        envelopeHeaderSize + maxMessagePayloadSize,
      );
    });

    test('one maximum frame fits inside one maximum envelope', () {
      // A chat message is one frame; an attachment is many. Either
      // way the envelope swallows the largest legal single frame, so
      // there is only ever one size regime to reason about.
      expect(
        MessageCodec.maxContentLength,
        lessThanOrEqualTo(maxMessagePayloadSize),
      );
      expect(MessageCodec.minSize, 12);
    });

    test('the chunk header is small next to the payload it opens', () {
      expect(chunkHeaderSize, 5);
      expect(chunkHeaderSize, lessThan(PacketConstants.maxPayloadSize));
    });

    test('identity-sized fields fit their lanes', () {
      expect(peerIdByteSize, 32);
      expect(messageIdByteSize, 16);
    });

    test('relays stop at eight hops', () {
      // Enough for a room-sized gathering of rooms; small enough
      // that a loop dies young and a flood stays a trickle.
      expect(maxEnvelopeHops, 8);
    });
  });

  group('routing keeps its own books', () {
    test('the table bounds hold their values', () {
      expect(RoutingLimits.maxNeighbors, 64);
      expect(RoutingLimits.maxTopologySources, 256);
      expect(RoutingLimits.maxNeighborsPerSource, 64);
      expect(RoutingLimits.maxRouteDestinations, 512);
      expect(RoutingLimits.maxRoutesPerDestination, 8);
      // One byte, as the wire format demands.
      expect(RoutingLimits.maxRouteMetric, 255);
    });

    test('discovery stays bounded no matter the graph', () {
      expect(RoutingLimits.maxDiscoveryDepth, 64);
      expect(RoutingLimits.maxDiscoveryVisited, 1024);
      // A visited-set smaller than one source's full neighbor list
      // would stall discovery on its first advertisement.
      expect(
        RoutingLimits.maxDiscoveryVisited,
        greaterThanOrEqualTo(RoutingLimits.maxNeighborsPerSource),
      );
    });

    test('recovery and diagnostics do not grow without end', () {
      expect(RoutingLimits.maxRecoveryStates, 128);
      expect(RoutingLimits.maxRecoveryAttempts, 5);
      expect(RoutingLimits.maxDiagnosticEvents, 200);
      expect(RoutingLimits.maxSecurityEventLog, 200);
    });

    test('an advertisement fits the lane it travels', () {
      expect(RoutingLimits.maxAdvertisementPayloadSize, 4096);
      // The BLE advertisement is the tightest lane of all: the stack
      // allows 31 bytes and this protocol uses 24 of them.
      expect(BleIdentityProtocol.maxAdvertPayloadLength, 24);
      expect(
        BleIdentityProtocol.maxAdvertPayloadLength,
        lessThanOrEqualTo(31),
      );
    });
  });

  group('small bounds elsewhere', () {
    test('the reliable layer remembers a bounded recent past', () {
      const config = ReliableTransferConfig();
      expect(config.duplicateCacheSize, 64);
      expect(config.maxAttempts, 3);
      expect(config.ackTimeoutMs, 5000);
    });

    test('the replay window is a window, not a ledger', () {
      expect(ReplayWindow().windowSize, 64);
    });

    test('what the user can attach or quote is bounded', () {
      expect(AttachmentPrep.maxImageBytes, 120 * 1024);
      expect(ReplyTag.maxQuoteLength, 200);
    });

    test('an identity import cannot be a payload attack', () {
      expect(kMaxImportPayloadSize, 8192);
    });
  });
}
