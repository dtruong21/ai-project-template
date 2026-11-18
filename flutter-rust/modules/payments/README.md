# Payments module

In-app subscriptions and one-time unlocks through the App Store and Google Play, using [RevenueCat](https://www.revenuecat.com). The stores take the payment, RevenueCat validates the receipt, and **this Worker decides who is paid** — the app can show state but never grant it.

Use this for digital features sold inside the app (Apple and Google require their own purchase system for those). For physical goods, services or web-sold plans you would want Stripe instead; that is a different module and is not built.

## Enable

```bash
python3 modules/payments/apply.py
```

Then the one-time setup below. Until it is done, Settings → Subscription says "Purchases aren't set up yet" and everything else works normally.

## One-time setup

**1. Stores.** App Store Connect: accept the Paid Apps agreement, create your subscription(s). Google Play Console: create the subscription(s) (needs an uploaded build). Add sandbox/license testers.

**2. RevenueCat dashboard.** Create a project, add the iOS and Android apps, import the products, then:
- create an **entitlement** named `pro` (the name must match `proEntitlement` in `lib/features/payments/application/payments_provider.dart` and the name `/v1/pro/ping` checks);
- create an **offering** `default` with your packages (monthly, annual…). The paywall shows the *current* offering.

**3. Keys.**
- Public SDK keys (they are not secret) go in `.env`: `REVENUECAT_API_KEY_IOS`, `REVENUECAT_API_KEY_ANDROID`.
- The **secret** API key (v1) goes only in the Worker:
  ```bash
  cd rust/api
  npx wrangler secret put REVENUECAT_API_KEY
  ```

**4. Webhook.** RevenueCat → Integrations → Webhooks → URL `https://<your-worker>/v1/webhooks/revenuecat`. Set the *Authorization header* to a long random value in the form `Bearer <random>`, and give the Worker the same full string:
```bash
echo "Bearer $(openssl rand -hex 32)"        # use this value in both places
npx wrangler secret put REVENUECAT_WEBHOOK_SECRET
```
The route is off (404) until that secret exists.

**5. iOS.** Xcode → Runner → Signing & Capabilities → add **In-App Purchase**. `apply.py` does not edit the Xcode project.

## How a purchase flows

1. The app asks the store (via RevenueCat) to sell a package; the RevenueCat user id is the **Firebase uid**.
2. On success the app calls `POST /v1/entitlements/refresh`; the Worker asks RevenueCat for that user's state and stores it. The UI updates at once.
3. RevenueCat also sends a webhook. It is only a *nudge* ("this user changed"): the Worker never trusts the event's content, it re-reads the user's state from RevenueCat. So duplicate, late and out-of-order events cannot leave it wrong, and a failed lookup returns 500 so RevenueCat retries.
4. Gate features on the server: `payments::has_entitlement(&env, &uid, "pro")`. `GET /v1/pro/ping` is the example — copy its shape, then delete it.

| Route | Who | Does |
|---|---|---|
| `GET /v1/entitlements` | signed-in user | the caller's entitlements |
| `POST /v1/entitlements/refresh` | signed-in user | re-read from RevenueCat now (throttled to once per 5 s) |
| `GET /v1/pro/ping` | signed-in user | **example** gated route: 402 `payment_required` unless `pro` is active |
| `POST /v1/webhooks/revenuecat` | RevenueCat | shared-secret header; off until the secret is set |

## Security

- The client cannot grant itself anything: no route accepts an entitlement from it.
- "Active" is computed from the expiry **when read**, so an expiry takes effect even if its webhook is lost. A lifetime unlock has no expiry; an expiry the Worker cannot parse counts as already expired, never as forever. A billing-retry grace period keeps access.
- The webhook secret is compared in constant time. The RevenueCat secret key lives only in a Worker secret.
- Sandbox purchases count as real ones. That is deliberate: App Review tests with sandbox accounts.
- `REVENUECAT_BASE_URL` exists only so `api_test.py` can point the Worker at a fake. Never set it on a deployed Worker.

## Account deletion

Deleting the account removes the user's entitlements here and erases their record at RevenueCat (best effort; a failure is logged and never blocks the deletion). **It does not cancel a store subscription** — only the user can, in their App Store or Google Play account. Say so in your delete-account confirmation text if the user may have one; stores expect it.

## App Review checklist (the code covers the first three)

- [x] "Restore purchases" button
- [x] Price and period shown before buying
- [x] Auto-renewal disclosure text under the plans
- [ ] Links to your Terms of Use and Privacy Policy on the paywall (add yours)
- [ ] Subscription terms match what the store listing says

## Ceilings

- One entitlement name (`pro`) is wired through the example. More are fine: add names in RevenueCat and gate with `has_entitlement`.
- No consumable credits, promo-code UI, intro-offer messaging, paywall experiments, or Stripe/web checkout.
- A webhook that arrives after the account was deleted can recreate rows for that uid while RevenueCat still knows the subscription. Harmless (that uid no longer exists), but they are orphans.
- The refresh route lets a signed-in user trigger one RevenueCat lookup per 5 s for themselves.

## Verified

Applied (together with the files and push modules) to a copy of the template: 40 shared + 14 core Rust tests, 72 Flutter tests, and 176 API end-to-end checks (49 for this module) pass. The end-to-end tests run against a strict fake of RevenueCat's REST API (it requires the secret key and records every call). They cover: webhook credentials; a purchase becoming access; a stale event unable to revive an expired entitlement; duplicate events; expiry with no webhook; lifetime, grace period and unreadable dates; ignored (test, anonymous) events; transfers; RevenueCat failing; the refresh throttle; the app being unable to grant itself access; and account deletion. Breaking the expiry computation, the webhook authentication, the RevenueCat cleanup or the entitlement deletion on purpose makes the matching checks fail.

**Not verified:** a real RevenueCat project, the App Store or Google Play (no real purchase, sandbox or otherwise), the paywall against real products, the In-App Purchase capability, and the Android purchase flow. `payments_platform.dart` compiles against `purchases_flutter` but is exercised only through a fake.
