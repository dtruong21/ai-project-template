import 'package:app/core/design/theme.dart';
import 'package:app/core/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'App',
      routerConfig: ref.watch(routerProvider),
      // `buildTheme` exists in every design system — switching systems with
      // scripts/pick-design-system.sh never touches this file.
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
    );
  }
}
