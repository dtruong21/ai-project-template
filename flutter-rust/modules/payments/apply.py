#!/usr/bin/env python3
"""Turn on the payments module (RevenueCat subscriptions) in this project.

    python3 modules/payments/apply.py [--no-codegen]

Safe to run twice. See modules/payments/README.md for the one-time
RevenueCat, App Store and Google Play setup this cannot do for you.

After it runs:
    (cd rust && cargo test) ; (cd rust/core && cargo test)
    (cd rust/api && python3 tests/api_test.py)
    flutter test
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from apply_lib import Module  # noqa: E402

m = Module(Path(__file__).resolve().parent)
m.check_root()
m.copy_payload()

print("patching the core")
m.patch("rust/shared/src/lib.rs", "// modules: shared", "pub mod payments;\n", "pub mod payments;")
m.patch("rust/api/src/lib.rs", "// modules: mods", "mod payments;\n", "mod payments;")
m.patch(
    "rust/api/src/lib.rs", "// modules: routes",
    '        .get_async("/v1/entitlements", payments::list)\n'
    '        .post_async("/v1/entitlements/refresh", payments::refresh)\n'
    '        .get_async("/v1/pro/ping", payments::pro_ping)\n'
    '        .post_async("/v1/webhooks/revenuecat", payments::webhook)\n',
    '"/v1/entitlements"',
)
m.patch(
    "rust/api/src/account.rs", "// modules: user-tables",
    '    "DELETE FROM entitlements WHERE uid = ?1",\n    "DELETE FROM customers WHERE uid = ?1",\n',
    "DELETE FROM entitlements",
)
m.patch(
    "rust/api/src/account.rs", "// modules: before-delete",
    "    // Payments module: erase the user at RevenueCat (best effort; never blocks).\n"
    "    crate::payments::forget_user(&ctx.env, &uid).await;\n",
    "payments::forget_user",
)
m.patch("rust/core/src/api/mod.rs", "// modules: core", "pub mod payments;\n", "pub mod payments;")
m.patch(
    "lib/features/settings/presentation/settings_screen.dart", "// modules: settings-links",
    "          const Divider(height: 1),\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.workspace_premium_outlined),\n"
    "            title: const Text('Subscription'),\n"
    "            trailing: const Icon(Icons.chevron_right),\n"
    "            onTap: () => context.push('/settings/subscription'),\n"
    "          ),\n",
    "/settings/subscription",
)
m.patch(
    "lib/core/routing/router.dart", "// modules: routes",
    "      GoRoute(\n        path: '/settings/subscription',\n        builder: (context, state) => const PaywallScreen(),\n      ),\n",
    "PaywallScreen()",
)
m.patch(
    "lib/core/routing/router.dart", "import 'package:app/features/settings/presentation/settings_screen.dart';",
    "import 'package:app/features/payments/presentation/paywall_screen.dart';\n",
    "paywall_screen.dart", where="before",
)
m.patch("rust/api/tests/api_test.py", "# modules: setup", m.snippet("api_test_setup.py"), "fake_revenuecat")
m.patch("rust/api/tests/api_test.py", "# modules: tests", m.snippet("api_test_block.py"), 'print("payments module")')
m.patch("rust/api/tests/api_test.py", "# modules: teardown", m.snippet("api_test_teardown.py"), '"rc" in MODULE_STATE')

# The public SDK keys the app needs (safe to bundle: they are not secret).
env_lines = "\n# Payments module — RevenueCat PUBLIC SDK keys (RevenueCat → Project → API keys).\nREVENUECAT_API_KEY_IOS=\nREVENUECAT_API_KEY_ANDROID=\n"
for env_file in (".env.example", ".env"):
    if (m.root / env_file).exists():
        m.append_once(env_file, env_lines, "REVENUECAT_API_KEY_IOS")

m.pub_add("purchases_flutter")
m.codegen()

print("\nPayments module is on. Next:")
print("  (cd rust && cargo test) && (cd rust/core && cargo test)")
print("  (cd rust/api && python3 tests/api_test.py)")
print("  flutter test")
print("Then the one-time setup in modules/payments/README.md (RevenueCat, stores, secrets).")
