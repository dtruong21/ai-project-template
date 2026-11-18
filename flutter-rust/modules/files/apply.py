#!/usr/bin/env python3
"""Turn on the files module (R2 uploads) in this project.

    python3 modules/files/apply.py [--no-codegen]

Safe to run twice. It changes only the places marked `// modules: <name>` in
the core (plus pubspec.yaml, wrangler.toml and one new migration) and never
overwrites a file you edited. See modules/README.md.

After it runs:
    npx wrangler r2 bucket create app-files        # once, before deploying
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
m.patch("rust/shared/src/lib.rs", "// modules: shared", "pub mod files;\n", "pub mod files;")
m.patch("rust/api/src/lib.rs", "// modules: mods", "mod files;\n", "mod files;")
m.patch(
    "rust/api/src/lib.rs", "// modules: routes",
    '        .post_async("/v1/files", files::create)\n'
    '        .get_async("/v1/files", files::list)\n'
    '        .get_async("/v1/files/:id", files::get)\n'
    '        .delete_async("/v1/files/:id", files::delete)\n',
    '"/v1/files"',
)
m.patch("rust/api/src/account.rs", "// modules: user-tables", '    "DELETE FROM files WHERE uid = ?1",\n', "DELETE FROM files")
m.patch(
    "rust/api/src/account.rs", "// modules: before-delete",
    "    // Files module: R2 objects first, so a failure leaves nothing half-deleted.\n"
    "    crate::files::purge_user(&ctx.env, &uid).await?;\n",
    "files::purge_user",
)
m.patch("rust/core/src/api/mod.rs", "// modules: core", "pub mod files;\n", "pub mod files;")
m.patch(
    "lib/features/settings/presentation/settings_screen.dart", "// modules: settings-links",
    "          const Divider(height: 1),\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.folder_outlined),\n"
    "            title: const Text('My files'),\n"
    "            trailing: const Icon(Icons.chevron_right),\n"
    "            onTap: () => context.push('/settings/files'),\n"
    "          ),\n",
    "/settings/files",
)
m.patch(
    "lib/core/routing/router.dart", "// modules: routes",
    "      GoRoute(\n        path: '/settings/files',\n        builder: (context, state) => const FilesScreen(),\n      ),\n",
    "FilesScreen()",
)
m.patch(
    "lib/core/routing/router.dart", "import 'package:app/features/gallery/gallery_screen.dart';",
    "import 'package:app/features/files/presentation/files_screen.dart';\n",
    "files_screen.dart", where="before",
)
m.patch("rust/api/tests/api_test.py", "# modules: tests", m.snippet("api_test_block.py"), 'print("files module")')
m.append_once("rust/api/wrangler.toml", m.snippet("wrangler_r2.toml"), 'binding = "FILES"')

m.pub_add("image_picker")
m.codegen()

print("\nFiles module is on. Next:")
print("  npx wrangler r2 bucket create app-files     # once, before deploying")
print("  (cd rust && cargo test) && (cd rust/core && cargo test)")
print("  (cd rust/api && python3 tests/api_test.py)")
print("  flutter test")
