"""Shared machinery for `modules/<name>/apply.py`.

A module's apply.py only declares WHAT to change; this does it, safely:
idempotent (every step checks whether it is already done), never overwrites a
file that exists, and stops with a clear message when an anchor is missing.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path


def say(message: str) -> None:
    print(f"  {message}")


def fail(message: str) -> None:
    sys.exit(f"\nERROR: {message}\n")


class Module:
    def __init__(self, here: Path):
        self.name = here.name
        self.here = here
        self.root = here.parent.parent  # the project root (has pubspec.yaml)
        self.payload = here / "payload"
        self.snippets = here / "snippets"

    # -- steps ----------------------------------------------------------------

    def copy_payload(self) -> None:
        print("copying files")
        migration_source = self.payload / "rust/api/migrations" / f"{self.name}.sql"
        for source in sorted(self.payload.rglob("*")):
            if not source.is_file() or source == migration_source:
                continue
            relative = source.relative_to(self.payload)
            target = self.root / relative
            if target.exists():
                if target.read_bytes() == source.read_bytes():
                    say(f"= {relative} (already there)")
                else:
                    say(f"! {relative} differs from the module's copy — kept yours")
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            say(f"+ {relative}")

        if migration_source.exists():
            migrations = self.root / "rust/api/migrations"
            if any(p.name.endswith(f"_{self.name}.sql") for p in migrations.glob("*.sql")):
                say("= migration (already there)")
                return
            numbers = [int(m.group(1)) for p in migrations.glob("*.sql") if (m := re.match(r"(\d+)_", p.name))]
            name = f"{max(numbers, default=0) + 1:04d}_{self.name}.sql"
            shutil.copyfile(migration_source, migrations / name)
            say(f"+ rust/api/migrations/{name}")

    def patch(self, file: str, anchor: str, text: str, sentinel: str, where: str = "after") -> None:
        """Insert `text` after (or before) the line containing `anchor`,
        unless `sentinel` is already in the file."""
        path = self.root / file
        source = path.read_text()
        label = anchor.strip().removeprefix("// modules: ").removeprefix("# modules: ")[:40]
        if sentinel in source:
            say(f"= {file} ({label}: already done)")
            return
        lines = source.splitlines(keepends=True)
        for index, line in enumerate(lines):
            # A marker must be the whole comment line, so prose that merely
            # mentions it is never mistaken for it.
            is_marker = anchor.startswith(("// modules:", "# modules:"))
            if (line.strip().startswith(anchor)) if is_marker else (anchor in line):
                at = index + 1 if where == "after" else index
                lines[at:at] = [text]
                path.write_text("".join(lines))
                say(f"~ {file} ({label})")
                return
        fail(f"`{anchor}` not found in {file}. Was the core edited? Restore it and rerun.")

    def replace(self, file: str, old: str, new: str, sentinel: str) -> None:
        path = self.root / file
        source = path.read_text()
        if sentinel in source:
            say(f"= {file} (already done)")
            return
        if old not in source:
            fail(f"`{old}` not found in {file}; make the change by hand: use `{new}`.")
        path.write_text(source.replace(old, new, 1))
        say(f"~ {file}")

    def append_once(self, file: str, text: str, sentinel: str) -> None:
        path = self.root / file
        if sentinel in path.read_text():
            say(f"= {file} (already done)")
            return
        with path.open("a") as handle:
            handle.write(text)
        say(f"~ {file}")

    def snippet(self, name: str) -> str:
        return (self.snippets / name).read_text()

    def run(self, command: list[str]) -> None:
        say("$ " + " ".join(command))
        if subprocess.run(command, cwd=self.root).returncode != 0:
            fail(f"`{' '.join(command)}` failed.")

    def pub_add(self, package: str, keep_in_step: tuple[str, ...] = ()) -> None:
        """`flutter pub add`, then upgrade `keep_in_step` packages. Needed for
        the FlutterFire plugins: each release pins an exact iOS SDK version, so
        mixing releases makes the iOS build fail to resolve dependencies."""
        if package not in (self.root / "pubspec.yaml").read_text():
            print(f"adding {package}")
            self.run(["flutter", "pub", "add", package])
            if keep_in_step:
                self.run(["flutter", "pub", "upgrade", *keep_in_step])

    def codegen(self) -> None:
        if "--no-codegen" in sys.argv:
            return
        print("generating code")
        self.run(["flutter_rust_bridge_codegen", "generate"])
        self.run(["dart", "run", "build_runner", "build"])

    def check_root(self) -> None:
        if not (self.root / "pubspec.yaml").exists() or not (self.root / "rust/api/wrangler.toml").exists():
            fail(f"{self.root} does not look like a project made from the flutter-rust template.")
