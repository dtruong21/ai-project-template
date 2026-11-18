/// Component gallery — every kit component in every state, in the installed
/// design system. This is where "does it look right" gets judged: open it in
/// light and dark (toggle in the app bar) after any token or component change.
///
/// Debug builds only (the home screen hides the entry in release).
library;

import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Component gallery'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light' : 'Switch to dark',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .set(isDark ? ThemeMode.light : ThemeMode.dark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: const [
          _Section('Color', _Colors()),
          _Section('Type', _Type()),
          _Section('Buttons', _Buttons()),
          _Section('Inputs', _Inputs()),
          _Section('Surfaces', _Surfaces()),
          _Section('Feedback', _Feedback()),
          _Section('States', _States()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: UiTokens.of(context).muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: Gap.md),
          child,
        ],
      ),
    );
  }
}

class _Colors extends StatelessWidget {
  const _Colors();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = UiTokens.of(context);
    // Label color is picked per swatch for legibility; it is not a token.
    Color labelOn(Color background) =>
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final swatches = <(String, Color)>[
      ('primary', scheme.primary),
      ('container', scheme.primaryContainer),
      ('surface', scheme.surface),
      ('raised', scheme.surfaceContainer),
      ('success', tokens.success),
      ('warning', tokens.warning),
      ('danger', tokens.danger),
      ('muted', tokens.muted),
    ];
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final (name, background) in swatches)
          Container(
            width: 84,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: labelOn(background)),
            ),
          ),
      ],
    );
  }
}

class _Type extends StatelessWidget {
  const _Type();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Headline', style: text.headlineMedium),
        Text('Title large', style: text.titleLarge),
        Text('Title medium', style: text.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(
          'Body — the quick brown fox jumps over the lazy dog. 0123456789',
          style: text.bodyMedium,
        ),
        Text(
          'Caption — secondary information',
          style: text.bodySmall?.copyWith(color: UiTokens.of(context).muted),
        ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final variant in AppButtonVariant.values) ...[
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              AppButton(
                label: _name(variant),
                variant: variant,
                onPressed: () {},
              ),
              AppButton(label: 'Disabled', variant: variant, onPressed: null),
              AppButton(
                label: 'Loading',
                variant: variant,
                onPressed: () {},
                loading: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
        ],
        AppButton(
          label: 'Full width with icon',
          icon: Icons.add,
          expand: true,
          onPressed: () {},
        ),
      ],
    );
  }

  String _name(AppButtonVariant variant) => switch (variant) {
    AppButtonVariant.primary => 'Primary',
    AppButtonVariant.secondary => 'Secondary',
    AppButtonVariant.text => 'Text',
    AppButtonVariant.danger => 'Danger',
  };
}

class _Inputs extends StatefulWidget {
  const _Inputs();

  @override
  State<_Inputs> createState() => _InputsState();
}

class _InputsState extends State<_Inputs> {
  bool _switch = true;
  bool _check = true;
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Label',
            hintText: 'Placeholder',
            helperText: 'Helper text',
          ),
        ),
        const SizedBox(height: Gap.md),
        const TextField(
          decoration: InputDecoration(
            labelText: 'With error',
            errorText: "Name can't be empty.",
          ),
        ),
        const SizedBox(height: Gap.md),
        const TextField(
          enabled: false,
          decoration: InputDecoration(labelText: 'Disabled'),
        ),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          children: [
            for (final (index, label) in ['One', 'Two', 'Three'].indexed)
              ChoiceChip(
                label: Text(label),
                selected: _chip == index,
                onSelected: (_) => setState(() => _chip = index),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Switch'),
          value: _switch,
          onChanged: (value) => setState(() => _switch = value),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Checkbox'),
          value: _check,
          onChanged: (value) => setState(() => _check = value ?? false),
        ),
      ],
    );
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card title', style: text.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  'Cards group related content. Padding is Gap.lg.',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const AppAvatar(name: 'David Truong'),
                title: const Text('List row with avatar'),
                subtitle: const Text('Secondary line'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('List row with icon'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        AppButton(
          label: 'Message',
          variant: AppButtonVariant.secondary,
          onPressed: () => showMessage(context, 'Saved'),
        ),
        AppButton(
          label: 'Error',
          variant: AppButtonVariant.secondary,
          onPressed: () => showError(context, "Couldn't save. Try again."),
        ),
        AppButton(
          label: 'Confirm',
          variant: AppButtonVariant.secondary,
          onPressed: () => confirm(
            context,
            title: 'Discard changes?',
            message: 'Your edits will be lost.',
            confirmLabel: 'Discard',
          ),
        ),
        AppButton(
          label: 'Destructive',
          variant: AppButtonVariant.secondary,
          onPressed: () => confirm(
            context,
            title: 'Delete account?',
            message: 'This erases your data and cannot be undone.',
            confirmLabel: 'Delete account',
            destructive: true,
          ),
        ),
        AppButton(
          label: 'Sheet',
          variant: AppButtonVariant.secondary,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => const Padding(
              padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
              child: EmptyState(
                title: 'Bottom sheet',
                message: 'Use for short tasks that keep context.',
                icon: Icons.vertical_align_bottom,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _States extends StatelessWidget {
  const _States();

  @override
  Widget build(BuildContext context) {
    final states = <(String, Widget)>[
      ('Loading', const LoadingState()),
      (
        'Empty',
        EmptyState(
          title: 'No feedback yet',
          message: 'What you send will show up here.',
          actionLabel: 'Send feedback',
          onAction: () {},
        ),
      ),
      (
        'Offline',
        ErrorState(
          error: ApiNetworkException(
            '/gallery',
            const SocketException('offline'),
            StackTrace.empty,
          ),
          onRetry: () {},
        ),
      ),
      ('Error', ErrorState(error: StateError('demo'), onRetry: () {})),
      (
        'Sign in',
        const ErrorState(error: ApiUnauthenticatedException('/gallery')),
      ),
    ];
    return Column(
      children: [
        for (final (name, widget) in states)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.md,
                      Gap.lg,
                      0,
                    ),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  SizedBox(height: 260, child: widget),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
