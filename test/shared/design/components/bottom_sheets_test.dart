import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_bottom_sheets.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import '../support/design_support.dart';

void main() {
  testWidgets('showOneBitActionSheet returns the tapped value', (tester) async {
    String? picked;
    await tester.pumpWidget(
      oneBitApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showOneBitActionSheet<String>(
                context,
                title: 'Node actions',
                actions: [
                  const OneBitSheetAction(label: 'Verify', value: 'verify'),
                  const OneBitSheetAction(
                    label: 'Forget',
                    value: 'forget',
                    destructive: true,
                  ),
                ],
              ).then((value) => picked = value),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Node actions'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Forget'), findsOneWidget);

    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(picked, 'forget');
  });

  testWidgets('disabled actions are not tappable', (tester) async {
    String? picked;
    await tester.pumpWidget(
      oneBitApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showOneBitActionSheet<String>(
                context,
                actions: [
                  const OneBitSheetAction(
                    label: 'Locked',
                    value: 'locked',
                    enabled: false,
                  ),
                ],
              ).then((value) => picked = value),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('showOneBitSelectionSheet marks the selected option', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      oneBitApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showOneBitSelectionSheet<String>(
                context,
                title: 'Order',
                options: [
                  const OneBitSheetAction(label: 'Latest', value: 'latest'),
                  const OneBitSheetAction(label: 'Oldest', value: 'oldest'),
                ],
                selected: 'oldest',
              ).then((value) => chosen = value),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(OneBitIcons.check), findsOneWidget);

    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();
    expect(chosen, 'latest');
  });

  testWidgets('showOneBitSheetContent hosts arbitrary content', (tester) async {
    await tester.pumpWidget(
      oneBitApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showOneBitSheetContent(
                context,
                title: 'Filters',
                content: const Text('Status: all'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Status: all'), findsOneWidget);
  });

  testWidgets('action rows keep a 48dp target', (tester) async {
    await tester.pumpWidget(
      oneBitApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showOneBitActionSheet<String>(
                context,
                actions: [const OneBitSheetAction(label: 'Row', value: 'row')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final row = tester.getSize(
      find.byWidgetPredicate((widget) => widget is OneBitSheetRow<String>),
    );
    expect(row.height, greaterThanOrEqualTo(48));
  });
}
