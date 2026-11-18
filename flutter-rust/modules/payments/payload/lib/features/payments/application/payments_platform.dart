import 'package:app/core/bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// One thing the user can buy, as the store describes it.
class PaywallPackage {
  const PaywallPackage({
    required this.id,
    required this.title,
    required this.price,
    this.period,
  });

  final String id;
  final String title;

  /// Already formatted and localized by the store ("$4.99").
  final String price;

  /// "monthly", "annual", "lifetime"… or `null` when the store gave none.
  final String? period;
}

sealed class PaymentsException implements Exception {
  const PaymentsException();
}

/// The user backed out of the store sheet. Not an error: show nothing.
class PurchaseCancelled extends PaymentsException {
  const PurchaseCancelled();
}

/// A failure with words the user can act on.
class PaymentsFailure extends PaymentsException {
  const PaymentsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The slice of RevenueCat the app uses. An interface so the screens and
/// controllers can be tested without the store (which needs a device).
abstract interface class PaymentsPlatform {
  /// Ties purchases to this user. Call before anything else; safe to repeat.
  Future<void> logIn(String uid);

  Future<List<PaywallPackage>> packages();

  /// Throws [PurchaseCancelled] if the user backs out, [PaymentsFailure] on
  /// any other problem.
  Future<void> purchase(String packageId);

  /// For a user who reinstalled or changed phone and already paid.
  Future<void> restore();
}

class RevenueCatPlatform implements PaymentsPlatform {
  RevenueCatPlatform(this._apiKey);

  final String _apiKey;
  bool _configured = false;
  String? _uid;
  final _packages = <String, Package>{};

  @override
  Future<void> logIn(String uid) async {
    if (!_configured) {
      // The RevenueCat user id IS the Firebase uid: that is how the Worker
      // knows whose purchase a webhook is about.
      await Purchases.configure(
        PurchasesConfiguration(_apiKey)..appUserID = uid,
      );
      _configured = true;
      _uid = uid;
    } else if (_uid != uid) {
      await Purchases.logIn(uid);
      _uid = uid;
    }
  }

  @override
  Future<List<PaywallPackage>> packages() async {
    try {
      final current = (await Purchases.getOfferings()).current;
      if (current == null) return const [];
      _packages
        ..clear()
        ..addEntries(
          current.availablePackages.map((p) => MapEntry(p.identifier, p)),
        );
      return [
        for (final p in current.availablePackages)
          PaywallPackage(
            id: p.identifier,
            title: p.storeProduct.title,
            price: p.storeProduct.priceString,
            period: switch (p.packageType) {
              PackageType.monthly => 'monthly',
              PackageType.annual => 'annual',
              PackageType.weekly => 'weekly',
              PackageType.lifetime => 'lifetime',
              _ => null,
            },
          ),
      ];
    } on PlatformException catch (e) {
      throw PaymentsFailure(_message(e));
    }
  }

  @override
  Future<void> purchase(String packageId) async {
    final package = _packages[packageId];
    if (package == null) {
      throw const PaymentsFailure('That option is no longer available.');
    }
    try {
      await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelled();
      }
      throw PaymentsFailure(_message(e));
    }
  }

  @override
  Future<void> restore() async {
    try {
      await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      throw PaymentsFailure(_message(e));
    }
  }

  static String _message(
    PlatformException e,
  ) => switch (PurchasesErrorHelper.getErrorCode(e)) {
    PurchasesErrorCode.networkError =>
      "Can't reach the store. Check your connection and try again.",
    PurchasesErrorCode.paymentPendingError =>
      'Your payment is waiting for approval. You will get access once it clears.',
    PurchasesErrorCode.productAlreadyPurchasedError =>
      'You already own this. Try "Restore purchases".',
    PurchasesErrorCode.purchaseNotAllowedError =>
      'Purchases are not allowed on this device.',
    _ => "Something went wrong with the store. Try again.",
  };
}

/// `null` until Firebase is configured AND this platform's RevenueCat public
/// SDK key is in `.env` (`REVENUECAT_API_KEY_IOS` / `_ANDROID`). The screen
/// then says purchases aren't set up instead of crashing.
final paymentsPlatformProvider = Provider<PaymentsPlatform?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final key = switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.macOS => dotenv.env['REVENUECAT_API_KEY_IOS'],
    TargetPlatform.android => dotenv.env['REVENUECAT_API_KEY_ANDROID'],
    _ => null,
  };
  if (key == null || key.isEmpty) return null;
  return RevenueCatPlatform(key);
});

/// The signed-in Firebase uid; `null` when nobody is. Rebuilds dependents when
/// the signed-in user changes (sign-out, account deletion, a new anonymous user).
final currentUidProvider = Provider<String?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  // The stream's first event repeats the current user: skip it, or this
  // provider would invalidate itself forever.
  final changes = FirebaseAuth.instance
      .authStateChanges()
      .skip(1)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  return FirebaseAuth.instance.currentUser?.uid;
});
