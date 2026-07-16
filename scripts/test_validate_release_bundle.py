import hashlib
import importlib.util
import io
import json
import struct
import unittest
import warnings
import zipfile
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("validate-release-bundle.py")
SPEC = importlib.util.spec_from_file_location("validate_release_bundle", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SOURCE_COMMIT = "a" * 40


def zip_bytes(
    files: list[tuple[str, bytes]],
    symlink: tuple[str, str] | None = None,
) -> bytes:
    output = io.BytesIO()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, content in files:
                archive.writestr(name, content)
            if symlink is not None:
                info = zipfile.ZipInfo(symlink[0])
                info.create_system = 3
                info.external_attr = 0o120777 << 16
                archive.writestr(info, symlink[1])
    return output.getvalue()


def zip_with_metadata(
    name: str,
    content: bytes,
    *,
    archive_comment: bytes = b"",
    entry_comment: bytes = b"",
    entry_extra: bytes = b"",
) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.comment = archive_comment
        info = zipfile.ZipInfo(name)
        info.comment = entry_comment
        info.extra = entry_extra
        archive.writestr(info, content)
    return output.getvalue()


def encrypted_first_entry(content: bytes) -> bytes:
    result = bytearray(content)
    local = result.find(b"PK\x03\x04")
    central = result.find(b"PK\x01\x02")
    assert local >= 0 and central >= 0
    local_flags = struct.unpack_from("<H", result, local + 6)[0] | 0x1
    central_flags = struct.unpack_from("<H", result, central + 8)[0] | 0x1
    struct.pack_into("<H", result, local + 6, local_flags)
    struct.pack_into("<H", result, central + 8, central_flags)
    return bytes(result)


def file_record(path: str, role: str, content: bytes) -> dict[str, object]:
    return {
        "path": path,
        "role": role,
        "bytes": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
    }


def complete_fixture(
    hap: bytes | None = None,
) -> tuple[dict[str, bytes], dict[str, bytes], dict[str, object]]:
    sources = {
        "README.md": b"source readme\n",
        MODULE.CONTENT_GATE.SUBMISSION_MANIFEST: b"source manifest\n",
        MODULE.CONTENT_GATE.COMPETITION_NOTICE: b"reviewed notice\n",
    }
    attachments = {
        "release/app.hap": hap
        if hap is not None
        else zip_bytes([("module.json", b"{}")]),
        "release/third-party-licenses.md": b"license index\n",
        "release/originality.md": b"originality declaration\n",
        "release/ai-usage.md": b"ai usage declaration\n",
        "release/evidence.json": b"{}\n",
    }
    role_by_path = {
        "release/app.hap": "hap",
        "release/third-party-licenses.md": "third-party-license-index",
        "release/originality.md": "originality-declaration",
        "release/ai-usage.md": "ai-usage-declaration",
        "release/evidence.json": "release-evidence-index",
    }
    document: dict[str, object] = {
        "sourceCommit": SOURCE_COMMIT,
        "nonGitFiles": [
            file_record(path, role_by_path[path], content)
            for path, content in attachments.items()
        ],
    }
    entries = {**sources, **attachments}
    entries[MODULE.RELEASE_MANIFEST_PATH] = json.dumps(
        document,
        separators=(",", ":"),
    ).encode("utf-8")
    return entries, sources, document


def with_document(entries: dict[str, bytes], document: dict[str, object]) -> dict[str, bytes]:
    result = dict(entries)
    result[MODULE.RELEASE_MANIFEST_PATH] = json.dumps(
        document,
        separators=(",", ":"),
    ).encode("utf-8")
    return result


class ReleaseBundleGateTests(unittest.TestCase):
    def check(self, entries: dict[str, bytes], sources: dict[str, bytes]) -> list[str]:
        return MODULE.check_release_bundle_entries(entries, sources, SOURCE_COMMIT)

    def test_schema_identifiers_and_complete_fixture_are_exact(self) -> None:
        entries, sources, _ = complete_fixture()

        errors = self.check(entries, sources)

        self.assertEqual(
            {"sourceCommit", "nonGitFiles"}, MODULE.RELEASE_MANIFEST_FIELDS
        )
        self.assertEqual(
            {"path", "role", "bytes", "sha256"}, MODULE.NON_GIT_FILE_FIELDS
        )
        self.assertEqual(
            {
                "hap",
                "third-party-license-index",
                "originality-declaration",
                "ai-usage-declaration",
                "release-evidence-index",
            },
            MODULE.REQUIRED_NON_GIT_ROLES,
        )
        self.assertEqual([], errors)

    def test_source_tampering_is_rejected_byte_for_byte(self) -> None:
        entries, sources, _ = complete_fixture()
        entries["README.md"] = b"tampered\n"

        errors = self.check(entries, sources)

        self.assertTrue(any("逐字不一致: README.md" in error for error in errors))

    def test_missing_and_duplicate_roles_are_rejected(self) -> None:
        entries, sources, document = complete_fixture()
        records = list(document["nonGitFiles"])
        records = [record for record in records if record["role"] != "ai-usage-declaration"]
        originality = next(record for record in records if record["role"] == "originality-declaration")
        originality["role"] = "third-party-license-index"
        document["nonGitFiles"] = records

        errors = self.check(with_document(entries, document), sources)

        self.assertTrue(any("ai-usage-declaration" in error and "实际 0" in error for error in errors))
        self.assertTrue(any("originality-declaration" in error and "实际 0" in error for error in errors))
        self.assertTrue(any("third-party-license-index" in error and "实际 2" in error for error in errors))

    def test_undeclared_extra_file_is_rejected(self) -> None:
        entries, sources, _ = complete_fixture()
        entries["release/unlisted.txt"] = b"unlisted\n"

        errors = self.check(entries, sources)

        self.assertTrue(
            any("未在 nonGitFiles 声明" in error and "unlisted.txt" in error for error in errors)
        )

    def test_declared_size_and_hash_must_match_actual_bytes(self) -> None:
        entries, sources, document = complete_fixture()
        evidence = next(
            record
            for record in document["nonGitFiles"]
            if record["role"] == "release-evidence-index"
        )
        evidence["bytes"] += 1
        evidence["sha256"] = "0" * 64

        errors = self.check(with_document(entries, document), sources)

        self.assertTrue(any("bytes 与实际文件大小不一致" in error for error in errors))
        self.assertTrue(any("sha256 与实际文件哈希不一致" in error for error in errors))

    def test_source_commit_must_match_current_git_commit_and_resolve(self) -> None:
        entries, sources, _ = complete_fixture()

        mismatch_errors = MODULE.check_release_bundle_entries(
            entries,
            sources,
            "b" * 40,
        )
        head_commit, head_errors = MODULE.current_git_commit()
        missing_snapshot, missing_errors = MODULE.load_git_source_snapshot("0" * 40)

        self.assertTrue(any("sourceCommit" in error and "不一致" in error for error in mismatch_errors))
        self.assertEqual([], head_errors)
        self.assertIsNotNone(head_commit)
        self.assertRegex(head_commit or "", r"^[0-9a-f]{40}$")
        self.assertIsNone(missing_snapshot)
        self.assertTrue(any("无法解析为本仓库提交" in error for error in missing_errors))

    def test_git_snapshot_reuses_source_package_gate(self) -> None:
        head_commit, head_errors = MODULE.current_git_commit()
        self.assertEqual([], head_errors)
        assert head_commit is not None

        with mock.patch.object(
            MODULE.CONTENT_GATE,
            "check_submission_package",
            return_value=["source-package-gate-sentinel"],
        ) as source_gate:
            snapshot, errors = MODULE.load_git_source_snapshot(head_commit)

        self.assertIsNone(snapshot)
        self.assertIn("source-package-gate-sentinel", errors)
        source_gate.assert_called_once()

    def test_hap_rejects_dangerous_internal_path(self) -> None:
        entries, sources, _ = complete_fixture(
            zip_bytes([("../escape.txt", b"unsafe")])
        )

        errors = self.check(entries, sources)

        self.assertTrue(any("HAP" in error and "../escape.txt" in error for error in errors))

    def test_hap_rejects_secret_without_echoing_value(self) -> None:
        secret = b'VERCEL_' + b'TOKEN = "' + (b'xY7_' * 6) + b'"'
        entries, sources, _ = complete_fixture(
            zip_bytes([("config.txt", secret)])
        )

        errors = self.check(entries, sources)
        output = "\n".join(errors)

        self.assertIn("literal-server-secret", output)
        self.assertNotIn(secret.decode("ascii"), output)

    def test_outer_file_rejects_secret_without_echoing_value(self) -> None:
        secret = b'MODEL_' + b'API_KEY = "' + (b'Qz9_' * 8) + b'"'
        entries, sources, document = complete_fixture()
        evidence = next(
            record
            for record in document["nonGitFiles"]
            if record["role"] == "release-evidence-index"
        )
        entries[evidence["path"]] = secret
        evidence["bytes"] = len(secret)
        evidence["sha256"] = hashlib.sha256(secret).hexdigest()

        errors = self.check(with_document(entries, document), sources)
        output = "\n".join(errors)

        self.assertIn("literal-server-secret", output)
        self.assertNotIn(secret.decode("ascii"), output)

    def test_secret_in_attachment_path_is_redacted_from_all_errors(self) -> None:
        secret_segment = "MODEL_" + "API_KEY=" + ("T9_" * 8)
        secret_path = f"release/{secret_segment}.json"
        entries, sources, document = complete_fixture()
        evidence = next(
            record
            for record in document["nonGitFiles"]
            if record["role"] == "release-evidence-index"
        )
        old_path = evidence["path"]
        entries[secret_path] = entries.pop(old_path)
        evidence["path"] = secret_path
        evidence["sha256"] = "0" * 64
        entries = with_document(entries, document)

        semantic_errors = self.check(entries, sources)
        archive_content = zip_bytes(list(entries.items()))
        _, metadata_errors = MODULE.collect_zip_entries(
            io.BytesIO(archive_content),
            "最终 ZIP",
        )
        output = "\n".join(semantic_errors + metadata_errors)

        self.assertIn("<redacted-path>", output)
        self.assertNotIn(secret_segment, output)

    def test_manifest_and_archive_paths_have_internal_size_limits(self) -> None:
        long_path = "release/" + ("x" * MODULE.MAX_ARCHIVE_PATH_BYTES) + ".md"
        entries, _, document = complete_fixture()
        del entries
        records = document["nonGitFiles"]
        records[1]["path"] = long_path

        _, manifest_errors = MODULE.parse_release_manifest(
            json.dumps(document).encode("utf-8")
        )
        _, archive_errors = MODULE.collect_zip_entries(
            io.BytesIO(zip_bytes([(long_path, b"content")])),
            "最终 ZIP",
        )
        _, oversized_manifest_errors = MODULE.parse_release_manifest(
            b" " * (MODULE.MAX_RELEASE_MANIFEST_BYTES + 1)
        )
        nested_manifest = (
            b'{"sourceCommit":"'
            + SOURCE_COMMIT.encode("ascii")
            + b'","nonGitFiles":'
            + (b"[" * 10000)
            + (b"]" * 10000)
            + b"}"
        )
        _, nested_manifest_errors = MODULE.parse_release_manifest(nested_manifest)
        output = "\n".join(
            manifest_errors
            + archive_errors
            + oversized_manifest_errors
            + nested_manifest_errors
        )

        self.assertIn("路径 UTF-8 长度超过内部上限", output)
        self.assertIn("release-manifest.json 超过内部上限", output)
        self.assertIn("JSON 结构或数值超出内部安全边界", output)
        self.assertNotIn(long_path, output)

    def test_zip_metadata_and_long_hap_secret_are_rejected_without_echo(self) -> None:
        secret = b'VERCEL_' + b'TOKEN = "' + (b'K' * 70000) + b'"'
        short_secret = b'MODEL_' + b'API_KEY = "' + (b'R7_' * 8) + b'"'
        valid_extra = struct.pack("<HH", 0xCAFE, len(short_secret)) + short_secret
        hap = zip_with_metadata(
            "module.json",
            secret,
            archive_comment=short_secret,
            entry_comment=short_secret,
            entry_extra=valid_extra,
        )
        hap_errors = MODULE.check_hap_content("release/app.hap", hap)
        outer = zip_with_metadata(
            "release-manifest.json",
            b"{}",
            archive_comment=short_secret,
            entry_comment=short_secret,
            entry_extra=valid_extra,
        )
        _, outer_errors = MODULE.collect_zip_entries(io.BytesIO(outer), "最终 ZIP")
        output = "\n".join(hap_errors + outer_errors)

        self.assertIn("ZIP 注释敏感信息命中", output)
        self.assertIn("条目注释敏感信息命中", output)
        self.assertIn("条目扩展字段敏感信息命中", output)
        self.assertIn("HAP 内部条目内容敏感信息命中", output)
        self.assertNotIn(short_secret.decode("ascii"), output)
        self.assertNotIn(secret.decode("ascii"), output)

    def test_hap_filename_secret_is_rejected_without_echo(self) -> None:
        secret_name = "MODEL_" + "API_KEY=" + ("S8_" * 8)
        errors = MODULE.check_hap_content(
            "release/app.hap",
            zip_bytes([(secret_name, b"{}")]),
        )
        output = "\n".join(errors)

        self.assertIn("条目文件名敏感信息命中", output)
        self.assertNotIn(secret_name, output)

    def test_hap_rejects_encrypted_symlink_and_duplicate_entries(self) -> None:
        encrypted = encrypted_first_entry(zip_bytes([("secret.txt", b"content")]))
        symlink = zip_bytes([("module.json", b"{}")], ("link", "target"))
        duplicate = zip_bytes([("same.txt", b"one"), ("same.txt", b"two")])

        encrypted_errors = MODULE.check_hap_content("release/app.hap", encrypted)
        symlink_errors = MODULE.check_hap_content("release/app.hap", symlink)
        duplicate_errors = MODULE.check_hap_content("release/app.hap", duplicate)

        self.assertTrue(any("加密条目" in error for error in encrypted_errors))
        self.assertTrue(any("符号链接" in error for error in symlink_errors))
        self.assertTrue(any("重复条目" in error for error in duplicate_errors))

    def test_hap_must_be_unique_nonempty_readable_and_use_hap_role(self) -> None:
        entries, sources, document = complete_fixture()
        entries["release/app.hap"] = b""
        records = document["nonGitFiles"]
        hap_record = next(record for record in records if record["role"] == "hap")
        hap_record["bytes"] = 1
        hap_record["sha256"] = hashlib.sha256(b"").hexdigest()
        entries = with_document(entries, document)

        empty_errors = self.check(entries, sources)
        entries["release/second.hap"] = zip_bytes([("module.json", b"{}")])
        multiple_errors = self.check(entries, sources)

        self.assertTrue(any("HAP 为空" in error for error in empty_errors))
        self.assertTrue(any("只能包含一个 HAP，实际 2" in error for error in multiple_errors))

    def test_notice_pending_marker_is_rejected(self) -> None:
        entries, sources, _ = complete_fixture()
        pending = MODULE.CONTENT_GATE.PENDING_SUBMISSION_MARKER + b"\n"
        entries[MODULE.CONTENT_GATE.COMPETITION_NOTICE] = pending
        sources = dict(sources)
        sources[MODULE.CONTENT_GATE.COMPETITION_NOTICE] = pending

        errors = self.check(entries, sources)

        self.assertTrue(any("NOTICE 仍含待人工处理标记" in error for error in errors))

    def test_manifest_rejects_unknown_fields_duplicate_keys_and_bad_paths(self) -> None:
        duplicate = b'{"sourceCommit":"' + SOURCE_COMMIT.encode("ascii") + (
            b'","sourceCommit":"' + SOURCE_COMMIT.encode("ascii") + b'","nonGitFiles":[]}'
        )
        _, duplicate_errors = MODULE.parse_release_manifest(duplicate)
        bad_document = {
            "sourceCommit": SOURCE_COMMIT,
            "nonGitFiles": [
                {
                    "path": "../escape.txt",
                    "role": "hap",
                    "bytes": 1,
                    "sha256": "0" * 64,
                    "extra": True,
                }
            ],
            "extra": True,
        }
        _, path_errors = MODULE.parse_release_manifest(
            json.dumps(bad_document).encode("utf-8")
        )
        entries, _, exact_document = complete_fixture()
        del entries
        exact_records = exact_document["nonGitFiles"]
        exact_records[1]["path"] = exact_records[0]["path"]
        _, exact_path_errors = MODULE.parse_release_manifest(
            json.dumps(exact_document).encode("utf-8")
        )
        _, _, folded_document = complete_fixture()
        folded_records = folded_document["nonGitFiles"]
        folded_records[1]["path"] = folded_records[0]["path"].upper()
        _, folded_path_errors = MODULE.parse_release_manifest(
            json.dumps(folded_document).encode("utf-8")
        )
        _, _, forbidden_document = complete_fixture()
        forbidden_records = forbidden_document["nonGitFiles"]
        forbidden_records[1]["path"] = ".env.local"
        _, forbidden_path_errors = MODULE.parse_release_manifest(
            json.dumps(forbidden_document).encode("utf-8")
        )

        self.assertTrue(any("重复键" in error for error in duplicate_errors))
        self.assertTrue(any("未定义字段" in error for error in path_errors))
        self.assertTrue(any("../escape.txt" in error for error in path_errors))
        self.assertTrue(any("路径重复" in error for error in exact_path_errors))
        self.assertTrue(any("大小写折叠后重复" in error for error in folded_path_errors))
        self.assertTrue(any("发布包禁止项" in error for error in forbidden_path_errors))

    def test_outer_zip_collector_rejects_unsafe_duplicate_symlink_and_encrypted(self) -> None:
        unsafe_duplicate_symlink = zip_bytes(
            [
                ("../escape.txt", b"unsafe"),
                ("a/./b.txt", b"not normalized"),
                ("same.txt", b"one"),
                ("same.txt", b"two"),
            ],
            ("link", "target"),
        )
        _, errors = MODULE.collect_zip_entries(
            io.BytesIO(unsafe_duplicate_symlink), "最终 ZIP"
        )
        encrypted = encrypted_first_entry(zip_bytes([("entry.txt", b"content")]))
        _, encrypted_errors = MODULE.collect_zip_entries(
            io.BytesIO(encrypted), "最终 ZIP"
        )

        self.assertTrue(any("../escape.txt" in error for error in errors))
        self.assertTrue(any("a/./b.txt" in error for error in errors))
        self.assertIsNotNone(MODULE.archive_path_reason("a\\b.txt"))
        self.assertTrue(any("重复条目" in error for error in errors))
        self.assertTrue(any("符号链接" in error for error in errors))
        self.assertTrue(any("加密条目" in error for error in encrypted_errors))


if __name__ == "__main__":
    unittest.main()
