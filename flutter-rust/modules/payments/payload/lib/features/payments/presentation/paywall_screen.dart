import 'package:app/core/ui/ui.dart';
import 'package:app/features/payments/application/payments_platform.dart';
import 'package:app/features/payments/application/payments_provider.dart';
import 'package:app/src/rust/api/payments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Subscription screen: what the user has, what they can buy, restore.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// The package being bought, or `'restore'`. Locks every button meanwhile.
  String? _busy;

  Future<void> _run(String busyKey, Future<void> Function() action) async {
    setState(() => _busy = busyKey);
    try {
      await action();
      if (mounted) showMessage(context, 'Thank you!');
    } on PurchaseCancelled {
      // The user changed their mind: say nothing.
    } on PurchaseNotConfirmed {
      // Money moved, our server has not caught up. Never call this a failure.
      if (mounted) {
        showMessage(
          context,
          'Your purchase went through. It may take a moment to appear — pull down to refresh.',
        );
      }
    } on PaymentsFailure catch (e) {
      if (mounted) showError(context, e.message);
    } on Object {
      if (mounted)
        showError(
          context,
          "Something went wrong. You were not charged twice — try again.",
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = ref.watch(paymentsPlatformProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final packages = ref.watch(paywallProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: platform == null
          ? const StateView(
              icon: Icons.storefront_outlined,
              title: "Purchases aren't set up yet",
              message:
                  'Add your RevenueCat key to .env and finish the Firebase setup. '
                  'See modules/payments/README.md.',
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(paywallProvider);
                return ref.refresh(entitlementsProvider.future);
              },
              child: AsyncValueView(
                value: packages,
                onRetry: () => ref.invalidate(paywallProvider),
                isEmpty: (items) => items.isEmpty,
                empty: const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No plans available right now',
                  message: 'Try again in a moment.',
                ),
                data: (items) => ListView(
                  padding: const EdgeInsets.all(Gap.lg),
                  children: [
                    _Status(entitlements: entitlements),
                    const SizedBox(height: Gap.lg),
                    for (final package in items) ...[
                      _PackageCard(
                        package: package,
                        busy: _busy == package.id,
                        locked: _busy != null,
                        onBuy: () => _run(
                          package.id,
                          () => ref
                              .read(paywallProvider.notifier)
                              .purchase(package.id),
                        ),
                      ),
                      const SizedBox(height: Gap.md),
                    ],
                    AppButton(
                      label: 'Restore purchases',
                      variant: AppButtonVariant.text,
                      expand: true,
                      loading: _busy == 'restore',
                      onPressed: _busy != null
                          ? null
                          : () => _run(
                              'restore',
                              () =>
                                  ref.read(paywallProvider.notifier).restore(),
                            ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Text(
                      // Required by the stores for auto-renewing subscriptions.
                      'Payment is charged to your Apple ID or Google Play account at '
                      'confirmation. Subscriptions renew automatically unless cancelled '
                      'at least 24 hours before the end of the current period. Manage or '
                      'cancel anytime in your account settings.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: UiTokens.of(context).muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.entitlements});

  final AsyncValue<List<EntitlementItem>> entitlements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = UiTokens.of(context).muted;
    final items = entitlements.value;
    final pro = items
        ?.where((e) => e.name == proEntitlement && e.active)
        .firstOrNull;

    if (entitlements.hasError && items == null) {
      return Text(
        "Couldn't check your current plan.",
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      );
    }
    if (pro == null) {
      return Text('Choose a plan', style: theme.textTheme.titleLarge);
    }
    final expires = pro.expiresAt?.toInt();
    return Card(
      child: ListTile(
        leading: Icon(Icons.check_circle, color: UiTokens.of(context).success),
        title: const Text("You're subscribed"),
        subtitle: Text(
          expires == null
              ? 'Never expires'
              : 'Renews or ends ${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(expires * 1000))}',
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.busy,
    required this.locked,
    required this.onBuy,
  });

  final PaywallPackage package;
  final bool busy;
  final bool locked;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(package.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              package.period == null
                  ? package.price
                  : '${package.price} · ${package.period}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: UiTokens.of(context).muted,
              ),
            ),
            const SizedBox(height: Gap.md),
            AppButton(
              label: 'Subscribe',
              expand: true,
              loading: busy,
              onPressed: locked ? null : onBuy,
            ),
          ],
        ),
      ),
    );
  }
}
