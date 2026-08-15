import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

void main() {
  testWidgets('probe narrow conversation frames', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.channelOf(channelId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final exc = tester.takeException();
    if (exc != null) {
      for (final e in find.byType(Row).evaluate()) {
        final ro = e.renderObject;
        if (ro is RenderFlex) {
          var sum = 0.0;
          for (final child in ro.getChildrenAsList()) {
            sum += child.size.width;
          }
          if (sum > ro.size.width + 0.5) {
            debugPrint('OVERFLOW w=${ro.size.width} sum=$sum');
            final chain = <String>[];
            e.visitAncestorElements((ancestor) {
              chain.add(ancestor.widget.runtimeType.toString());
              return true;
            });
            debugPrint('CHAIN: ${chain.join(' <- ')}');
          }
        }
      }
    }
    debugPrint('EXC was: $exc');
    await disposeApp(tester);
  });
}
