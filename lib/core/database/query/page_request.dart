import 'package:flutter/foundation.dart';

import '../models/page.dart' show PageOrder;

/// A paged read request: [offset] + [limit] with a stable [order].
@immutable
final class PageRequest {
  const PageRequest({
    this.offset = 0,
    this.limit = defaultLimit,
    this.order = PageOrder.descending,
  });

  static const int defaultLimit = 50;
  static const int maxLimit = 500;

  final int offset;
  final int limit;
  final PageOrder order;

  PageRequest next() =>
      PageRequest(offset: offset + limit, limit: limit, order: order);
}
