#!/usr/bin/env python3
"""Turn on the files module (R2 uploads) in this project.

    python3 modules/files/apply.py [--no-codegen]

Safe to run twice: every step checks whether it is already done. It changes
only the places marked `// modules: <name>` in the core (plus pubspec.yaml,
wrangler.toml and one new migration), and never overwrites a file you edited
(a file that already exists is left alone and reported).

After it runs:
    npx wrangler r2 bucket create app-files        # once, before deploying
    (cd rust && cargo test) ; (cd rust/core && cargo test)
    (cd rust/api && python3 tests/api_test.py)
    flutter test
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # project root (the folder with pubspec.yaml)
PAYLOAD = HERE / "payload"
SNIPPETS = HERE / "snippets"


def say(message: str) -> None:
    print(f"  {message}")


def fail(message: str) -> None:
    sys.exit(f"\nERROR: {message}\n")


def copy_payload() -> None:
    print("copying files")
    for source in sorted(PAYLOAD.rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(PAYLOAD)
        if relative.parts[-2:] == ("migrations", "files.sql"):
            continue  # handled below: needs a number
        target = ROOT / relative
        if target.exists():
            if target.read_bytes() == source.read_bytes():
                say(f"= {relative} (already there)")
                continue
            say(f"! {relative} differs from the module's copy — kept yours")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        say(f"+ {relative}")

    migrations = ROOT / "rust/api/migrations"
    if any(path.name.endswith("_files.sql") for path in migrations.glob("*.sql")):
        say("= migration (already there)")
        return
    numbers = [int(m.group(1)) for p in migrations.glob("*.sql") if (m := re.match(r"(\d+)_", p.name))]
    name = f"{max(numbers, default=0) + 1:04d}_files.sql"
    shutil.copyfile(PAYLOAD / "rust/api/migrations/files.sql", migrations / name)
    say(f"+ rust/api/migrations/{name}")


# (file, marker, text to insert after the marker line, sentinel that means "done")
PATCHES = [
    ("rust/shared/src/lib.rs", "// modules: shared", "pub mod files;\n", "pub mod files;"),
    ("rust/api/src/lib.rs", "// modules: mods", "mod files;\n", "mod files;"),
    (
        "rust/api/src/lib.rs",
        "// modules: routes",
        '        .post_async("/v1/files", files::create)\n'
        '        .get_async("/v1/files", files::list)\n'
        '        .get_async("/v1/files/:id", files::get)\n'
        '        .delete_async("/v1/files/:id", files::delete)\n',
        '"/v1/files"',
    ),
    ("rust/api/src/account.rs", "// modules: user-tables", '    "DELETE FROM files WHERE uid = ?1",\n', "DELETE FROM files"),
    (
        "rust/api/src/account.rs",
        "// modules: before-delete",
        "    // Files module: R2 objects first, so a failure leaves nothing half-deleted.\n"
        "    crate::files::purge_user(&ctx.env, &uid).await?;\n",
        "files::purge_user",
    ),
    ("rust/core/src/api/mod.rs", "// modules: core", "pub mod files;\n", "pub mod files;"),
    (
        "lib/features/settings/presentation/settings_screen.dart",
        "// modules: settings-links",
        "          const Divider(height: 1),\n"
        "          ListTile(\n"
        "            leading: const Icon(Icons.folder_outlined),\n"
        "            title: const Text('My files'),\n"
        "            trailing: const Icon(Icons.chevron_right),\n"
        "            onTap: () => context.push('/settings/files'),\n"
        "          ),\n",
        "/settings/files",
    ),
    (
        "lib/core/routing/router.dart",
        "// modules: routes",
        "      GoRoute(\n"
        "        path: '/settings/files',\n"
        "        builder: (context, state) => const FilesScreen(),\n"
        "      ),\n",
        "FilesScreen()",
    ),
    ("rust/api/tests/api_test.py", "# modules: tests", (SNIPPETS / "api_test_block.py").read_text(), 'print("files module")'),
]


def patch(file: str, marker: str, text: str, sentinel: str) -> None:
    path = ROOT / file
    source = path.read_text()
    if sentinel in source:
        say(f"= {file} ({marker.split(': ')[1]}: already done)")
        return
    lines = source.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if marker in line:
            lines[index + 1 : index + 1] = [text]
            path.write_text("".join(lines))
            say(f"~ {file} ({marker.split(': ')[1]})")
            return
    fail(f"marker `{marker}` not found in {file}. Was the core edited? "
         "Add the marker back (see another module's patch) and rerun.")


def patch_router_import() -> None:
    path = ROOT / "lib/core/routing/router.dart"
    source = path.read_text()
    line = "import 'package:app/features/files/presentation/files_screen.dart';\n"
    if line in source:
        return
    anchor = "import 'package:app/features/gallery/gallery_screen.dart';\n"
    if anchor not in source:
        fail("router.dart import anchor not found; add the FilesScreen import by hand.")
    path.write_text(source.replace(anchor, line + anchor, 1))
    say("~ lib/core/routing/router.dart (import)")


def patch_wrangler() -> None:
    path = ROOT / "rust/api/wrangler.toml"
    if 'binding = "FILES"' in path.read_text():
        say("= rust/api/wrangler.toml (R2 binding already there)")
        return
    with path.open("a") as handle:
        handle.write((SNIPPETS / "wrangler_r2.toml").read_text())
    say("~ rust/api/wrangler.toml (R2 binding)")


def run(command: list[str], cwd: Path = ROOT) -> None:
    say("$ " + " ".join(command))
    if subprocess.run(command, cwd=cwd).returncode != 0:
        fail(f"`{' '.join(command)}` failed.")


def main() -> None:
    if not (ROOT / "pubspec.yaml").exists() or not (ROOT / "rust/api/wrangler.toml").exists():
        fail(f"{ROOT} does not look like a project made from the flutter-rust template.")

    copy_payload()
    print("patching the core")
    for entry in PATCHES:
        patch(*entry)
    patch_router_import()
    patch_wrangler()

    if "image_picker" not in (ROOT / "pubspec.yaml").read_text():
        print("adding the image picker")
        run(["flutter", "pub", "add", "image_picker"])

    if "--no-codegen" not in sys.argv:
        print("generating code")
        run(["flutter_rust_bridge_codegen", "generate"])
        run(["dart", "run", "build_runner", "build"])

    print("\nFiles module is on. Next:")
    print("  npx wrangler r2 bucket create app-files     # once, before deploying")
    print("  (cd rust && cargo test) && (cd rust/core && cargo test)")
    print("  (cd rust/api && python3 tests/api_test.py)")
    print("  flutter test")


if __name__ == "__main__":
    main()
