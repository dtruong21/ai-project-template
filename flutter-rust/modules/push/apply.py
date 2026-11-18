#!/usr/bin/env python3
"""Turn on the push module (Firebase Cloud Messaging) in this project.

    python3 modules/push/apply.py [--no-codegen]

Safe to run twice. See modules/push/README.md for the one-time Firebase,
Apple and Worker-secret setup this cannot do for you.

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
m.patch("rust/shared/src/lib.rs", "// modules: shared", "pub mod push;\n", "pub mod push;")
m.patch("rust/api/src/lib.rs", "// modules: mods", "mod push;\n", "mod push;")
m.patch(
    "rust/api/src/lib.rs", "// modules: routes",
    '        .put_async("/v1/push/token", push::register)\n'
    '        .delete_async("/v1/push/token", push::unregister)\n'
    '        .post_async("/v1/admin/push", push::admin_send)\n',
    '"/v1/push/token"',
)
m.patch("rust/api/src/account.rs", "// modules: user-tables", '    "DELETE FROM push_tokens WHERE uid = ?1",\n', "DELETE FROM push_tokens")
m.patch("rust/core/src/api/mod.rs", "// modules: core", "pub mod push;\n", "pub mod push;")
m.patch(
    "lib/features/settings/presentation/settings_screen.dart", "// modules: settings-links",
    "          const Divider(height: 1),\n          const PushSettingsTile(),\n",
    "PushSettingsTile()",
)
m.patch(
    "lib/features/settings/presentation/settings_screen.dart",
    "import 'package:app/features/settings/application/account_actions.dart';",
    "import 'package:app/features/push/presentation/push_settings_tile.dart';\n",
    "push_settings_tile.dart", where="before",
)
m.patch("rust/api/tests/api_test.py", "# modules: setup", m.snippet("api_test_setup.py"), "fake_fcm")
m.patch("rust/api/tests/api_test.py", "# modules: tests", m.snippet("api_test_block.py"), 'print("push module")')
m.patch("rust/api/tests/api_test.py", "# modules: teardown", m.snippet("api_test_teardown.py"), '"fcm" in MODULE_STATE')

# Signing the service-account JWT needs the PEM key parser.
m.replace("rust/api/Cargo.toml", 'features = ["rust_crypto"]', 'features = ["rust_crypto", "use_pem"]', "use_pem")
# Android 13+ asks for this permission at runtime; it must be declared first.
m.patch(
    "android/app/src/main/AndroidManifest.xml", "android.permission.INTERNET",
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n',
    "POST_NOTIFICATIONS",
)

m.pub_add("firebase_messaging", keep_in_step=("firebase_core", "firebase_auth"))
m.codegen()

print("\nPush module is on. Next:")
print("  (cd rust && cargo test) && (cd rust/core && cargo test)")
print("  (cd rust/api && python3 tests/api_test.py)")
print("  flutter test")
print("Then the one-time setup in modules/push/README.md (Firebase, Apple, secrets).")
