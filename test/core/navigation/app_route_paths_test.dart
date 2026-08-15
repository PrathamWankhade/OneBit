import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';

void main() {
  group('AppRoutePaths registry', () {
    final paths = [
      AppRoutePaths.splash,
      AppRoutePaths.onboarding,
      AppRoutePaths.channels,
      AppRoutePaths.channel,
      AppRoutePaths.message,
      AppRoutePaths.composeMessage,
      AppRoutePaths.search,
      AppRoutePaths.transfer,
      AppRoutePaths.mediaGallery,
      AppRoutePaths.nodes,
      AppRoutePaths.node,
      AppRoutePaths.identity,
      AppRoutePaths.qr,
      AppRoutePaths.qrIdentity,
      AppRoutePaths.qrScanner,
      AppRoutePaths.nearby,
      AppRoutePaths.mesh,
      AppRoutePaths.routeInspector,
      AppRoutePaths.settings,
      AppRoutePaths.appearance,
      AppRoutePaths.privacy,
      AppRoutePaths.storage,
      AppRoutePaths.notifications,
      AppRoutePaths.bluetooth,
      AppRoutePaths.developer,
      AppRoutePaths.diagnostics,
      AppRoutePaths.logs,
      AppRoutePaths.about,
      AppRoutePaths.licenses,
      AppRoutePaths.bluetoothDebug,
      AppRoutePaths.meshDebug,
      AppRoutePaths.packetDebug,
      AppRoutePaths.dtnDebug,
    ];

    test('every path is a non-empty absolute location', () {
      for (final path in paths) {
        expect(path, startsWith('/'), reason: path);
        expect(path.length, greaterThanOrEqualTo(2), reason: path);
      }
    });

    test('the legacy home path is the bare slash redirect', () {
      expect(AppRoutePaths.home, '/');
    });

    test('paths are unique', () {
      expect(paths.toSet().length, paths.length);
    });

    test('parameterized routes use the registered parameter names', () {
      expect(
        AppRoutePaths.channel,
        '/channels/:${AppRouteParameters.channelId}',
      );
      expect(
        AppRoutePaths.message,
        '/channels/:${AppRouteParameters.channelId}/'
        'message/:${AppRouteParameters.messageId}',
      );
      expect(
        AppRoutePaths.composeMessage,
        '/channels/:${AppRouteParameters.channelId}/compose',
      );
      expect(AppRoutePaths.node, '/nodes/:${AppRouteParameters.nodeId}');
      expect(
        AppRoutePaths.transfer,
        '/transfers/:${AppRouteParameters.sessionId}',
      );
    });

    test('tab paths are branch roots', () {
      expect(AppRoutePaths.channels, '/channels');
      expect(AppRoutePaths.nodes, '/nodes');
      expect(AppRoutePaths.nearby, '/nearby');
      expect(AppRoutePaths.mesh, '/mesh');
    });

    test('settings is a top-level route, not a branch', () {
      expect(AppRoutePaths.settings, '/settings');
    });

    test('about area lives under settings', () {
      expect(AppRoutePaths.about, '/settings/about');
      expect(AppRoutePaths.licenses, '/settings/licenses');
    });

    test('developer gated paths cover the whole developer area', () {
      expect(
        AppRoutePaths.developerGatedPaths,
        containsAll([
          AppRoutePaths.developer,
          AppRoutePaths.diagnostics,
          AppRoutePaths.logs,
          AppRoutePaths.bluetoothDebug,
          AppRoutePaths.meshDebug,
          AppRoutePaths.packetDebug,
          AppRoutePaths.dtnDebug,
        ]),
      );
    });
  });

  group('deep-link builders', () {
    test('channel', () {
      expect(AppRoutePaths.channelOf('chan-42'), '/channels/chan-42');
    });

    test('message', () {
      expect(
        AppRoutePaths.messageOf('chan-42', 'msg-9'),
        '/channels/chan-42/message/msg-9',
      );
    });

    test('compose', () {
      expect(AppRoutePaths.composeOf('chan-42'), '/channels/chan-42/compose');
    });

    test('node', () {
      expect(AppRoutePaths.nodeOf('node-7'), '/nodes/node-7');
    });

    test('transfer', () {
      expect(AppRoutePaths.transferOf('session-1'), '/transfers/session-1');
    });
  });
}
