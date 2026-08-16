import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/responsive/onebit_master_detail.dart';

void main() {
  group('OneBitMasterDetail', () {
    testWidgets('shows only master on compact viewport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitMasterDetail(
              master: Text('master'),
              detail: Text('detail'),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsNothing);
    });

    testWidgets('shows master and detail side-by-side on medium viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitMasterDetail(
              master: Text('master'),
              detail: Text('detail'),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(720, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('shows master and detail side-by-side on expanded viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitMasterDetail(
              master: Text('master'),
              detail: Text('detail'),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('renders a divider between panes on tablets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitMasterDetail(
              master: Text('master'),
              detail: Text('detail'),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(720, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.byType(Container), findsWidgets);
    });
  });

  group('OneBitResponsiveGrid', () {
    testWidgets('renders single column on compact viewport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitResponsiveGrid(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('renders two columns on medium viewport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitResponsiveGrid(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(720, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('renders three columns on expanded viewport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitResponsiveGrid(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('respects custom column counts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitResponsiveGrid(
              compactColumns: 2,
              mediumColumns: 3,
              expandedColumns: 4,
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
                Text('Item 4'),
              ],
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(find.text('Item 4'), findsOneWidget);
    });

    testWidgets('applies outer padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneBitResponsiveGrid(
              padding: EdgeInsets.all(16),
              children: [Text('Item')],
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('Item'), findsOneWidget);
    });
  });
}
