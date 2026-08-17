import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_rail.dart';

import 'app/support/app_navigation_support.dart';

void main() {
  testWidgets('debug pump and settle', (tester) async {
    debugPrintScheduleFrameStacks = true;
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(oneBitApp(identity: testIdentity()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    debugPrintScheduleFrameStacks = false;
    expect(find.byType(OneBitNavigationRail), findsOneWidget);
  });
}