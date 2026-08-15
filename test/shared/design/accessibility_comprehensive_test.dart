import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_channel_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_node_card.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_terminal_states.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'support/design_support.dart';

void main() {
  group('OneBitIconButton accessibility', () {
    testWidgets('enforces 48dp minimum touch target', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitIconButton(
            icon: OneBitIcons.close,
            onPressed: _noop,
            tooltip: 'Close',
          ),
        ),
      );
      final size = tester.getSize(find.byType(OneBitIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('renders with tooltip parameter', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitIconButton(
            icon: OneBitIcons.search,
            onPressed: _noop,
            tooltip: 'Search',
          ),
        ),
      );
      expect(find.byType(OneBitIconButton), findsOneWidget);
    });
  });

  group('OneBitCard semantic label', () {
    testWidgets('exposes semanticLabel when tappable', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitCard(
            onTap: _noop,
            semanticLabel: 'Test card',
            child: Text('Content'),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitCard));
      expect(semantics.label, contains('Test card'));
    });
  });

  group('OneBitChannelCard accessibility', () {
    testWidgets('exposes channel name as semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitChannelCard(
            name: 'General',
            onTap: _noop,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitChannelCard));
      expect(semantics.label, contains('Channel General'));
    });
  });

  group('OneBitNodeCard accessibility', () {
    testWidgets('exposes node name as semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNodeCard(
            name: 'Alice',
            nodeId: 'node-001',
            onTap: _noop,
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitNodeCard));
      expect(semantics.label, contains('Node Alice'));
    });
  });

  group('OneBitListItem accessibility', () {
    testWidgets('combines title and subtitle in semantic label', (tester) async {
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
  });

  group('OneBitPermissionState accessibility', () {
    testWidgets('exposes custom icon', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitPermissionState(
            title: 'Location',
            message: 'Location is needed for nearby discovery.',
            onRequest: _noop,
            icon: OneBitIcons.radar,
          ),
        ),
      );
      expect(find.byIcon(OneBitIcons.radar), findsOneWidget);
    });
  });

  group('Error state widgets accessibility', () {
    testWidgets('OneBitErrorState exposes message as semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitErrorState(
            message: 'Transfer failed',
            detail: 'timeout',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitErrorState));
      expect(semantics.label, contains('Transfer failed'));
    });

    testWidgets('OneBitEmptyState exposes title as semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No channels yet',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitEmptyState));
      expect(semantics.label, contains('No channels yet'));
    });

    testWidgets('OneBitOfflineState exposes title as semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitOfflineState(
            title: 'Offline',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitOfflineState));
      expect(semantics.label, contains('Offline'));
    });

    testWidgets('OneBitInlineError renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitInlineError(
            message: 'Connection lost',
          ),
        ),
      );
      expect(find.byType(OneBitInlineError), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Terminal states accessibility', () {
    testWidgets('OneBitNoResultsState exposes semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoResultsState(
            title: 'No results',
            message: 'Try a different search term.',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitNoResultsState));
      expect(semantics.label, contains('No results'));
    });

    testWidgets('OneBitNoNodesState exposes semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoNodesState(
            title: 'No nodes nearby',
            message: 'Keep this screen open.',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitNoNodesState));
      expect(semantics.label, contains('No nodes nearby'));
    });

    testWidgets('OneBitNoChannelsState exposes semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoChannelsState(
            title: 'No channels yet',
            message: 'Start a conversation.',
          ),
        ),
      );
      final semantics = tester.getSemantics(
        find.byType(OneBitNoChannelsState),
      );
      expect(semantics.label, contains('No channels yet'));
    });
  });

  group('48dp touch target compliance', () {
    testWidgets('OneBitIconButton meets minimum size', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitIconButton(
            icon: OneBitIcons.close,
            onPressed: _noop,
            tooltip: 'Close',
          ),
        ),
      );
      final size = tester.getSize(find.byType(OneBitIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}

void _noop() {}
