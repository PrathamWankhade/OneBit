import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import '../notifications/notification.dart';
import '../notifications/notification_repository.dart';

/// Publishes internal notification events into the durable log.
///
/// This is the in-app notification bus: it does **not** render Android
/// notifications — it is the source of truth the UI layer consumes later
/// via [NotificationRepository.watch].
final class NotificationEngine {
  NotificationEngine({required this._repository, required this._logger});

  final NotificationRepository _repository;
  final AppLogger _logger;

  static const _tag = LogTags.messaging;

  /// Appends an event to the log. Never throws.
  Future<Result<NotificationEvent>> emit(NotificationEvent event) async {
    final result = await _repository.push(event);
    if (result is Ok<NotificationEvent>) {
      _logger.debug('notification:${event.kind.name} emitted', tag: _tag);
    } else {
      _logger.warning('notification push failed: ${result.failure}', tag: _tag);
    }
    return result;
  }
}
