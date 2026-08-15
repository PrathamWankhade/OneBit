import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/messaging/domain/use_cases/cancel_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/delete_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/edit_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/forward_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/generate_read_receipt.dart';
import 'package:onebit/features/messaging/domain/use_cases/generate_receipt.dart';
import 'package:onebit/features/messaging/domain/use_cases/load_draft.dart';
import 'package:onebit/features/messaging/domain/use_cases/mark_channel_read.dart';
import 'package:onebit/features/messaging/domain/use_cases/reply_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/retry_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/save_draft.dart';
import 'package:onebit/features/messaging/domain/use_cases/send_message.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

/// Use-case providers for message actions.
final Provider<SendMessage> sendMessageProvider = Provider<SendMessage>(
  (ref) => SendMessage(ref.watch(messagingEngineProvider)),
);

final Provider<ReplyMessage> replyMessageProvider = Provider<ReplyMessage>(
  (ref) => ReplyMessage(ref.watch(messagingEngineProvider)),
);

final Provider<ForwardMessage> forwardMessageProvider =
    Provider<ForwardMessage>(
      (ref) => ForwardMessage(ref.watch(messagingEngineProvider)),
    );

final Provider<EditMessage> editMessageProvider = Provider<EditMessage>(
  (ref) => EditMessage(ref.watch(messagingEngineProvider)),
);

final Provider<DeleteMessage> deleteMessageProvider = Provider<DeleteMessage>(
  (ref) => DeleteMessage(ref.watch(messagingEngineProvider)),
);

final Provider<RetryMessage> retryMessageProvider = Provider<RetryMessage>(
  (ref) => RetryMessage(ref.watch(messagingEngineProvider)),
);

final Provider<CancelMessage> cancelMessageProvider = Provider<CancelMessage>(
  (ref) => CancelMessage(ref.watch(messagingEngineProvider)),
);

final Provider<MarkChannelRead> markChannelReadProvider =
    Provider<MarkChannelRead>(
      (ref) => MarkChannelRead(ref.watch(messagingEngineProvider)),
    );

final Provider<GenerateReceipt> generateReceiptProvider =
    Provider<GenerateReceipt>(
      (ref) => GenerateReceipt(ref.watch(messagingEngineProvider)),
    );

final Provider<GenerateReadReceipt> generateReadReceiptProvider =
    Provider<GenerateReadReceipt>(
      (ref) => GenerateReadReceipt(ref.watch(messagingEngineProvider)),
    );

final Provider<LoadDraft> loadDraftProvider = Provider<LoadDraft>(
  (ref) => LoadDraft(ref.watch(messagingEngineProvider)),
);

final Provider<SaveDraft> saveDraftProvider = Provider<SaveDraft>(
  (ref) => SaveDraft(ref.watch(messagingEngineProvider)),
);
