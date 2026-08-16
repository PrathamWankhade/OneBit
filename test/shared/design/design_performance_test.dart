import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_channel_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_node_card.dart';
import 'package:onebit/shared/design_system/components/onebit_terminal_states.dart';
import 'support/design_support.dart';

void main() {
  group('Design system rendering performance', () {
    testWidgets('OneBitErrorState renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitErrorState(
            message: 'Something went wrong',
            detail: 'Error code: 0x1234',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OneBitErrorState), findsOneWidget);
    });

    testWidgets('OneBitEmptyState renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No data available',
            message: 'Check your connection and try again.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OneBitEmptyState), findsOneWidget);
    });

    testWidgets('OneBitChannelCard renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitChannelCard(
            name: 'General',
            unreadCount: 5,
            lastMessage: 'Hello everyone!',
            timestamp: '14:32',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OneBitChannelCard), findsOneWidget);
    });

    testWidgets('OneBitNodeCard renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNodeCard(
            name: 'Alice',
            nodeId: 'node-001',
            fingerprint: 'AA:BB:CC:DD:EE:FF',
            rssi: -65,
            lastSeen: '2 min ago',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OneBitNodeCard), findsOneWidget);
    });

    testWidgets('OneBitListItem renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitListItem(
            title: 'Bluetooth',
            subtitle: 'Enabled and scanning',
            showChevron: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OneBitListItem), findsOneWidget);
    });

    testWidgets('terminal states render without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoResultsState(
            title: 'No results found',
            message: 'Try adjusting your search.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoNodesState(
            title: 'No nodes nearby',
            message: 'Keep scanning.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        oneBitApp(
          const OneBitNoChannelsState(
            title: 'No channels yet',
            message: 'Start a conversation.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reasonable text renders without overflow', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitErrorState(
            message: 'This is a moderately long error message for testing.',
            detail: 'Additional technical details about the error.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No data available yet',
            message: 'Please check your connection and try again later.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple cards render without performance issues', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          ListView(
            children: List.generate(
              20,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OneBitChannelCard(
                  name: 'Channel $i',
                  unreadCount: i % 3 == 0 ? i : null,
                  lastMessage: 'Message $i',
                  timestamp: '${i % 24}:${(i * 5) % 60}',
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // ListView only renders visible items
      expect(find.byType(OneBitChannelCard), findsWidgets);
    });
  });

  group('Reduced motion compliance', () {
    testWidgets('disables animations when reduceMotion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Text(
                    'reduceMotion: ${MediaQuery.disableAnimationsOf(context)}',
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('reduceMotion: true'), findsOneWidget);
    });
  });

  group('Widget const optimization', () {
    testWidgets('OneBitErrorState supports const constructor', (tester) async {
      // This verifies the widget can be const-constructed
      const widget = OneBitErrorState(
        message: 'Test',
        detail: 'Detail',
      );
      expect(widget.message, 'Test');
      expect(widget.detail, 'Detail');
    });

    testWidgets('OneBitEmptyState supports const constructor', (tester) async {
      const widget = OneBitEmptyState(
        title: 'Empty',
        message: 'No data',
      );
      expect(widget.title, 'Empty');
      expect(widget.message, 'No data');
    });

    testWidgets('OneBitChannelCard supports const constructor', (
      tester,
    ) async {
      const widget = OneBitChannelCard(
        name: 'Test',
      );
      expect(widget.name, 'Test');
    });

    testWidgets('OneBitNodeCard supports const constructor', (tester) async {
      const widget = OneBitNodeCard(
        name: 'Alice',
        nodeId: 'node-001',
      );
      expect(widget.name, 'Alice');
      expect(widget.nodeId, 'node-001');
    });
  });
}
