import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/config/app_flavor.dart';

void main() {
  group('AppFlavor.fromName', () {
    test('accepts canonical names', () {
      expect(AppFlavor.fromName('debug'), AppFlavor.debug);
      expect(AppFlavor.fromName('beta'), AppFlavor.beta);
      expect(AppFlavor.fromName('release'), AppFlavor.release);
    });

    test('accepts Gradle product-flavor aliases', () {
      expect(AppFlavor.fromName('dev'), AppFlavor.debug);
      expect(AppFlavor.fromName('prod'), AppFlavor.release);
    });

    test('falls back to debug for unknown or absent names', () {
      expect(AppFlavor.fromName(null), AppFlavor.debug);
      expect(AppFlavor.fromName('staging'), AppFlavor.debug);
    });
  });

  group('AppFlavor semantics', () {
    test('release is marked as release and production', () {
      expect(AppFlavor.release.isRelease, isTrue);
      expect(AppFlavor.release.isDebug, isFalse);
      expect(AppFlavor.release.defaultEnvironment.rawName, 'production');
    });

    test('debug maps to a development environment', () {
      expect(AppFlavor.debug.defaultEnvironment.rawName, 'development');
      expect(AppFlavor.beta.defaultEnvironment.rawName, 'staging');
    });
  });
}
