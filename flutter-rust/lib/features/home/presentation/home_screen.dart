/// Starter home screen. It exists to prove the stack is wired: it shows live
/// status for the three moving parts (Rust bridge, Firebase, API) and opens
/// the feedback sheet, which exercises the full path to the database.
///
/// Replace the body with your product's home once `/design` has a spec —
/// keep the feedback entry point somewhere reachable.
library;

import 'package:app/core/api/api_client.dart';
import 'package:app/core/bootstrap.dart';
import 'package:app/features/feedback/presentation/feedback_sheet.dart';
import 'package:app/src/rust/api/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Proves the Rust library is loaded: asks Rust to validate a known-good
/// payload. Any failure here means the bridge is broken, not the input.
final _rustBridgeOkProvider = Provider<bool>((ref) {
  try {
    buildFeedbackPayload(
      category: 'other',
      body: 'bridge check',
      route: '/',
      appVersion: '0',
      platform: 'check',
    );
    return true;
  } on Object {
    return false;
  }
});

final FutureProvider<bool> _apiReachableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(apiClientProvider).isReachable(),
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final api = ref.watch(_apiReachableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_apiReachableProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('It runs.', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Flutter UI, Rust logic, Worker API. Pull down to re-check.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  _StatusTile(
                    label: 'Rust bridge',
                    ok: ref.watch(_rustBridgeOkProvider),
                    okText: 'loaded',
                    failText: 'not loaded — rebuild the app',
                  ),
                  const Divider(height: 1),
                  _StatusTile(
                    label: 'Firebase Auth',
                    ok: ref.watch(firebaseReadyProvider),
                    okText: 'configured',
                    failText: 'not configured — run flutterfire configure',
                  ),
                  const Divider(height: 1),
                  _StatusTile(
                    label: 'API',
                    ok: api.value,
                    okText: 'reachable',
                    failText: 'unreachable — start wrangler dev',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showFeedbackSheet(context, route: '/'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.ok,
    required this.okText,
    required this.failText,
  });

  final String label;

  /// `null` while checking.
  final bool? ok;
  final String okText;
  final String failText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = this.ok;
    return ListTile(
      title: Text(label),
      subtitle: Text(
        ok == null ? 'checking…' : (ok ? okText : failText),
      ),
      // Icon shape differs as well as color — status must not rely on color.
      trailing: ok == null
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? scheme.primary : scheme.error,
              semanticLabel: ok ? 'OK' : 'Problem',
            ),
    );
  }
}
