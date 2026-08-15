import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

import 'app_navigation_support.dart';

/// The provider container behind the mounted app.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(OneBitApp)));

/// Mounts the full app (in-memory database, fake identity) and settles.
Future<ProviderContainer> pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(oneBitApp(identity: testIdentity()));
  await tester.pumpAndSettle();
  return containerOf(tester);
}

/// Creates a private channel with [peer] and [title], returning its id.
Future<String> seedChannel(
  ProviderContainer container, {
  required String peer,
  required String title,
}) async {
  final result = await container
      .read(channelRepositoryProvider)
      .create(
        CreateChannelParams(
          type: ChannelType.private,
          peer: peer,
          title: title,
        ),
      );
  return result.value!.channelId;
}

/// Sends an outbound text through the messaging engine (stamped local).
Future<Message> seedOutbound(
  ProviderContainer container,
  String channelId,
  String body,
) async {
  final result = await container
      .read(messagingEngineProvider)
      .sendText(channelId, body);
  return result.value!;
}

/// Inserts an inbound message directly into the store (foreign sender).
Future<Message> seedInbound(
  ProviderContainer container,
  String channelId, {
  required String sender,
  required String body,
  MessageStatus status = MessageStatus.delivered,
}) async {
  final message = Message(
    messageId: 'in-$sender-${body.hashCode}',
    channelId: channelId,
    sender: sender,
    timestamp: DateTime.utc(2026, 1, 1, 12),
    body: body,
    status: status,
    sequence: 1,
  );
  await container.read(messageRepositoryProvider).insert(message);
  return message;
}

/// Bumps the unread counter of a channel without touching its stream.
Future<void> seedUnread(
  ProviderContainer container,
  String channelId, {
  int count = 1,
}) async {
  await container
      .read(channelRepositoryProvider)
      .bumpActivity(channelId, unreadDelta: count);
}

/// Adds a trusted contact to the local registry.
Future<void> seedContact(
  ProviderContainer container, {
  required String nodeId,
  String displayName = 'Alice',
  TrustLevel trustLevel = TrustLevel.known,
}) async {
  final fingerprintHex = List.filled(32, 'ab').join();
  await container
      .read(trustContactRepositoryProvider)
      .upsert(
        TrustContact(
          nodeId: NodeId.parse(nodeId),
          displayName: displayName,
          fingerprintHex: fingerprintHex,
          ed25519PublicKey: Uint8List(32),
          x25519PublicKey: Uint8List(32),
          trustLevel: trustLevel,
          firstSeenAt: DateTime.utc(2026, 1, 1),
          lastSeenAt: DateTime.utc(2026, 1, 2),
        ),
      );
}
