import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/providers/message_providers.dart';

void main() {
  group('MessageComposerState', () {
    test('default values', () {
      const state = MessageComposerState();
      expect(state.isCreating, isFalse);
      expect(state.lastError, isNull);
    });

    test('copyWith preserves values', () {
      const state = MessageComposerState(
        isCreating: true,
        lastError: 'test error',
      );
      final copied = state.copyWith();

      expect(copied.isCreating, isTrue);
      expect(copied.lastError, equals('test error'));
    });

    test('copyWith overrides values', () {
      const state = MessageComposerState(
        isCreating: true,
        lastError: 'test error',
      );
      final copied = state.copyWith(
        isCreating: false,
        lastError: () => 'new error',
      );

      expect(copied.isCreating, isFalse);
      expect(copied.lastError, equals('new error'));
    });

    test('copyWith clears error when null closure', () {
      const state = MessageComposerState(lastError: 'error');
      final copied = state.copyWith(lastError: () => null);

      expect(copied.lastError, isNull);
    });
  });

  group('outboundMessageStoreProvider', () {
    test('creates a new store', () {
      final container = ProviderContainer();
      final store = container.read(outboundMessageStoreProvider);

      expect(store, isA<OutboundMessageStore>());
      expect(store.isEmpty, isTrue);

      container.dispose();
    });

    test('provides same instance on repeated reads', () {
      final container = ProviderContainer();
      final store1 = container.read(outboundMessageStoreProvider);
      final store2 = container.read(outboundMessageStoreProvider);

      expect(identical(store1, store2), isTrue);

      container.dispose();
    });
  });

  group('MessageComposerNotifier', () {
    test('sendMessage succeeds and clears isCreating', () {
      final container = ProviderContainer(
        overrides: [
          localPeerIdForMessageProvider.overrideWithValue('aa' * 32),
          messageTransmissionServiceProvider.overrideWithValue(null),
        ],
      );

      final notifier = container.read(messageComposerProvider.notifier);
      notifier.sendMessage(
        destinationPeerId: 'bb' * 32,
        content: 'Hello',
      );

      final state = container.read(messageComposerProvider);
      expect(state.isCreating, isFalse);
      expect(state.lastError, isNull);

      container.dispose();
    });

    test('sendMessage failure sets error state', () {
      final container = ProviderContainer(
        overrides: [
          localPeerIdForMessageProvider.overrideWithValue('aa' * 32),
          messageTransmissionServiceProvider.overrideWithValue(null),
        ],
      );

      final notifier = container.read(messageComposerProvider.notifier);
      notifier.sendMessage(
        destinationPeerId: '',
        content: 'Hello',
      );

      final state = container.read(messageComposerProvider);
      expect(state.isCreating, isFalse);
      expect(state.lastError, isNotNull);

      container.dispose();
    });

    test('clearError resets error state', () {
      final container = ProviderContainer(
        overrides: [
          localPeerIdForMessageProvider.overrideWithValue('aa' * 32),
          messageTransmissionServiceProvider.overrideWithValue(null),
        ],
      );

      final notifier = container.read(messageComposerProvider.notifier);
      notifier.sendMessage(
        destinationPeerId: '',
        content: 'Hello',
      );

      expect(container.read(messageComposerProvider).lastError, isNotNull);

      notifier.clearError();
      expect(container.read(messageComposerProvider).lastError, isNull);

      container.dispose();
    });

    test('sendMessage stores message in the shared store', () {
      final container = ProviderContainer(
        overrides: [
          localPeerIdForMessageProvider.overrideWithValue('aa' * 32),
          messageTransmissionServiceProvider.overrideWithValue(null),
          outboundMessageStoreProvider.overrideWith((ref) {
            return OutboundMessageStore();
          }),
        ],
      );

      // Read the store before creating the message.
      final store = container.read(outboundMessageStoreProvider);
      expect(store.length, equals(0));

      final notifier = container.read(messageComposerProvider.notifier);
      notifier.sendMessage(
        destinationPeerId: 'bb' * 32,
        content: 'Hello',
      );

      expect(store.length, equals(1));

      container.dispose();
    });
  });
}
