import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/payments/application/payments_platform.dart';
import 'package:app/src/rust/api/payments.dart' as rust;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payments_provider.g.dart';

/// The entitlement your products unlock. Must match the entitlement id in the
/// RevenueCat dashboard and the name the Worker checks (`/v1/pro/ping`).
const proEntitlement = 'pro';

/// Parses the Worker's response with the Rust types. A provider so tests can
/// replace it (they cannot load the Rust library).
final entitlementParserProvider =
    Provider<List<rust.EntitlementItem> Function(String)>(
      (ref) =>
          (json) => rust.parseEntitlements(json: json),
    );

bool hasActive(List<rust.EntitlementItem> items, String name) =>
    items.any((e) => e.name == name && e.active);

/// What the Worker says this user has paid for. The Worker is the source of
/// truth — this only displays it; never unlock a feature from the app alone.
@riverpod
class Entitlements extends _$Entitlements {
  @override
  Future<List<rust.EntitlementItem>> build() async {
    final body = await ref.watch(apiClientProvider).getJson('/v1/entitlements');
    return ref.read(entitlementParserProvider)(body);
  }

  /// Asks the Worker to re-read from RevenueCat — right after a purchase or
  /// restore, so the UI need not wait for the webhook. Throws on failure and
  /// leaves what is shown as it was.
  Future<void> refresh() async {
    final body = await ref
        .read(apiClientProvider)
        .postJson('/v1/entitlements/refresh', '{}');
    state = AsyncData(ref.read(entitlementParserProvider)(body));
  }
}

/// The store's options for this user, and the actions on them.
@riverpod
class Paywall extends _$Paywall {
  @override
  Future<List<PaywallPackage>> build() async {
    final platform = ref.watch(paymentsPlatformProvider);
    if (platform == null) return const [];
    final uid = ref.watch(currentUidProvider);
    if (uid == null) throw const ApiUnauthenticatedException('/paywall');
    await platform.logIn(uid);
    return platform.packages();
  }

  /// Buys, then has the Worker confirm. Throws [PurchaseCancelled] if the user
  /// backs out. If the store took the payment but confirming failed, throws
  /// [PurchaseNotConfirmed] — the purchase is real and the webhook will still
  /// deliver it; the UI must say so rather than "failed".
  Future<void> purchase(String packageId) async {
    final platform = ref.read(paymentsPlatformProvider)!;
    await platform.purchase(packageId);
    await _confirm();
  }

  Future<void> restore() async {
    await ref.read(paymentsPlatformProvider)!.restore();
    await _confirm();
  }

  Future<void> _confirm() async {
    try {
      await ref.read(entitlementsProvider.notifier).refresh();
    } on ApiException {
      throw const PurchaseNotConfirmed();
    }
  }
}

/// The store succeeded but the Worker could not confirm yet.
class PurchaseNotConfirmed implements Exception {
  const PurchaseNotConfirmed();
}
