import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/presentation/compose_message_controller.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

void main() {
  testWidgets('debug compose state', (tester) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    final view = container.read(composeMessageControllerProvider);
    // ignore: avoid_print
    print(
      'DEBUG offline=${view.offline} enabled=${view.enabled} mode=${view.mode}',
    );
    final mesh = container.read(meshStateProvider);
    // ignore: avoid_print
    print('DEBUG mesh=${mesh.value?.value} err=${mesh.value?.isErr}');
    final buttons = tester.widgetList(find.byType(IconButton));
    // ignore: avoid_print
    print('DEBUG iconButtons=${buttons.length}');

    await tester.tap(find.byIcon(OneBitIcons.attachFile));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print(
      'DEBUG afterTap text="Add attachment"? ${find.text('Add attachment').evaluate().length}',
    );

    await disposeApp(tester);
  });
}
