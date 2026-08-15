# Riverpod — Provider Surface (no UI)

The messaging module exposes providers from `features/messaging/providers.dart`
(a single composition-root file, mirroring the DTN feature's
`dtn_providers.dart`). Providers are the **only** connection between the
domain engine and the future Flutter UI.

## Provider list

```dart
// Engine + repositories
final Provider<MessagingEngine> messagingEngineProvider;      // lifecycle wiring
final Provider<ChannelRepository> channelRepositoryProvider;
final Provider<MessageRepository> messageRepositoryProvider;
final Provider<DraftRepository> draftRepositoryProvider;
final Provider<ReceiptRepository> receiptRepositoryProvider;
final Provider<SearchRepository> searchRepositoryProvider;
final Provider<NotificationRepository> notificationRepositoryProvider;

// Streams the UI will consume
final StreamProvider<MessagePage> channelTimelineProvider;     // family(channelId)
final StreamProvider<ConversationSummary> conversationListProvider; // + sort
final StreamProvider<Draft> channelDraftProvider;              // family(channelId)
final StreamProvider<NodeUnread> unreadCountsProvider;
final StreamProvider<TypingState> typingStatesProvider;        // family(channelId)
final StreamProvider<NotificationEvent> notificationStreamProvider;
final FutureProvider<Channel> channelProvider;                 // family(channelId)
```

## Wiring rules

1. `messagingEngineProvider` watches `dtnEngineProvider` (DTN repository),
   `databaseProvider`, `identityRepositoryProvider` and the logger; starts
   the engine lazily on first read (`onDispose` stops it).
2. All repository providers derive from `repositoryFactoryProvider` /
   `messagingDaoProvider` so tests can override a single seam.
3. No provider imports Flutter UI classes. Return types are domain models.
4. `typingStatesProvider` and `notificationStreamProvider` are `StreamProvider`s
   that lazily subscribe to the engine's buses and cancel on dispose.

## Test overrides

Tests construct a `ProviderContainer` with:

```dart
container.read(messagingEngineProvider.overrideWith((ref) => engine));
```

or override `dtnGatewayProvider` with a fake, exercising the real engine
pipeline through the provider surface.