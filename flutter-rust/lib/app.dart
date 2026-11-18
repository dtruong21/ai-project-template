import 'package:app/core/design/theme.dart';
import 'package:app/core/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light / dark / follow-the-system. Starts on system.
// ponytail: in memory only — resets on restart. Persist with
// shared_preferences when a settings screen offers the choice to users.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  // A named method reads better at call sites than assigning `state`.
  // ignore: use_setters_to_change_properties
  void set(ThemeMode mode) => state = mode;
}

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
      themeMode: ref.watch(themeModeProvider),
    );
  }
}
