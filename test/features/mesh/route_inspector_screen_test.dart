import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/mesh/presentation/route_inspector_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';

void main() {
  group('RouteInspectorScreen', () {
    testWidgets('shows loading while routes load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OneBitLoadingIndicator), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(
              AsyncError(Exception('fail'), StackTrace.empty),
            ),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OneBitErrorState), findsOneWidget);
    });

    testWidgets('shows empty state when no routes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(const AsyncData(Ok([]))),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OneBitEmptyState), findsOneWidget);
    });

    testWidgets('displays routes when available', (tester) async {
      final routes = [
        MeshRoute(
          destination: 'peer-2',
          nextHop: 'peer-1',
          hopCount: 2,
          cost: 1.5,
          quality: 0.8,
          reliability: 0.9,
          preferred: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          lastUsed: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        MeshRoute(
          destination: 'peer-3',
          nextHop: 'peer-1',
          hopCount: 3,
          cost: 2.5,
          quality: 0.5,
          reliability: 0.7,
          preferred: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          lastUsed: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(AsyncData(Ok(routes))),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('peer-2'), findsOneWidget);
      expect(find.text('peer-3'), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(const AsyncData(Ok([]))),
          ],
          child: MaterialApp(
            theme: OneBitTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RouteInspectorScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(const AsyncData(Ok([]))),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const Scaffold(body: RouteInspectorScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RouteInspectorScreen), findsOneWidget);
    });

    testWidgets('renders in landscape', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshRoutesProvider.overrideWithValue(const AsyncData(Ok([]))),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 800,
                height: 400,
                child: RouteInspectorScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RouteInspectorScreen), findsOneWidget);
    });
  });
}
