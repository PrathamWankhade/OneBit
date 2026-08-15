import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

void main() {
  testWidgets('debug draft persistence', (tester) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    final controller = container.read(
      composeMessageControllerProvider.notifier,
    );
    await controller.initNewMessage(channelId);
    controller.updateDraft('Draft me');
    expect(controller.state.draft, 'Draft me');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final saved = await container
        .read(messagingEngineProvider)
        .loadDraft(channelId);
    // ignore: avoid_print
    print('DEBUG saved=${saved.value?.body}');
    expect(saved.value?.body, 'Draft me');
    await disposeApp(tester);
  });
}
