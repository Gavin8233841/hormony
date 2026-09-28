#!/usr/bin/env python3
"""Contract checks for the reviewer-facing source archive."""

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import sys
import unittest
import zipfile
from pathlib import Path


PATH = Path(__file__).with_name("validate-public-source-bundle.py")
SPEC = importlib.util.spec_from_file_location("validate_public_source_bundle", PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load public source validator")
GATE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = GATE
SPEC.loader.exec_module(GATE)
COMMIT = "a" * 40
SOURCE = {
    "apps/harmonyos/entry/src/main/module.json5": b"{}",
    "apps/web/src/app/page.tsx": b"export default function Page() { return null; }",
    "scripts/local-api-gateway.mjs": b"export const gateway = true;",
}


def hap(content: bytes = b"{}") -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("module.json", content)
    return buffer.getvalue()


def package(
    extra_roles: bool = False,
    hap_content: bytes = b"{}",
) -> dict[str, bytes]:
    entries = {
        **SOURCE,
        "README.md": b"Run the application.",
        "artifacts/app.hap": hap(hap_content),
    }
    roles = [
        ("README.md", "readme"),
        ("artifacts/app.hap", "hap"),
    ]
    if extra_roles:
        for path, role in (
            ("release/licenses.md", "third-party-license-index"),
            ("release/originality.pdf", "originality-declaration"),
            ("release/ai-usage.md", "ai-usage-declaration"),
        ):
            entries[path] = f"{role}\n".encode()
            roles.append((path, role))
    entries["public-package.json"] = (
        json.dumps(
            {
                "schemaVersion": 1,
                "sourceCommit": COMMIT,
                "files": [
                    {
                        "path": path,
                        "role": role,
                        "bytes": len(entries[path]),
                        "sha256": hashlib.sha256(entries[path]).hexdigest(),
                    }
                    for path, role in roles
                ],
            }
        )
        + "\n"
    ).encode()
    return entries


class PublicSourceBundleTests(unittest.TestCase):
    def test_exact_review_package_passes(self) -> None:
        self.assertEqual(GATE.validate_entries(package(), COMMIT, SOURCE), [])

    def test_submission_requires_declarations(self) -> None:
        errors = GATE.validate_entries(package(), COMMIT, SOURCE, require_complete=True)
        self.assertTrue(any("required role missing" in error for error in errors))
        self.assertEqual(
            GATE.validate_entries(package(extra_roles=True), COMMIT, SOURCE, require_complete=True),
            [],
        )

    def test_git_source_tampering_and_extra_file_fail(self) -> None:
        entries = package()
        entries["apps/web/src/app/page.tsx"] = b"tampered"
        entries["private-note.txt"] = b"extra"
        errors = GATE.validate_entries(entries, COMMIT, SOURCE)
        self.assertTrue(any("Git source byte mismatch" in error for error in errors))
        self.assertTrue(any("entry set mismatch" in error for error in errors))

    def test_nested_hap_wording_fails(self) -> None:
        entries = package(hap_content=b"simulator")
        errors = GATE.validate_entries(entries, COMMIT, SOURCE)
        self.assertIn("public wording in HAP", errors)

    def test_manifest_digest_and_commit_mismatch_fail(self) -> None:
        entries = package()
        entries["README.md"] = b"Modified"
        errors = GATE.validate_entries(entries, "b" * 40, SOURCE)
        self.assertTrue(any("sourceCommit differs" in error for error in errors))
        self.assertTrue(any("manifest digest mismatch" in error for error in errors))

    def test_malformed_role_fails_without_exception(self) -> None:
        entries = package()
        manifest = json.loads(entries["public-package.json"])
        manifest["files"][0]["role"] = ["readme"]
        entries["public-package.json"] = json.dumps(manifest).encode()
        errors = GATE.validate_entries(entries, COMMIT, SOURCE)
        self.assertIn("manifest file record has invalid role", errors)


if __name__ == "__main__":
    unittest.main()
