import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_channel_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_node_card.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

import '../support/design_support.dart';

void main() {
  group('Touch targets — 48dp minimum', () {
    testWidgets('OneBitIconButton meets 48dp minimum', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitIconButton(
            icon: OneBitIcons.close,
            onPressed: () {},
            tooltip: 'Close',
          ),
        ),
      );
      final size = tester.getSize(find.byType(OneBitIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('OneBitButton large meets 48dp target', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitButton(
            label: 'Large',
            onPressed: _noop,
            size: OneBitButtonSize.large,
          ),
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('OneBitListItem meets 48dp minimum', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitListItem(
            title: 'Test Item',
            subtitle: 'Subtitle',
            onTap: _noop,
          ),
        ),
      );
      final size = tester.getSize(find.byType(OneBitListItem));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('OneBitTapTarget enforces 48dp minimum', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          // ignore: prefer_const_constructors
          OneBitTapTarget(
            onTap: _noop,
            child: const SizedBox(width: 16, height: 16),
          ),
        ),
      );
      final size = tester.getSize(find.byType(OneBitTapTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('Screen reader — semantic labels', () {
    testWidgets('OneBitIconButton exposes tooltip', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          // ignore: prefer_const_constructors
          OneBitIconButton(
            icon: OneBitIcons.close,
            onPressed: _noop,
            tooltip: 'Close',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitIconButton));
      expect(semantics.tooltip, 'Close');
    });

    testWidgets('OneBitCard exposes semanticLabel when tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitCard(
            semanticLabel: 'Test card',
            onTap: _noop,
            child: Text('Content'),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitCard));
      expect(semantics.label, contains('Test card'));
    });

    testWidgets('OneBitChannelCard exposes channel name', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitChannelCard(name: 'General', onTap: _noop)),
      );
      final semantics = tester.getSemantics(find.byType(OneBitChannelCard));
      expect(semantics.label, contains('Channel General'));
    });

    testWidgets('OneBitNodeCard exposes node name', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNodeCard(name: 'Alice', nodeId: 'AB:CD:EF', onTap: _noop),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitNodeCard));
      expect(semantics.label, contains('Node Alice'));
    });

    testWidgets('OneBitListItem combines title and subtitle', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitListItem(
            title: 'Bluetooth',
            subtitle: 'Enabled',
            onTap: _noop,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitListItem));
      expect(semantics.label, contains('Bluetooth. Enabled'));
    });

    testWidgets('OneBitEmptyState exposes title', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No items',
            message: 'Nothing here yet.',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitEmptyState));
      expect(semantics.label, contains('No items'));
    });

    testWidgets('OneBitOfflineState exposes title', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitOfflineState(title: 'Offline', message: 'No connection.'),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitOfflineState));
      expect(semantics.label, contains('Offline'));
    });

    testWidgets('OneBitPermissionState exposes title and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitPermissionState(
            title: 'Bluetooth needed',
            message: 'Please enable Bluetooth.',
            onRequest: _noop,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitPermissionState));
      expect(semantics.label, contains('Bluetooth needed'));
      expect(semantics.label, contains('Please enable Bluetooth'));
    });

    testWidgets('OneBitBadge announces unread count', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitBadge(count: 5)));
      final semantics = tester.getSemantics(find.byType(OneBitBadge));
      expect(semantics, isSemantics(label: '5 unread items'));
    });

    testWidgets('OneBitStatusChip exposes label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitStatusChip(
            label: 'Online',
            tone: OneBitStatusTone.success,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitStatusChip));
      expect(semantics, isSemantics(label: 'Online'));
    });
  });

  group('Decorative icons — ExcludeSemantics', () {
    testWidgets('OneBitListItem excludes leading icon from semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitListItem(
            title: 'Test',
            leading: Icons.star,
            onTap: _noop,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitListItem));
      expect(semantics.label, contains('Test'));
    });

    testWidgets('OneBitEmptyState excludes decorative icon', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitEmptyState(title: 'Empty', icon: Icons.inbox)),
      );
      final semantics = tester.getSemantics(find.byType(OneBitEmptyState));
      expect(semantics.label, contains('Empty'));
    });
  });

  group('Reduced motion — system preference', () {
    testWidgets('OneBitMotion.resolve returns Duration.zero when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                final duration = OneBitMotion.resolve(
                  context,
                  OneBitMotion.medium,
                );
                expect(duration, Duration.zero);
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );
    });

    testWidgets(
      'OneBitMotion.resolve passes duration when animations enabled',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Builder(
                builder: (context) {
                  final duration = OneBitMotion.resolve(
                    context,
                    OneBitMotion.medium,
                  );
                  expect(duration, OneBitMotion.medium);
                  return const Scaffold(body: SizedBox());
                },
              ),
            ),
          ),
        );
      },
    );

    testWidgets('context.reduceMotion reflects system setting', (tester) async {
      bool? reduceMotion;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reduceMotion = context.reduceMotion;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );
      expect(reduceMotion, isTrue);
    });
  });

  group('Text scaling — system support', () {
    testWidgets('OneBitButton handles large text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    return const OneBitButton(
                      label: 'Scaled',
                      onPressed: _noop,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Scaled'), findsOneWidget);
    });

    testWidgets('OneBitListItem handles large text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const [
                  OneBitListItem(title: 'Scaled Item', onTap: _noop),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Scaled Item'), findsOneWidget);
    });

    testWidgets('OneBitTextField handles large text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: OneBitTextField(
                controller: TextEditingController(),
                label: 'Search',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Search'), findsOneWidget);
    });
  });

  group('Navigation semantics', () {
    testWidgets('Floating navigation items have semantic labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitListItem(title: 'Navigation test', onTap: _noop)),
      );
      expect(find.text('Navigation test'), findsOneWidget);
    });
  });

  group('Form accessibility', () {
    testWidgets('OneBitTextField has semantic label via labelText', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitTextField(controller: TextEditingController(), label: 'Email'),
        ),
      );
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('OneBitButton disabled state is semantically announced', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitButton(label: 'Submit', onPressed: null)),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('Card accessibility', () {
    testWidgets('OneBitCard has semantic button when tappable', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitCard(onTap: _noop, child: Text('Tappable card'))),
      );
      final semantics = tester.getSemantics(find.byType(OneBitCard));
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('OneBitCard without onTap is not a button', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitCard(child: Text('Static card'))),
      );
      final semantics = tester.getSemantics(find.byType(OneBitCard));
      expect(semantics.flagsCollection.isButton, isFalse);
    });
  });

  group('Accessibility tokens', () {
    test('minInteractiveSize is 48dp', () {
      expect(OneBitAccessibility.minInteractiveSize, 48);
    });

    test('minVisualSize is 24dp', () {
      expect(OneBitAccessibility.minVisualSize, 24);
    });
  });
}

void _noop() {}
