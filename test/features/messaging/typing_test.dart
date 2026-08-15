import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/engine/typing_engine.dart';
import 'package:onebit/features/messaging/domain/messages/typing_state.dart';

void main() {
  group('TypingEngine', () {
    test('startTyping emits a started state and marks presence', () {
      final typing = TypingEngine(
        minBeaconInterval: const Duration(seconds: 1),
      );
      final changed = typing.startTyping('c1', 'node-b');
      expect(changed, isTrue);
      expect(typing.isTyping('c1', 'node-b'), isTrue);
      expect(typing.phaseOf('c1', 'node-b'), TypingPhase.started);
      expect(typing.typingKeys.value, contains('c1::node-b'));
      typing.dispose();
    });

    test('repeat started beacons before timeout do not change state', () {
      final typing = TypingEngine();
      typing.startTyping('c1', 'node-b');
      final changed = typing.startTyping('c1', 'node-b');
      expect(changed, isFalse);
      typing.dispose();
    });

    test('stopTyping flushes the presence key', () {
      final typing = TypingEngine();
      typing.startTyping('c1', 'node-b');
      typing.stopTyping('c1', 'node-b');
      expect(typing.isTyping('c1', 'node-b'), isFalse);
      expect(typing.phaseOf('c1', 'node-b'), TypingPhase.idle);
      expect(typing.typingKeys.value, isEmpty);
      typing.dispose();
    });

    test('timeout moves started → timeout → idle', () async {
      final typing = TypingEngine(
        timeoutAfter: const Duration(milliseconds: 30),
        idleAfter: const Duration(milliseconds: 30),
      );
      typing.startTyping('c1', 'node-b');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(typing.isTyping('c1', 'node-b'), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(typing.phaseOf('c1', 'node-b'), TypingPhase.idle);
      typing.dispose();
    });

    test('typingKeys only contains currently typing pairs', () async {
      final typing = TypingEngine(
        timeoutAfter: const Duration(milliseconds: 30),
      );
      typing.startTyping('c1', 'node-b');
      typing.startTyping('c2', 'node-c');
      expect(typing.typingKeys.value, hasLength(2));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(typing.typingKeys.value, isEmpty);
      typing.dispose();
    });

    test('beacon throttle allows one beacon per channel per interval', () {
      final typing = TypingEngine(
        minBeaconInterval: const Duration(seconds: 1),
      );
      expect(typing.shouldSendBeacon('c1', started: true), isTrue);
      typing.markBeaconSent('c1');
      expect(typing.shouldSendBeacon('c1', started: true), isFalse);
      expect(typing.shouldSendBeacon('c2', started: true), isTrue);
      typing.dispose();
    });

    test('stop beacons are always sendable', () {
      final typing = TypingEngine();
      expect(typing.shouldSendBeacon('c1', started: false), isTrue);
      typing.dispose();
    });

    test('changes stream emits started → stopped → idle', () async {
      final typing = TypingEngine();
      final phases = <TypingPhase>[];
      final sub = typing.changes.listen((s) => phases.add(s.state));
      typing.startTyping('c1', 'node-b');
      await Future<void>.delayed(Duration.zero);
      typing.stopTyping('c1', 'node-b');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(phases, [
        TypingPhase.started,
        TypingPhase.stopped,
        TypingPhase.idle,
      ]);
      typing.dispose();
    });

    test('diagnostics hook fires on transitions', () {
      final events = <TypingPhase>[];
      final typing = TypingEngine(
        onDiagnostics:
            ({
              required channelId,
              required node,
              required phase,
              DateTime? since,
            }) {
              events.add(phase);
            },
      );
      typing.startTyping('c1', 'node-b');
      typing.stopTyping('c1', 'node-b');
      expect(events, [TypingPhase.started, TypingPhase.stopped]);
      typing.dispose();
    });
  });
}
