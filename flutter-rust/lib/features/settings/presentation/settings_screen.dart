import 'package:app/app.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/settings/application/account_actions.dart';
import 'package:app/features/settings/application/profile_provider.dart';
import 'package:app/features/settings/presentation/profile_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: const [
          _ProfileCard(),
          SizedBox(height: Gap.lg),
          _LinksCard(),
          SizedBox(height: Gap.lg),
          _AppearanceCard(),
          SizedBox(height: Gap.xxl),
          _DangerZone(),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // A one-row card: the full-screen state views don't fit, so each state
    // is a row of the same height — the card never jumps or clips.
    final row = switch (profile) {
      AsyncValue(hasValue: true, :final value) => ListTile(
        leading: AppAvatar(name: value?.displayName ?? ''),
        title: Text(value?.displayName ?? 'Add your name'),
        subtitle: Text(value == null ? 'Not set yet' : 'Tap to edit'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showProfileEditSheet(context, current: value?.displayName),
      ),
      AsyncValue(:final error?) => ListTile(
        leading: Icon(
          error is ApiUnauthenticatedException
              ? Icons.lock_outline
              : Icons.error_outline,
        ),
        title: Text(switch (error) {
          ApiUnauthenticatedException() => 'Sign in to set your name',
          ApiNetworkException() => "Can't reach the server",
          _ => "Couldn't load your profile",
        }),
        subtitle: error is ApiUnauthenticatedException
            ? null
            : const Text('Tap to try again'),
        onTap: error is ApiUnauthenticatedException
            ? null
            : () => ref.invalidate(profileProvider),
      ),
      _ => const ListTile(
        leading: SizedBox.square(
          dimension: 40,
          child: Padding(
            padding: EdgeInsets.all(Gap.sm),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Text('Loading your profile'),
      ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Center(child: row),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('My feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/feedback'),
          ),
          // modules: settings-links
        ],
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Gap.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {ref.watch(themeModeProvider)},
                onSelectionChanged: (selection) =>
                    ref.read(themeModeProvider.notifier).set(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends ConsumerStatefulWidget {
  const _DangerZone();

  @override
  ConsumerState<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends ConsumerState<_DangerZone> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await confirm(
      context,
      title: 'Delete account?',
      message:
          'This permanently erases your profile and everything you have '
          'sent. It cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(deleteAccountProvider)();
      if (mounted) showMessage(context, 'Your account was deleted.');
    } on ApiUnauthenticatedException {
      if (mounted) showError(context, 'Sign in to delete your account.');
    } on ApiNetworkException {
      if (mounted) {
        showError(context, "Can't reach the server. Nothing was deleted.");
      }
    } on Exception {
      if (mounted) {
        showError(context, "Couldn't delete your account. Try again.");
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Erases your profile and all data you have sent.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: UiTokens.of(context).muted,
          ),
        ),
        const SizedBox(height: Gap.sm),
        AppButton(
          label: 'Delete account',
          variant: AppButtonVariant.danger,
          loading: _deleting,
          onPressed: _delete,
        ),
      ],
    );
  }
}
