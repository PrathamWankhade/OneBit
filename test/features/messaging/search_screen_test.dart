import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/domain/search/search_repository.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/features/messaging/presentation/search_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_search_field.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The message search screen: query, debounced results, clear, and the
/// loading/error/empty state machine.
void main() {
  Future<void> pumpSearch(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.search);
    await tester.pumpAndSettle();
  }

  testWidgets('initial state invites a query', (tester) async {
    final container = await pumpShell(tester);

    await pumpSearch(tester, container);

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search your messages'), findsOneWidget);
    expect(find.text('Find any text in your conversations.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a query returns matching messages and clears again', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'meet for coffee tomorrow');
    await seedOutbound(container, channelId, 'the ship departs at noon');
    await tester.pumpAndSettle();

    await pumpSearch(tester, container);

    await tester.enterText(find.byType(OneBitSearchField), 'coffee');
    await tester.pump(const Duration(milliseconds: 100));
    // Debounce window: still loading.
    expect(find.byType(OneBitLoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // The result tile shows the FTS snippet, which wraps the match in
    // '⋯' markers; scope the finder to the result rows (the search field
    // also holds the query text).
    expect(
      find.descendant(
        of: find.byType(OneBitListItem),
        matching: find.textContaining('coffee'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ship departs'), findsNothing);

    // Clear restores the invitation state.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Search your messages'), findsOneWidget);
    expect(find.byType(OneBitEmptyState), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a miss reports no results', (tester) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'meet for coffee tomorrow');
    await tester.pumpAndSettle();

    await pumpSearch(tester, container);

    await tester.enterText(find.byType(OneBitSearchField), 'giraffe');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No results for "giraffe"'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('tapping a result deep-links into the channel', (tester) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'meet for coffee tomorrow');
    await tester.pumpAndSettle();

    await pumpSearch(tester, container);

    await tester.enterText(find.byType(OneBitSearchField), 'coffee');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(OneBitListItem),
        matching: find.textContaining('coffee'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChannelDetailsScreen), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('search failures surface the error state with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          searchRepositoryProvider.overrideWithValue(
            _FailingSearchRepository(),
          ),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.search);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(OneBitSearchField), 'coffee');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(OneBitErrorState), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await disposeApp(tester);
  });
}

/// A search repository that always fails (error-state coverage).
final class _FailingSearchRepository implements SearchRepository {
  @override
  Future<Result<SearchPage<MessageSearchResult>>> searchMessages(
    MessageSearchQuery query, {
    int offset = 0,
    int limit = 50,
  }) async => const Err(StorageFailure(message: 'index unavailable'));

  @override
  Future<Result<List<ConversationSummary>>> searchChannels(
    String terms, {
    int limit = 25,
  }) async => const Err(StorageFailure(message: 'index unavailable'));

  @override
  Future<Result<List<ConversationSummary>>> searchChannelsByNodeName(
    String terms, {
    int limit = 25,
  }) async => const Err(StorageFailure(message: 'index unavailable'));

  @override
  Future<Result<int>> rebuildIndex() async =>
      const Err(StorageFailure(message: 'index unavailable'));

  @override
  Future<Result<void>> indexMessage({
    required String messageId,
    required String channelId,
    required String body,
    required String sender,
    required String nodeName,
    required String type,
    required int timestampMs,
  }) async => const Err(StorageFailure(message: 'index unavailable'));

  @override
  Future<Result<void>> removeFromIndex(String messageId) async =>
      const Err(StorageFailure(message: 'index unavailable'));
}
