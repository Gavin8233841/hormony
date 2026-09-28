#!/usr/bin/env python3
"""Read-only validation of the source and HAP archive shared with reviewers."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
LEGACY_PATH = Path(__file__).with_name("validate-release-bundle.py")
SPEC = importlib.util.spec_from_file_location("release_bundle_for_public_source", LEGACY_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load archive safety checks")
LEGACY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LEGACY)

MANIFEST_PATH = "public-package.json"
SOURCE_ROOTS = ("apps/harmonyos", "apps/web", "scripts/local-api-gateway.mjs")
EXCLUDED = frozenset({
    "apps/web/BACKEND_P1_FIX_DEVLOG.md",
    "apps/web/BACKEND_P2_CLEANUP_DEVLOG.md",
})
REQUIRED_ROLES = frozenset({"readme", "hap"})
COMPLETE_ROLES = frozenset({
    "third-party-license-index",
    "originality-declaration",
    "ai-usage-declaration",
})
ALL_ROLES = REQUIRED_ROLES | COMPLETE_ROLES
PUBLIC_TERMS = ("模拟器", "真机", "缺口", "未实现", "未验证", "不做承诺", "simulator")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
COMMIT = re.compile(r"[0-9a-f]{40}\Z")
MAX_MANIFEST_BYTES = 64 * 1024


def _duplicates(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def _sha(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT, stderr=subprocess.DEVNULL)


def _source_snapshot(commit: str) -> dict[str, bytes]:
    names = _git("ls-tree", "-r", "--name-only", "-z", commit, "--", *SOURCE_ROOTS)
    source: dict[str, bytes] = {}
    for raw in names.split(b"\0"):
        if not raw:
            continue
        name = raw.decode("utf-8")
        if name in EXCLUDED or name.startswith("apps/harmonyos/screenshot/"):
            continue
        if LEGACY.archive_path_reason(name) is not None:
            raise ValueError("invalid source path")
        source[name] = _git("show", f"{commit}:{name}")
    if not source or not any(n.startswith("apps/harmonyos/entry/") for n in source):
        raise ValueError("HarmonyOS source is incomplete")
    if not any(n.startswith("apps/web/src/") for n in source):
        raise ValueError("Web source is incomplete")
    if "scripts/local-api-gateway.mjs" not in source:
        raise ValueError("local gateway source is missing")
    return source


def _wording_hits(name: str, content: bytes) -> list[str]:
    hits: list[str] = []
    lower_name = name.casefold()
    lower_content = content.lower()
    for term in PUBLIC_TERMS:
        if term.casefold() in lower_name or term.encode("utf-8").lower() in lower_content:
            hits.append(term)
    return hits


def _record_errors(record: object) -> list[str]:
    if not isinstance(record, dict) or set(record) != {"path", "role", "bytes", "sha256"}:
        return ["manifest file record has invalid fields"]
    if not isinstance(record["path"], str) or LEGACY.archive_path_reason(record["path"]) is not None:
        return ["manifest file record has invalid path"]
    if not isinstance(record["role"], str) or record["role"] not in ALL_ROLES:
        return ["manifest file record has invalid role"]
    if not isinstance(record["bytes"], int) or isinstance(record["bytes"], bool) or record["bytes"] <= 0:
        return ["manifest file record has invalid byte count"]
    if not isinstance(record["sha256"], str) or SHA256.fullmatch(record["sha256"]) is None:
        return ["manifest file record has invalid SHA-256"]
    if record["role"] == "readme" and record["path"] != "README.md":
        return ["README path must be README.md"]
    if record["role"] == "hap" and not record["path"].endswith(".hap"):
        return ["HAP path must end in .hap"]
    if record["role"] in COMPLETE_ROLES and not record["path"].startswith("release/"):
        return ["declaration path must be under release/"]
    return []


def validate_entries(
    entries: dict[str, bytes],
    expected_commit: str,
    expected_sources: dict[str, bytes],
    require_complete: bool = False,
) -> list[str]:
    errors: list[str] = []
    if MANIFEST_PATH not in entries:
        return [f"missing {MANIFEST_PATH}"]
    raw_manifest = entries[MANIFEST_PATH]
    if len(raw_manifest) > MAX_MANIFEST_BYTES:
        return ["manifest exceeds size limit"]
    try:
        manifest = json.loads(raw_manifest.decode("utf-8"), object_pairs_hook=_duplicates)
    except (UnicodeDecodeError, ValueError):
        return ["manifest is not strict UTF-8 JSON"]
    if not isinstance(manifest, dict) or set(manifest) != {"schemaVersion", "sourceCommit", "files"}:
        return ["manifest has invalid fields"]
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1:
        errors.append("manifest schemaVersion must be 1")
    if not isinstance(manifest["sourceCommit"], str) or COMMIT.fullmatch(manifest["sourceCommit"]) is None:
        errors.append("manifest sourceCommit is invalid")
    elif manifest["sourceCommit"] != expected_commit:
        errors.append("manifest sourceCommit differs from current HEAD")
    records = manifest["files"]
    if not isinstance(records, list) or len(records) > 8:
        return errors + ["manifest files must be a short array"]
    record_errors = [error for record in records for error in _record_errors(record)]
    if record_errors:
        return errors + record_errors
    roles = [record["role"] for record in records]
    paths = [record["path"] for record in records]
    if len(set(roles)) != len(roles):
        errors.append("manifest has duplicate roles")
    if len(set(paths)) != len(paths) or len(set(p.casefold() for p in paths)) != len(paths):
        errors.append("manifest has duplicate paths")
    for role in REQUIRED_ROLES | (COMPLETE_ROLES if require_complete else frozenset()):
        if roles.count(role) != 1:
            errors.append(f"required role missing: {role}")
    if require_complete and set(roles) != ALL_ROLES:
        errors.append("submission archive must have the five declared roles")
    actual = set(entries)
    expected = set(expected_sources) | set(paths) | {MANIFEST_PATH}
    if actual != expected:
        errors.append(f"archive entry set mismatch: missing={len(expected - actual)}, extra={len(actual - expected)}")
    for name, expected_bytes in expected_sources.items():
        if name in entries and entries[name] != expected_bytes:
            errors.append(f"Git source byte mismatch: {name}")
    for record in records:
        name = record["path"]
        if name not in entries:
            continue
        content = entries[name]
        if len(content) != record["bytes"] or _sha(content) != record["sha256"]:
            errors.append(f"manifest digest mismatch: {name}")
        if record["role"] == "hap":
            errors.extend(LEGACY.check_hap_content(name, content))
            try:
                with zipfile.ZipFile(io.BytesIO(content)) as archive:
                    for info in archive.infolist():
                        if info.is_dir():
                            continue
                        if _wording_hits(f"{name}!/{info.filename}", archive.read(info)):
                            errors.append("public wording in HAP")
                            break
            except (OSError, RuntimeError, zipfile.BadZipFile):
                errors.append("HAP wording scan failed")
    for name, content in entries.items():
        if _wording_hits(name, content):
            errors.append(f"public wording in archive entry: {name}")
        if LEGACY._stream_secret_hits(io.BytesIO(content)):
            errors.append(f"sensitive content in archive entry: {name}")
    return errors


def validate_file(path: Path, require_complete: bool = False) -> list[str]:
    if not path.is_file() or path.is_symlink() or path.suffix.casefold() != ".zip":
        return ["bundle path must be an existing regular ZIP file"]
    entries, errors = LEGACY.collect_zip_entries(path.resolve(), "public source ZIP")
    if errors:
        return errors
    try:
        commit = _git("rev-parse", "HEAD").decode("ascii").strip()
        source = _source_snapshot(commit)
    except (subprocess.CalledProcessError, UnicodeDecodeError, ValueError):
        return ["cannot obtain exact Git source snapshot"]
    return validate_entries(entries, commit, source, require_complete)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-path", type=Path, required=True)
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    errors = validate_file(args.bundle_path, args.require_complete)
    if errors:
        print(f"[FAIL] public source ZIP: {len(errors)}")
        for error in errors[:30]:
            print(f"  - {error}")
        return 1
    print(f"[PASS] public source ZIP: {args.bundle_path.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
