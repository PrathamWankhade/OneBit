import 'package:flutter/foundation.dart';

/// Ordering direction for paged reads.
enum PageOrder { ascending, descending }

/// A single page of results with enough context for the next request.
@immutable
final class Page<T> {
  const Page({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  /// Rows in this page.
  final List<T> items;

  /// Offset this page was fetched at.
  final int offset;

  /// Requested page size.
  final int limit;

  /// Whether more rows exist beyond this page.
  final bool hasMore;

  int get itemCount => items.length;

  /// Maps rows without changing paging metadata.
  Page<U> map<U>(U Function(T value) transform) => Page<U>(
    items: items.map(transform).toList(growable: false),
    offset: offset,
    limit: limit,
    hasMore: hasMore,
  );

  /// Offset to request for the next page.
  int get nextOffset => offset + itemCount;
}
