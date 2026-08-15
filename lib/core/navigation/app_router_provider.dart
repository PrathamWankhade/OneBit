import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/navigation/app_router.dart';

/// The process-wide [GoRouter].
///
/// Features obtain navigation via `ref.read(goRouterProvider)`; screens use
/// the `context.go`/`context.push` extensions provided by go_router.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>(
  AppRouter.create,
);
