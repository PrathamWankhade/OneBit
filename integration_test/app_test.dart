import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:onebit/app/app_shell.dart';

/// Device-level smoke test. Run with:
///   flutter test integration_test -d `<device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and renders the shell on-device', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OneBitApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('OneBit'), findsWidgets);
  });

  testWidgets('bluetooth dev screen opens and renders transport panels', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OneBitApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await tester.tap(find.text('Bluetooth transport (dev)'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Bluetooth Transport'), findsOneWidget);
    expect(find.text('Start scan'), findsOneWidget);
    expect(find.text('Advertise'), findsOneWidget);
    expect(find.text('GATT server on'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
  });
}
