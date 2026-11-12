/// App router — single `GoRouter` instance, exposed as a Riverpod provider so
/// it can react to auth state via `ref.watch`.
///
/// Adding routes:
///   1. Declare a typed route in `routes.dart` using `@TypedGoRoute<T>` on a
///      class that extends `GoRouteData` with a `const` constructor.
///      (Both are required — see master spec gotcha #5.)
///   2. Run `dart run build_runner watch -d` so `routes.g.dart` is regenerated.
///   3. Add the generated `$fooRoute` to the `routes:` list below.
///   4. Navigate with `const FooRoute(id: x).go(context)` — never raw paths.
///
/// Wiring in `app.dart`:
///
///   class App extends ConsumerWidget {
///     const App({super.key});
///
///     @override
///     Widget build(BuildContext context, WidgetRef ref) {
///       final router = ref.watch(routerProvider);
///       return MaterialApp.router(
///         routerConfig: router,
///         theme: buildTheme(Brightness.light),
///         darkTheme: buildTheme(Brightness.dark),
///       );
///     }
///   }
///
/// Auth redirects: read auth state inside the `redirect:` callback below. The
/// provider re-watches it, so the router rebuilds on sign-in / sign-out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app's top-level router. Watch via `ref.watch(routerProvider)` in
/// `app.dart`. Wrap with `@riverpod` codegen once you have more than one
/// dependency, but keep the manual `Provider` here so the template runs
/// before `build_runner` is invoked.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // TODO: replace with `$homeRoute` from `routes.g.dart` once typed routes
      // are scaffolded. Inline route kept here so the template compiles before
      // codegen runs.
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderHome(),
      ),
    ],
    // redirect: (context, state) {
    //   final isSignedIn = ref.read(authStateProvider).value != null;
    //   final goingToAuth = state.matchedLocation.startsWith('/auth');
    //   if (!isSignedIn && !goingToAuth) return '/auth/signin';
    //   if (isSignedIn && goingToAuth) return '/';
    //   return null;
    // },
  );
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter template')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Replace this with your home screen.\n\n'
            'Add typed routes via `lib/core/routing/routes.dart` and the '
            '`@TypedGoRoute` annotation, then list them above.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
