import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/launch/data/shared_preferences_first_run_repository.dart';
import 'package:onebit/features/launch/domain/display_name_validator.dart';
import 'package:onebit/features/launch/domain/first_run_state.dart';
import 'package:onebit/features/launch/domain/launch_flow_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // ---------------------------------------------------------------
  // FirstRunRepository (SharedPreferences)
  // ---------------------------------------------------------------
  group('FirstRunRepository persistence', () {
    test('load returns null on fresh prefs', () async {
      final repo = SharedPreferencesFirstRunRepository(
        SharedPreferencesAsync(),
      );
      expect(await repo.load(), isNull);
    });

    test('save and load round-trip every state', () async {
      final repo = SharedPreferencesFirstRunRepository(
        SharedPreferencesAsync(),
      );
      for (final state in FirstRunState.values) {
        await repo.save(state);
        expect(await repo.load(), state, reason: 'state: ${state.name}');
      }
    });

    test('overwrite replaces previous value', () async {
      final repo = SharedPreferencesFirstRunRepository(
        SharedPreferencesAsync(),
      );
      await repo.save(FirstRunState.intro);
      await repo.save(FirstRunState.completed);
      expect(await repo.load(), FirstRunState.completed);
    });
  });

  // ---------------------------------------------------------------
  // LaunchFlowResolver
  // ---------------------------------------------------------------
  group('LaunchFlowResolver.resolve', () {
    test('identity + null persisted => ready (legacy install)', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: true,
        persisted: null,
      );
      expect(result.ready, isTrue);
      expect(result.state, FirstRunState.completed);
    });

    test('identity + completed => ready', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: true,
        persisted: FirstRunState.completed,
      );
      expect(result.ready, isTrue);
    });

    test('identity + pending stage => initializing', () {
      for (final stage in FirstRunState.values) {
        if (stage == FirstRunState.completed) continue;
        final result = LaunchFlowResolver.resolve(
          hasIdentity: true,
          persisted: stage,
        );
        expect(result.ready, isFalse, reason: 'stage: ${stage.name}');
        expect(
          result.state,
          FirstRunState.initializing,
          reason: 'stage: ${stage.name}',
        );
      }
    });

    test('no identity + null persisted => newInstallation', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: false,
        persisted: null,
      );
      expect(result.ready, isFalse);
      expect(result.state, FirstRunState.newInstallation);
    });

    test('no identity + newInstallation => newInstallation', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: false,
        persisted: FirstRunState.newInstallation,
      );
      expect(result.state, FirstRunState.newInstallation);
    });

    test('no identity + intro => intro', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: false,
        persisted: FirstRunState.intro,
      );
      expect(result.state, FirstRunState.intro);
    });

    test('no identity + displayNameRequired => displayNameRequired', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: false,
        persisted: FirstRunState.displayNameRequired,
      );
      expect(result.state, FirstRunState.displayNameRequired);
    });

    test(
      'no identity + initializing => displayNameRequired (identity lost)',
      () {
        final result = LaunchFlowResolver.resolve(
          hasIdentity: false,
          persisted: FirstRunState.initializing,
        );
        expect(result.state, FirstRunState.displayNameRequired);
      },
    );

    test('no identity + completed => newInstallation (identity gone)', () {
      final result = LaunchFlowResolver.resolve(
        hasIdentity: false,
        persisted: FirstRunState.completed,
      );
      expect(result.state, FirstRunState.newInstallation);
    });
  });

  // ---------------------------------------------------------------
  // DisplayNameValidator
  // ---------------------------------------------------------------
  group('DisplayNameValidator.validate', () {
    test('rejects empty string', () {
      final result = DisplayNameValidator.validate('');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.empty);
    });

    test('rejects whitespace-only string', () {
      final result = DisplayNameValidator.validate('   ');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.empty);
    });

    test('trims leading/trailing whitespace', () {
      final result = DisplayNameValidator.validate('  Alice  ');
      expect(result.isValid, isTrue);
      expect(result.normalized, 'Alice');
    });

    test('accepts valid name with letters', () {
      final result = DisplayNameValidator.validate('Alice');
      expect(result.isValid, isTrue);
      expect(result.normalized, 'Alice');
    });

    test('accepts name with spaces', () {
      final result = DisplayNameValidator.validate('Alice Bob');
      expect(result.isValid, isTrue);
      expect(result.normalized, 'Alice Bob');
    });

    test('accepts name with numbers', () {
      final result = DisplayNameValidator.validate('Node42');
      expect(result.isValid, isTrue);
    });

    test('accepts name with common punctuation', () {
      final result = DisplayNameValidator.validate('Alice-Bob_1.0');
      expect(result.isValid, isTrue);
    });

    test('accepts Unicode characters', () {
      final result = DisplayNameValidator.validate('नोड');
      expect(result.isValid, isTrue);
      expect(result.normalized, 'नोड');
    });

    test('rejects name exceeding max length', () {
      final longName = 'A' * (DisplayNameRules.maxLength + 1);
      final result = DisplayNameValidator.validate(longName);
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.tooLong);
    });

    test('accepts name at max length', () {
      final maxName = 'A' * DisplayNameRules.maxLength;
      final result = DisplayNameValidator.validate(maxName);
      expect(result.isValid, isTrue);
    });

    test('rejects control characters', () {
      final result = DisplayNameValidator.validate('Alice\x00Bob');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.controlCharacters);
    });

    test('rejects DEL control character', () {
      final result = DisplayNameValidator.validate('Alice\x7FBob');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.controlCharacters);
    });

    test('rejects unpaired high surrogate', () {
      // High surrogate without a following low surrogate.
      final result = DisplayNameValidator.validate('\uD800');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.invalidUnicode);
    });

    test('rejects lone low surrogate', () {
      final result = DisplayNameValidator.validate('\uDC00');
      expect(result.isValid, isFalse);
      expect(result.issue, DisplayNameIssue.invalidUnicode);
    });

    test('accepts paired surrogates (emoji)', () {
      // Smiley face: U+1F600 = \uD83D\uDE00
      final result = DisplayNameValidator.validate('Alice \uD83D\uDE00');
      expect(result.isValid, isTrue);
    });
  });
}
