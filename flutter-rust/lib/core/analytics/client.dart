/// Analytics client — the only place the analytics SDK is touched.
///
/// Widgets and providers call `track()` / `identify()` / `reset()` from here.
/// Swapping providers (PostHog → Mixpanel → Firebase Analytics → etc.) means
/// changing the body of these three functions, never the call sites.
///
/// Provider currently: NONE (skeleton). Wire one in — see README.md.
library;

import 'package:flutter/foundation.dart';

import 'events.dart';

// ─── Provider wiring (pick one, uncomment) ───────────────────────────────────
//
// PostHog (recommended default — already in pubspec.yaml):
//
//   import 'package:posthog_flutter/posthog_flutter.dart';
//
// Firebase Analytics:
//
//   import 'package:firebase_analytics/firebase_analytics.dart';
//   final _fa = FirebaseAnalytics.instance;

/// When true, analytics fires even in debug builds. Default false keeps the
/// prod event stream clean. Flip via dart-define for local QA:
///
///   flutter run --dart-define=ANALYTICS_IN_DEV=true
const _analyticsInDev = bool.fromEnvironment('ANALYTICS_IN_DEV');

bool get _shouldDropInDev => kDebugMode && !_analyticsInDev;

// ─── Public API ──────────────────────────────────────────────────────────────

/// Fire a typed event. The event must extend `AppEvent` — anything else fails
/// to compile.
Future<void> track(AppEvent event) async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] ${event.name} ${event.props}');
    return;
  }

  // Provider call goes here. Example (PostHog):
  //
  // await Posthog().capture(
  //   eventName: event.name,
  //   properties: event.props,
  // );
}

/// Associate subsequent events with a user. Call on sign-up + sign-in.
/// `uid` is the Firebase Auth uid — never an email or name.
Future<void> identify(String uid, [UserProperties? properties]) async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] identify $uid ${properties?.toMap()}');
    return;
  }

  // await Posthog().identify(
  //   userId: uid,
  //   userProperties: properties?.toMap(),
  // );
}

/// Disassociate the current device from a user. Call on sign-out.
/// Without this, subsequent anonymous events incorrectly attribute to the
/// prior user.
Future<void> reset() async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] reset');
    return;
  }

  // await Posthog().reset();
}
