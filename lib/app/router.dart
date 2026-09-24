import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/main.dart' show gContainer;
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/features/conversations/presentation/conversation_list_screen.dart';
import 'package:onebit/features/conversations/presentation/conversation_screen.dart';
import 'package:onebit/features/conversations/presentation/new_conversation_dialog.dart';
import 'package:onebit/features/identity/presentation/edit_profile_screen.dart';
import 'package:onebit/features/identity/presentation/identity_qr_screen.dart';
import 'package:onebit/features/identity/presentation/identity_qr_scanner_screen.dart';
import 'package:onebit/features/identity/presentation/peer_detail_screen.dart';
import 'package:onebit/features/identity/presentation/peer_list_screen.dart';
import 'package:onebit/features/identity/presentation/profile_screen.dart';
import 'package:onebit/features/identity/presentation/verify_identity_screen.dart';
import 'package:onebit/features/message/presentation/message_screen.dart';
import 'package:onebit/features/navigation/presentation/main_shell_scaffold.dart';
import 'package:onebit/features/nearby/presentation/nearby_screen.dart';
import 'package:onebit/features/onboarding/presentation/onboarding_screen.dart';
import 'package:onebit/features/routing/ui/routing_diagnostics_screen.dart';
import 'package:onebit/features/settings/presentation/screens/about_screen.dart';
import 'package:onebit/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:onebit/features/settings/presentation/screens/mesh_settings_screen.dart';
import 'package:onebit/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:onebit/features/settings/presentation/screens/settings_main_screen.dart';

// Smooth page transition helpers
CustomTransitionPage<void> _slideTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutExpo,
        reverseCurve: Curves.easeInExpo,
      );
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutExpo,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.25, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.08, 0),
            ).animate(secondaryCurved),
            child: child,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<void> _fadeTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
}

GoRouter createRouter(RouterNotifier notifier) {
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => OnboardingScreen(
          onComplete: () => notifier.completeOnboarding(),
        ),
      ),

      // Shell route with floating nav bar for the 4 main tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShellScaffold(
          navigationShell: navigationShell,
          onCenterAction: () => _showNewMessageDialog(context),
        ),
        branches: [
          // Tab 0: Chats (home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const ConversationListScreen(),
              ),
            ],
          ),
          // Tab 1: Nearby (BLE discovery)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nearby',
                builder: (context, state) =>
                    const NearbyScreen(),
              ),
            ],
          ),
          // Tab 2: Identity (profile, QR, fingerprint)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/identity',
                builder: (context, state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Non-tab routes (pushed on top of shell)
      GoRoute(
        path: '/conversation/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return _fadeTransition(context, state, const _InvalidConversation());
          }
          return _slideTransition(
            context,
            state,
            ConversationScreen(conversationId: id),
          );
        },
      ),
      GoRoute(
        path: '/identity/qr',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const IdentityQrScreen()),
      ),
      GoRoute(
        path: '/identity/scan',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const IdentityQrScannerScreen()),
      ),
      GoRoute(
        path: '/identity/verify',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const VerifyIdentityScreen()),
      ),
      GoRoute(
        path: '/identity/edit',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/identity/peers',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const PeerListScreen()),
      ),
      GoRoute(
        path: '/identity/peers/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return _fadeTransition(context, state, const _InvalidPeer());
          }
          return _slideTransition(
            context,
            state,
            PeerDetailScreen(peerIdentityId: id),
          );
        },
      ),
      GoRoute(
        path: '/message/:peerId',
        pageBuilder: (context, state) {
          final peerId = state.pathParameters['peerId'];
          if (peerId == null || peerId.isEmpty) {
            return _fadeTransition(context, state, const _InvalidPeerId());
          }
          return _slideTransition(
            context,
            state,
            MessageScreen(peerId: peerId),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const SettingsMainScreen()),
        routes: [
          GoRoute(
            path: 'privacy',
            pageBuilder: (context, state) =>
                _slideTransition(context, state, const PrivacySettingsScreen()),
          ),
          GoRoute(
            path: 'mesh',
            pageBuilder: (context, state) =>
                _slideTransition(context, state, const MeshSettingsScreen()),
          ),
          GoRoute(
            path: 'appearance',
            pageBuilder: (context, state) => _slideTransition(
              context,
              state,
              const AppearanceSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'about',
            pageBuilder: (context, state) =>
                _slideTransition(context, state, const AboutScreen()),
          ),
          GoRoute(
            path: 'routing-diagnostics',
            pageBuilder: (context, state) => _slideTransition(
              context,
              state,
              const RoutingDiagnosticsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _slideTransition(context, state, const ProfileScreen()),
      ),
    ],
  );

  return router;
}

Future<void> _showNewMessageDialog(BuildContext context) async {
  final name = await showNewConversationDialog(context);
  if (name == null || !context.mounted) return;

  final db = gContainer.read(databaseProvider);
  final id = await db.createConversation(name);
  if (context.mounted) {
    context.push('/conversation/$id');
  }
}

class _InvalidConversation extends StatelessWidget {
  const _InvalidConversation();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invalid conversation.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidPeer extends StatelessWidget {
  const _InvalidPeer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invalid peer ID.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/nearby'),
              child: const Text('Back to Nearby'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidPeerId extends StatelessWidget {
  const _InvalidPeerId();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invalid peer ID.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/nearby'),
              child: const Text('Back to Nearby'),
            ),
          ],
        ),
      ),
    );
  }
}
