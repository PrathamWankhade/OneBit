import 'package:onebit/core/result/result.dart';

import '../messages/message_search_result.dart' show SearchPage;
import 'notification.dart';

/// Contract for the durable notification log.
abstract interface class NotificationRepository {
  /// Appends an event to the log.
  Future<Result<NotificationEvent>> push(NotificationEvent event);

  /// Streams new events as they are pushed.
  Stream<Result<NotificationEvent>> watch();

  /// Pages the log newest-first.
  Future<Result<SearchPage<NotificationEvent>>> page({
    int offset = 0,
    int limit = 50,
  });

  Future<Result<void>> clearAll();
}
