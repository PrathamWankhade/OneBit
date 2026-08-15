import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

/// Presentation state of the message search screen.
final NotifierProvider<MessageSearchController, MessageSearchView>
messageSearchProvider =
    NotifierProvider<MessageSearchController, MessageSearchView>(
      MessageSearchController.new,
    );

final class MessageSearchView {
  const MessageSearchView({
    this.query = '',
    this.loading = false,
    this.loadingMore = false,
    this.results = const [],
    this.hasMore = false,
    this.error,
  });

  /// Current query text (debounced before execution).
  final String query;

  /// Whether the debounce window or the search call is in flight.
  final bool loading;

  /// Whether an older page is being fetched.
  final bool loadingMore;

  /// Matched messages (newest rank first).
  final List<MessageSearchResult> results;

  /// Whether more results exist past the loaded page.
  final bool hasMore;

  /// Search failure, when the last run could not complete.
  final Object? error;

  bool get hasQuery => query.trim().isNotEmpty;

  MessageSearchView copyWith({
    String? query,
    bool? loading,
    bool? loadingMore,
    List<MessageSearchResult>? results,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) => MessageSearchView(
    query: query ?? this.query,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    results: results ?? this.results,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Debounced local full-text search over the engine's search façade.
final class MessageSearchController extends Notifier<MessageSearchView> {
  static const Duration _debounce = Duration(milliseconds: 300);
  static const int _pageSize = 50;

  Timer? _debounceTimer;
  String _activeQuery = '';
  int _offset = 0;

  @override
  MessageSearchView build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const MessageSearchView();
  }

  /// Applies a new query; execution is debounced so typing stays cheap.
  void onQueryChanged(String value) {
    _debounceTimer?.cancel();
    state = state.copyWith(query: value, clearError: true);
    if (value.trim().isEmpty) {
      _activeQuery = '';
      _offset = 0;
      state = const MessageSearchView();
      return;
    }
    state = state.copyWith(loading: true);
    _debounceTimer = Timer(_debounce, () => unawaited(_run(value.trim())));
  }

  /// Fetches the next page of the active query.
  Future<void> loadMore() async {
    final query = _activeQuery;
    if (query.isEmpty || state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    final result = await ref
        .read(messagingEngineProvider)
        .searchMessages(
          MessageSearchQuery(terms: query),
          offset: _offset,
          limit: _pageSize,
        );
    if (!ref.mounted || query != _activeQuery) return;
    if (result.isErr) {
      state = state.copyWith(loadingMore: false, error: result.failure);
      return;
    }
    final page = result.value!;
    _offset = page.offset + page.items.length;
    final seen = state.results.map((r) => r.messageId).toSet();
    state = state.copyWith(
      loadingMore: false,
      hasMore: page.hasMore,
      results: [
        ...state.results,
        ...page.items.where((r) => !r.deleted && seen.add(r.messageId)),
      ],
    );
  }

  /// Re-runs the active query (error recovery).
  void retry() {
    if (_activeQuery.isEmpty) return;
    unawaited(_run(_activeQuery));
  }

  /// Clears the query and every result.
  void clear() {
    _debounceTimer?.cancel();
    _activeQuery = '';
    _offset = 0;
    state = const MessageSearchView();
  }

  Future<void> _run(String query) async {
    _activeQuery = query;
    _offset = 0;
    final result = await ref
        .read(messagingEngineProvider)
        .searchMessages(
          MessageSearchQuery(terms: query),
          offset: 0,
          limit: _pageSize,
        );
    if (!ref.mounted || query != _activeQuery) return;
    if (result.isErr) {
      state = state.copyWith(loading: false, error: result.failure);
      return;
    }
    final page = result.value!;
    _offset = page.offset + page.items.length;
    state = state.copyWith(
      loading: false,
      hasMore: page.hasMore,
      results: page.items.where((r) => !r.deleted).toList(),
    );
  }
}
