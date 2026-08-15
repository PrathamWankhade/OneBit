import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/shared/design_system/components/onebit_app_bar.dart';
import 'package:onebit/shared/design_system/components/onebit_panel.dart';
import 'package:onebit/shared/design_system/components/onebit_progress_bar.dart';
import 'package:onebit/shared/design_system/components/onebit_status_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_terminal_label.dart';
import 'package:onebit/shared/design_system/components/onebit_terminal_line.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitPanel', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitPanel(child: Text('Panel content'))),
      );
      expect(find.text('Panel content'), findsOneWidget);
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitPanel(title: 'DIAGNOSTICS', child: Text('Content')),
        ),
      );
      expect(find.text('DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('hides title when null', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitPanel(child: Text('Content'))),
      );
      expect(find.text('DIAGNOSTICS'), findsNothing);
    });

    testWidgets('fills available width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneBitTheme.light,
          home: const Scaffold(body: OneBitPanel(child: Text('Wide'))),
        ),
      );
      final size = tester.getSize(find.byType(OneBitPanel));
      expect(size.width, greaterThan(100));
    });
  });

  group('OneBitTerminalLine', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTerminalLine(
            message: 'NODE VERIFIED',
            status: OneBitTerminalStatus.ok,
          ),
        ),
      );
      expect(find.text('NODE VERIFIED'), findsOneWidget);
    });

    testWidgets('renders bracketed prefix for each status', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const Column(
            children: [
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.ok,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.info,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.warn,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.err,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.node,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.tx,
              ),
              OneBitTerminalLine(
                message: 'test',
                status: OneBitTerminalStatus.rx,
              ),
            ],
          ),
        ),
      );
      expect(find.text('[OK]'), findsOneWidget);
      expect(find.text('[INFO]'), findsOneWidget);
      expect(find.text('[WARN]'), findsOneWidget);
      expect(find.text('[ERR]'), findsOneWidget);
      expect(find.text('[NODE]'), findsOneWidget);
      expect(find.text('[TX]'), findsOneWidget);
      expect(find.text('[RX]'), findsOneWidget);
    });

    testWidgets('custom prefix works with custom status', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTerminalLine(
            message: 'data',
            status: OneBitTerminalStatus.custom,
            prefix: 'SYS',
          ),
        ),
      );
      expect(find.text('[SYS]'), findsOneWidget);
    });
  });

  group('OneBitTerminalLabel', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitTerminalLabel(text: '7F4A...9C21')),
      );
      expect(find.text('7F4A...9C21'), findsOneWidget);
    });

    testWidgets('renders with background when provided', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTerminalLabel(text: 'ID', background: Colors.grey),
        ),
      );
      expect(find.text('ID'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('OneBitStatusIndicator', () {
    testWidgets('renders a colored dot', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitStatusIndicator(status: OneBitIndicatorStatus.success),
        ),
      );
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders label when showLabel is true', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitStatusIndicator(
            status: OneBitIndicatorStatus.success,
            label: 'Online',
            showLabel: true,
          ),
        ),
      );
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('hides label when showLabel is false', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitStatusIndicator(
            status: OneBitIndicatorStatus.success,
            label: 'Online',
            showLabel: false,
          ),
        ),
      );
      expect(find.text('Online'), findsNothing);
    });
  });

  group('OneBitAppBar', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneBitTheme.light,
          home: const Scaffold(appBar: OneBitAppBar(title: 'Settings')),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders custom title widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneBitTheme.light,
          home: const Scaffold(
            appBar: OneBitAppBar(titleWidget: Text('Custom')),
          ),
        ),
      );
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('has preferredSize', (tester) async {
      const bar = OneBitAppBar(title: 'Test');
      expect(bar.preferredSize.height, kToolbarHeight);
    });
  });

  group('OneBitProgressBar', () {
    testWidgets('renders determinate progress', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitProgressBar(
            value: 0.5,
            label: 'file.txt',
            percentage: '50%',
          ),
        ),
      );
      expect(find.text('file.txt'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('renders speed when provided', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitProgressBar(
            value: 0.3,
            label: 'file.txt',
            speed: '1.2 MB/s',
          ),
        ),
      );
      expect(find.text('1.2 MB/s'), findsOneWidget);
    });

    testWidgets('hides label section when all null', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitProgressBar(value: 0.5)));
      // No label, percentage, or speed — only the track should render
      expect(find.byType(Column), findsWidgets);
    });
  });
}
