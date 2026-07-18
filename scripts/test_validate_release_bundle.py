import hashlib
import importlib.util
import io
import json
import struct
import unittest
import warnings
import zipfile
import zlib
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("validate-release-bundle.py")
SPEC = importlib.util.spec_from_file_location("validate_release_bundle", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SOURCE_COMMIT = "a" * 40


def png_bytes(width: int = 2, height: int = 2) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    rows = b"".join(b"\x00" + (b"\x00\x00\x00\xff" * width) for _ in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(
        b"IDAT", zlib.compress(rows)
    ) + chunk(b"IEND", b"")


def ui_tree_bytes() -> bytes:
    return json.dumps(
        {
            "attributes": {
                "visible": "true",
                "pagePath": "pages/Index",
                "bounds": "[0,0][1260,2720]",
            },
            "children": [
                {
                    "attributes": {
                        "visible": "true",
                        "text": "固定输入页面",
                        "bounds": "[10,10][200,100]",
                    },
                    "children": [],
                }
            ],
        },
        separators=(",", ":"),
    ).encode("utf-8")


def mp4_bytes() -> bytes:
    def box(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I4s", len(payload) + 8, kind) + payload

    handler = b"\x00\x00\x00\x00" + b"\x00\x00\x00\x00" + b"vide" + (b"\x00" * 12)
    mdia = box(b"mdia", box(b"hdlr", handler))
    moov = box(b"moov", box(b"trak", mdia))
    ftyp = box(b"ftyp", b"isom" + (b"\x00" * 4) + b"isommp42")
    return ftyp + moov + box(b"mdat", b"\x00")


def fixed_media_probe(_path: str, _kind: str, _content: bytes) -> list[str]:
    return []


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


def zip_with_raw_filename(raw_name: bytes, content: bytes = b"fixture") -> bytes:
    if not raw_name or not raw_name.isascii():
        raise ValueError("raw_name must be non-empty ASCII bytes")

    placeholder_seed = b"RAW_NAME_PLACEHOLDER_0123456789_"
    placeholder = (placeholder_seed * (len(raw_name) // len(placeholder_seed) + 1))[
        : len(raw_name)
    ]
    result = bytearray(zip_bytes([(placeholder.decode("ascii"), content)]))
    local = result.find(b"PK\x03\x04")
    central = result.find(b"PK\x01\x02")
    assert local >= 0 and central >= 0

    local_name_length = struct.unpack_from("<H", result, local + 26)[0]
    central_name_length = struct.unpack_from("<H", result, central + 28)[0]
    local_name_start = local + 30
    central_name_start = central + 46
    assert local_name_length == len(placeholder)
    assert central_name_length == len(placeholder)
    assert result[local_name_start : local_name_start + local_name_length] == placeholder
    assert (
        result[central_name_start : central_name_start + central_name_length]
        == placeholder
    )
    assert bytes(result).count(placeholder) == 2

    result[local_name_start : local_name_start + local_name_length] = raw_name
    result[central_name_start : central_name_start + central_name_length] = raw_name
    assert bytes(result).count(raw_name) == 2
    return bytes(result)


def zip_with_invalid_utf8_filename() -> bytes:
    placeholder = b"invalid.bin"
    raw_name = b"\xffnvalid.bin"
    result = bytearray(zip_bytes([(placeholder.decode("ascii"), b"fixture")]))
    local = result.find(b"PK\x03\x04")
    central = result.find(b"PK\x01\x02")
    assert local >= 0 and central >= 0
    assert len(raw_name) == len(placeholder)
    assert bytes(result).count(placeholder) == 2
    result = bytearray(bytes(result).replace(placeholder, raw_name))
    local_flags = struct.unpack_from("<H", result, local + 6)[0] | 0x800
    central_flags = struct.unpack_from("<H", result, central + 8)[0] | 0x800
    struct.pack_into("<H", result, local + 6, local_flags)
    struct.pack_into("<H", result, central + 8, central_flags)
    return bytes(result)


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


def release_evidence_bytes(hap: bytes) -> bytes:
    records = [
        {
            "id": record_id,
            "claim": f"{record_id} 固定输入发布事实",
            "level": "未验证",
            "recordedAt": "2026-07-17T12:00:00+08:00",
            "command": None,
            "exitCode": None,
            "environment": {},
            "artifacts": [],
            "businessChecks": [],
            "notes": "固定输入只证明门禁合同，不代表产品流程通过",
        }
        for record_id in sorted(MODULE.EVIDENCE_GATE.REQUIRED_RECORD_IDS)
    ]
    return json.dumps(
        {
            "schemaVersion": MODULE.EVIDENCE_GATE.SCHEMA_VERSION,
            "sourceCommit": SOURCE_COMMIT,
            "hapSha256": hashlib.sha256(hap).hexdigest(),
            "records": records,
            "limitations": ["模拟器、真机、线上和门户上传均未验证"],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")


def complete_fixture(
    hap: bytes | None = None,
) -> tuple[dict[str, bytes], dict[str, bytes], dict[str, object]]:
    sources = {
        "README.md": b"source readme\n",
        MODULE.CONTENT_GATE.SUBMISSION_MANIFEST: b"source manifest\n",
        MODULE.CONTENT_GATE.COMPETITION_NOTICE: b"reviewed notice\n",
        MODULE.COMPETITION_PLAN_PATH: MODULE.COMPETITION_GATE.DEFAULT_PLAN_PATH.read_bytes(),
    }
    resolved_hap = hap if hap is not None else zip_bytes([("module.json", b"{}")])
    attachments = {
        "release/app.hap": resolved_hap,
        "release/third-party-licenses.md": b"license index\n",
        "release/originality.md": b"originality declaration\n",
        "release/ai-usage.md": b"ai usage declaration\n",
        "release/evidence.json": release_evidence_bytes(resolved_hap),
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


def with_attachment(
    entries: dict[str, bytes],
    document: dict[str, object],
    path: str,
    content: bytes,
) -> dict[str, bytes]:
    result = dict(entries)
    result[path] = content
    records = document["nonGitFiles"]
    record = next(item for item in records if item["path"] == path)
    record["bytes"] = len(content)
    record["sha256"] = hashlib.sha256(content).hexdigest()
    return with_document(result, document)


def with_static_evidence_artifact(
    entries: dict[str, bytes],
    document: dict[str, object],
    *,
    path: str = "evidence/artifacts/source-check.txt",
    content: bytes = b"fixed diagnostic evidence; not product runtime evidence",
    referenced: bool = True,
) -> dict[str, bytes]:
    result = dict(entries)
    records = document["nonGitFiles"]
    assert isinstance(records, list)
    records.append(file_record(path, MODULE.EVIDENCE_ARTIFACT_ROLE, content))
    result[path] = content

    evidence_record = next(
        item for item in records if item["role"] == "release-evidence-index"
    )
    evidence_document = json.loads(result[evidence_record["path"]])
    if referenced:
        source_record = next(
            item
            for item in evidence_document["records"]
            if item["id"] == "source-package"
        )
        source_record["level"] = "静态诊断通过"
        source_record["command"] = ["python", "-B", "scripts/validate-competition-content.py"]
        source_record["exitCode"] = 0
        source_record["environment"] = {
            "os": "Windows 11",
            "tool": "python",
            "toolVersion": "3.12",
        }
        source_record["artifacts"] = [
            {
                "path": path,
                "kind": "diagnostic",
                "bytes": len(content),
                "sha256": hashlib.sha256(content).hexdigest(),
            }
        ]
    evidence_content = json.dumps(
        evidence_document,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    result[evidence_record["path"]] = evidence_content
    evidence_record["bytes"] = len(evidence_content)
    evidence_record["sha256"] = hashlib.sha256(evidence_content).hexdigest()
    return with_document(result, document)


def with_verified_golden_demo(
    entries: dict[str, bytes],
    sources: dict[str, bytes],
    document: dict[str, object],
) -> tuple[dict[str, bytes], dict[str, bytes]]:
    result = dict(entries)
    expected_sources = dict(sources)
    figure_paths = (
        "evidence/artifacts/figure-1.png",
        "evidence/artifacts/figure-2.png",
    )
    supporting_artifacts = (
        (figure_paths[0], "screenshot", png_bytes()),
        (figure_paths[1], "screenshot", png_bytes(3, 2)),
        ("evidence/artifacts/golden-demo-ui-tree.json", "ui-tree", ui_tree_bytes()),
        ("evidence/artifacts/golden-demo.mp4", "video", mp4_bytes()),
    )

    plan_lines = result[MODULE.COMPETITION_PLAN_PATH].decode("utf-8").splitlines()
    state_indexes = [
        index
        for index, line in enumerate(plan_lines)
        if line.startswith("- 证据状态：")
    ]
    assert len(state_indexes) == 2
    for figure_index, state_index in enumerate(state_indexes):
        plan_lines[state_index] = (
            "- 证据状态：`level=模拟器通过; evidenceId=golden-demo; "
            f"artifact={figure_paths[figure_index]}; gap=none`。"
        )
    plan_content = ("\n".join(plan_lines) + "\n").encode("utf-8")
    result[MODULE.COMPETITION_PLAN_PATH] = plan_content
    expected_sources[MODULE.COMPETITION_PLAN_PATH] = plan_content

    manifest_records = document["nonGitFiles"]
    assert isinstance(manifest_records, list)
    for path, _, content in supporting_artifacts:
        result[path] = content
        manifest_records.append(
            file_record(path, MODULE.EVIDENCE_ARTIFACT_ROLE, content)
        )

    evidence_record = next(
        item
        for item in manifest_records
        if item["role"] == "release-evidence-index"
    )
    evidence_document = json.loads(result[evidence_record["path"]])
    demo = next(
        item
        for item in evidence_document["records"]
        if item["id"] == "golden-demo"
    )
    demo["level"] = "模拟器通过"
    demo["command"] = ["hdc", "shell", "uitest", "dumpLayout"]
    demo["exitCode"] = 0
    demo["environment"] = {
        "device": "fixed-emulator",
        "systemVersion": "HarmonyOS 5.0.0",
        "orientation": "portrait",
        "resolution": {"widthPx": 1260, "heightPx": 2720},
    }
    demo["artifacts"] = [
        {
            "path": path,
            "kind": kind,
            "bytes": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        }
        for path, kind, content in supporting_artifacts
    ]
    video_path = supporting_artifacts[-1][0]
    demo["businessChecks"] = [
        {
            "id": check_id,
            "passed": True,
            "actual": True,
            "artifactPath": video_path,
        }
        for check_id in sorted(MODULE.EVIDENCE_GATE.GOLDEN_DEMO_CHECK_IDS)
    ]
    evidence_content = json.dumps(
        evidence_document,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    result[evidence_record["path"]] = evidence_content
    evidence_record["bytes"] = len(evidence_content)
    evidence_record["sha256"] = hashlib.sha256(evidence_content).hexdigest()
    return with_document(result, document), expected_sources


def replace_evidence_artifact(
    entries: dict[str, bytes],
    path: str,
    content: bytes,
) -> dict[str, bytes]:
    result = dict(entries)
    manifest = json.loads(result[MODULE.RELEASE_MANIFEST_PATH])
    manifest_records = manifest["nonGitFiles"]
    artifact_record = next(item for item in manifest_records if item["path"] == path)
    result[path] = content
    artifact_record["bytes"] = len(content)
    artifact_record["sha256"] = hashlib.sha256(content).hexdigest()

    evidence_record = next(
        item
        for item in manifest_records
        if item["role"] == "release-evidence-index"
    )
    evidence_document = json.loads(result[evidence_record["path"]])
    artifact_metadata = next(
        artifact
        for record in evidence_document["records"]
        for artifact in record["artifacts"]
        if artifact["path"] == path
    )
    artifact_metadata["bytes"] = len(content)
    artifact_metadata["sha256"] = hashlib.sha256(content).hexdigest()
    evidence_content = json.dumps(
        evidence_document,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    result[evidence_record["path"]] = evidence_content
    evidence_record["bytes"] = len(evidence_content)
    evidence_record["sha256"] = hashlib.sha256(evidence_content).hexdigest()
    result[MODULE.RELEASE_MANIFEST_PATH] = json.dumps(
        manifest,
        separators=(",", ":"),
    ).encode("utf-8")
    return result


class ReleaseBundleGateTests(unittest.TestCase):
    def check(self, entries: dict[str, bytes], sources: dict[str, bytes]) -> list[str]:
        return MODULE.check_release_bundle_entries(
            entries,
            sources,
            SOURCE_COMMIT,
            fixed_media_probe,
        )

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

    def test_controlled_evidence_artifact_and_reference_closure(self) -> None:
        entries, sources, document = complete_fixture()
        valid = with_static_evidence_artifact(entries, document)

        self.assertEqual([], self.check(valid, sources))
        self.assertIn(MODULE.EVIDENCE_ARTIFACT_ROLE, MODULE.ALLOWED_NON_GIT_ROLES)

        unreferenced_entries, unreferenced_sources, unreferenced_document = complete_fixture()
        unreferenced = with_static_evidence_artifact(
            unreferenced_entries,
            unreferenced_document,
            referenced=False,
        )
        unreferenced_errors = self.check(unreferenced, unreferenced_sources)
        self.assertTrue(
            any("未被任何发布证据 ID 引用" in error for error in unreferenced_errors)
        )

    def test_figure_states_bind_to_golden_demo_level_and_artifacts(self) -> None:
        entries, sources, document = complete_fixture()
        valid, valid_sources = with_verified_golden_demo(entries, sources, document)

        self.assertEqual([], self.check(valid, valid_sources))

        manifest = json.loads(valid[MODULE.RELEASE_MANIFEST_PATH])
        evidence_record = next(
            item
            for item in manifest["nonGitFiles"]
            if item["role"] == "release-evidence-index"
        )
        evidence_document = json.loads(valid[evidence_record["path"]])
        demo = next(
            item
            for item in evidence_document["records"]
            if item["id"] == "golden-demo"
        )
        demo["artifacts"] = [
            artifact
            for artifact in demo["artifacts"]
            if artifact["path"] != "evidence/artifacts/figure-1.png"
        ]
        missing_content = json.dumps(
            evidence_document,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        missing = dict(valid)
        missing[evidence_record["path"]] = missing_content
        evidence_record["bytes"] = len(missing_content)
        evidence_record["sha256"] = hashlib.sha256(missing_content).hexdigest()
        missing[MODULE.RELEASE_MANIFEST_PATH] = json.dumps(
            manifest,
            separators=(",", ":"),
        ).encode("utf-8")
        missing_errors = self.check(missing, valid_sources)
        self.assertTrue(
            any("figure-1 图片未被 golden-demo artifacts 引用" in error for error in missing_errors)
        )

        stale = dict(valid)
        stale_sources = dict(valid_sources)
        unverified_plan = MODULE.COMPETITION_GATE.DEFAULT_PLAN_PATH.read_bytes()
        stale[MODULE.COMPETITION_PLAN_PATH] = unverified_plan
        stale_sources[MODULE.COMPETITION_PLAN_PATH] = unverified_plan
        stale_errors = self.check(stale, stale_sources)
        self.assertTrue(
            any("仍为未验证" in error and "必须迁移状态" in error for error in stale_errors)
        )

        mismatched = dict(valid)
        mismatched_sources = dict(valid_sources)
        mismatched_plan = valid[MODULE.COMPETITION_PLAN_PATH].decode("utf-8").replace(
            "level=模拟器通过",
            "level=真机通过",
            1,
        ).encode("utf-8")
        mismatched[MODULE.COMPETITION_PLAN_PATH] = mismatched_plan
        mismatched_sources[MODULE.COMPETITION_PLAN_PATH] = mismatched_plan
        mismatch_errors = self.check(mismatched, mismatched_sources)
        self.assertTrue(
            any("真机通过" in error and "模拟器通过" in error for error in mismatch_errors)
        )

    def test_golden_demo_rejects_fake_image_ui_tree_and_video_bytes(self) -> None:
        entries, sources, document = complete_fixture()
        valid, valid_sources = with_verified_golden_demo(entries, sources, document)
        fake = valid
        replacements = {
            "evidence/artifacts/figure-1.png": b"not a PNG",
            "evidence/artifacts/figure-2.png": b"still not a PNG",
            "evidence/artifacts/golden-demo-ui-tree.json": b"not a UI tree",
            "evidence/artifacts/golden-demo.mp4": b"not an MP4",
        }
        for path, content in replacements.items():
            fake = replace_evidence_artifact(fake, path, content)

        output = "\n".join(self.check(fake, valid_sources))

        self.assertIn("PNG 结构无效", output)
        self.assertIn("UI tree JSON 结构无效", output)
        self.assertIn("MP4 结构无效", output)

    def test_device_pass_requires_external_media_decoder(self) -> None:
        entries, sources, document = complete_fixture()
        valid, valid_sources = with_verified_golden_demo(entries, sources, document)

        errors = MODULE.check_release_bundle_entries(
            valid,
            valid_sources,
            SOURCE_COMMIT,
        )

        self.assertTrue(any("必须提供外部 ffprobe" in error for error in errors))

    def test_weak_png_and_empty_ui_tree_do_not_pass_structural_validation(self) -> None:
        def chunk(kind: bytes, payload: bytes) -> bytes:
            checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
            return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)

        invalid_ihdr = struct.pack(">IIBBBBB", 1, 1, 0, 6, 0, 0, 0)
        weak_png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", invalid_ihdr) + chunk(
            b"IDAT", b""
        ) + chunk(b"IEND", b"")
        empty_tree = json.dumps(
            {
                "attributes": {
                    "pagePath": "pages/Index",
                    "bounds": "[0,0][1260,2720]",
                },
                "children": [],
            }
        ).encode("utf-8")

        self.assertFalse(MODULE._png_structure_valid(weak_png))
        self.assertFalse(MODULE._ui_tree_structure_valid(empty_tree))

    def test_ffprobe_bytes_must_report_decoded_dimensions_and_duration(self) -> None:
        image_output = json.dumps(
            {
                "streams": [
                    {
                        "codec_type": "video",
                        "codec_name": "png",
                        "width": 2,
                        "height": 2,
                        "nb_read_frames": "1",
                    }
                ],
                "format": {"format_name": "png_pipe"},
            }
        ).encode("utf-8")
        video_output = json.dumps(
            {
                "streams": [
                    {
                        "codec_type": "video",
                        "codec_name": "h264",
                        "width": 1260,
                        "height": 2720,
                        "nb_read_frames": "1425",
                    }
                ],
                "format": {"format_name": "mov,mp4", "duration": "285.0"},
            }
        ).encode("utf-8")
        with mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=[
                MODULE.subprocess.CompletedProcess([], 0, image_output, b""),
                MODULE.subprocess.CompletedProcess([], 0, video_output, b""),
            ],
        ):
            image_errors = MODULE._ffprobe_media_errors(
                "evidence/artifacts/figure.png",
                "screenshot",
                png_bytes(),
                Path("C:/tools/ffprobe.exe"),
            )
            video_errors = MODULE._ffprobe_media_errors(
                "evidence/artifacts/demo.mp4",
                "video",
                mp4_bytes(),
                Path("C:/tools/ffprobe.exe"),
            )

        self.assertEqual([], image_errors)
        self.assertEqual([], video_errors)

    def test_ffprobe_rejects_unavailable_decoded_frame_count(self) -> None:
        unavailable_frame_output = json.dumps(
            {
                "streams": [
                    {
                        "codec_type": "video",
                        "codec_name": "h264",
                        "width": 1260,
                        "height": 2720,
                        "nb_read_frames": "N/A",
                    }
                ],
                "format": {"format_name": "mov,mp4", "duration": "285.0"},
            }
        ).encode("utf-8")
        with mock.patch.object(
            MODULE.subprocess,
            "run",
            return_value=MODULE.subprocess.CompletedProcess(
                [],
                0,
                unavailable_frame_output,
                b"",
            ),
        ):
            errors = MODULE._ffprobe_media_errors(
                "evidence/artifacts/demo.mp4",
                "video",
                mp4_bytes(),
                Path("C:/tools/ffprobe.exe"),
            )

        self.assertEqual(["黄金演示媒体未解码出正帧数"], errors)

    def test_ffprobe_rejects_nonempty_stderr_with_valid_metadata(self) -> None:
        valid_output = json.dumps(
            {
                "streams": [
                    {
                        "codec_type": "video",
                        "codec_name": "h264",
                        "width": 1260,
                        "height": 2720,
                        "nb_read_frames": "1425",
                    }
                ],
                "format": {"format_name": "mov,mp4", "duration": "285.0"},
            }
        ).encode("utf-8")
        with mock.patch.object(
            MODULE.subprocess,
            "run",
            return_value=MODULE.subprocess.CompletedProcess(
                [],
                0,
                valid_output,
                b"decoder warning",
            ),
        ):
            errors = MODULE._ffprobe_media_errors(
                "evidence/artifacts/demo.mp4",
                "video",
                mp4_bytes(),
                Path("C:/tools/ffprobe.exe"),
            )

        self.assertEqual(["黄金演示媒体 ffprobe 解码报告错误"], errors)

    def test_evidence_artifact_prefix_count_and_size_limits(self) -> None:
        _, _, outside_document = complete_fixture()
        outside_records = outside_document["nonGitFiles"]
        outside_records.append(
            file_record("release/evidence.log", MODULE.EVIDENCE_ARTIFACT_ROLE, b"x")
        )
        _, outside_errors = MODULE.parse_release_manifest(
            json.dumps(outside_document).encode("utf-8")
        )
        self.assertTrue(any("必须位于 evidence/artifacts/" in error for error in outside_errors))

        _, _, size_document = complete_fixture()
        size_records = size_document["nonGitFiles"]
        for index in range(5):
            size_records.append(
                {
                    "path": f"evidence/artifacts/large-{index}.mp4",
                    "role": MODULE.EVIDENCE_ARTIFACT_ROLE,
                    "bytes": MODULE.MAX_EVIDENCE_ARTIFACT_BYTES,
                    "sha256": "0" * 64,
                }
            )
        size_records[-1]["bytes"] = MODULE.MAX_EVIDENCE_ARTIFACT_BYTES + 1
        _, size_errors = MODULE.parse_release_manifest(
            json.dumps(size_document).encode("utf-8")
        )
        size_output = "\n".join(size_errors)
        self.assertIn("单项大小超过", size_output)
        self.assertIn("总大小超过", size_output)

        _, _, count_document = complete_fixture()
        count_records = count_document["nonGitFiles"]
        for index in range(MODULE.MAX_EVIDENCE_ARTIFACTS + 1):
            count_records.append(
                {
                    "path": f"evidence/artifacts/item-{index}.txt",
                    "role": MODULE.EVIDENCE_ARTIFACT_ROLE,
                    "bytes": 1,
                    "sha256": "0" * 64,
                }
            )
        _, count_errors = MODULE.parse_release_manifest(
            json.dumps(count_document).encode("utf-8")
        )
        self.assertTrue(any("项数超过内部上限" in error for error in count_errors))

    def test_git_source_cannot_masquerade_as_diagnostic_evidence(self) -> None:
        entries, sources, document = complete_fixture()
        records = document["nonGitFiles"]
        evidence_record = next(
            item for item in records if item["role"] == "release-evidence-index"
        )
        evidence_document = json.loads(entries[evidence_record["path"]])
        source_record = next(
            item for item in evidence_document["records"] if item["id"] == "source-package"
        )
        source_record["level"] = "静态诊断通过"
        source_record["command"] = ["python", "-B", "scripts/validate-competition-content.py"]
        source_record["exitCode"] = 0
        source_record["environment"] = {
            "os": "Windows 11",
            "tool": "python",
            "toolVersion": "3.12",
        }
        source_record["artifacts"] = [
            {
                "path": "README.md",
                "kind": "diagnostic",
                "bytes": len(entries["README.md"]),
                "sha256": hashlib.sha256(entries["README.md"]).hexdigest(),
            }
        ]
        evidence_content = json.dumps(
            evidence_document,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        entries[evidence_record["path"]] = evidence_content
        evidence_record["bytes"] = len(evidence_content)
        evidence_record["sha256"] = hashlib.sha256(evidence_content).hexdigest()

        errors = self.check(with_document(entries, document), sources)

        self.assertTrue(any("运行证据不得来自 Git 源文件" in error for error in errors))

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

    def test_release_evidence_empty_object_is_rejected_after_manifest_rehash(self) -> None:
        entries, sources, document = complete_fixture()

        mutated_entries = with_attachment(
            entries,
            document,
            "release/evidence.json",
            b"{}",
        )
        errors = self.check(mutated_entries, sources)
        output = "\n".join(errors)

        self.assertIn("发布证据索引 缺少字段", output)
        self.assertIn("发布证据索引缺少发布面", output)

    def test_release_evidence_commit_and_hap_bindings_use_bundle_bytes(self) -> None:
        entries, sources, document = complete_fixture()
        evidence_document = json.loads(entries["release/evidence.json"])
        evidence_document["sourceCommit"] = "b" * 40
        evidence_document["hapSha256"] = "c" * 64
        evidence_content = json.dumps(
            evidence_document,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")

        mutated_entries = with_attachment(
            entries,
            document,
            "release/evidence.json",
            evidence_content,
        )
        errors = self.check(mutated_entries, sources)
        output = "\n".join(errors)

        self.assertIn("sourceCommit 与 release-manifest.json 不一致", output)
        self.assertIn("hapSha256 与实际 HAP 字节不一致", output)

    def test_release_evidence_artifact_binds_actual_bundle_entry_bytes(self) -> None:
        entries, sources, document = complete_fixture()
        evidence_document = json.loads(entries["release/evidence.json"])
        source_record = next(
            item
            for item in evidence_document["records"]
            if item["id"] == "source-package"
        )
        source_content = entries["README.md"]
        source_record["level"] = "源码确认"
        source_record["artifacts"] = [
            {
                "path": "README.md",
                "kind": "source",
                "bytes": len(source_content),
                "sha256": hashlib.sha256(source_content).hexdigest(),
            }
        ]
        evidence_content = json.dumps(
            evidence_document,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        valid_entries = with_attachment(
            entries,
            document,
            "release/evidence.json",
            evidence_content,
        )

        self.assertEqual([], self.check(valid_entries, sources))

        source_record["artifacts"][0]["bytes"] += 1
        source_record["artifacts"][0]["sha256"] = "0" * 64
        invalid_content = json.dumps(
            evidence_document,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        invalid_entries = with_attachment(
            valid_entries,
            document,
            "release/evidence.json",
            invalid_content,
        )
        output = "\n".join(self.check(invalid_entries, sources))

        self.assertIn("bytes 与实际发布包条目不一致", output)
        self.assertIn("sha256 与实际发布包条目不一致", output)

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

        self.assertIn("条目原始文件名敏感信息命中", output)
        self.assertNotIn(secret_name, output)

    def test_raw_filename_divergence_is_rejected_for_outer_zip_and_hap(self) -> None:
        secret_value = b"ABCDEFGHIJKLMNOPQRSTUVWX"
        secret = b'MODEL_API_KEY="' + secret_value + b'"'
        raw_name = b"release\\README.md\x00" + secret
        malicious_zip = zip_with_raw_filename(raw_name)

        with zipfile.ZipFile(io.BytesIO(malicious_zip)) as archive:
            info = archive.infolist()[0]
            self.assertEqual(raw_name.decode("ascii"), info.orig_filename)
            self.assertNotEqual(info.orig_filename, info.filename)
            self.assertIn("\x00", info.orig_filename)
            self.assertNotIn("\x00", info.filename)

        _, outer_errors = MODULE.collect_zip_entries(
            io.BytesIO(malicious_zip),
            "最终 ZIP",
        )
        entries, sources, _ = complete_fixture(malicious_zip)
        hap_errors = self.check(entries, sources)

        for errors in (outer_errors, hap_errors):
            output = "\n".join(errors)
            self.assertIn("literal-server-secret", output)
            self.assertTrue(
                any(
                    "原始文件名" in error
                    and "解析文件名" in error
                    and "不一致" in error
                    for error in errors
                )
            )
            self.assertNotIn(secret.decode("ascii"), output)
            self.assertNotIn(secret_value.decode("ascii"), output)

    def test_valid_raw_filename_identity_remains_accepted(self) -> None:
        valid_zip = zip_bytes([("release/README.md", b"fixture")])
        with zipfile.ZipFile(io.BytesIO(valid_zip)) as archive:
            info = archive.infolist()[0]
            self.assertEqual(info.orig_filename, info.filename)

        entries, outer_errors = MODULE.collect_zip_entries(
            io.BytesIO(valid_zip),
            "最终 ZIP",
        )
        hap_errors = MODULE.check_hap_content("release/app.hap", valid_zip)

        self.assertEqual({"release/README.md": b"fixture"}, entries)
        self.assertEqual([], outer_errors)
        self.assertEqual([], hap_errors)

    def test_outer_zip_rejects_prefix_and_suffix_with_streamed_secret_scan(self) -> None:
        expected_entries, sources, _ = complete_fixture()
        valid_zip = zip_bytes(list(expected_entries.items()))
        secret_value = b"A" * 512
        secret = b"MODEL_" + b'API_KEY="' + secret_value + b'"'
        fixtures = (
            ("prefix", secret + valid_zip, "额外前缀"),
            ("suffix", valid_zip + secret, "尾随数据"),
        )

        for label, content, structure_error in fixtures:
            with self.subTest(label=label), mock.patch.object(
                MODULE,
                "RAW_SCAN_CHUNK_BYTES",
                17,
            ), mock.patch.object(MODULE, "RAW_SCAN_OVERLAP_BYTES", 64):
                entries, container_errors = MODULE.collect_zip_entries(
                    io.BytesIO(content),
                    "最终 ZIP",
                )
            semantic_errors = self.check(entries, sources)
            output = "\n".join(container_errors + semantic_errors)

            if label == "prefix":
                self.assertEqual({}, entries)
            else:
                self.assertEqual(expected_entries, entries)
                self.assertEqual([], semantic_errors)
            self.assertIn(structure_error, output)
            self.assertIn("ZIP 原始容器敏感信息命中 (literal-server-secret)", output)
            self.assertNotIn(secret.decode("ascii"), output)
            self.assertNotIn(secret_value.decode("ascii"), output)

        zip_header_prefix = MODULE.ZIP_LOCAL_FILE_HEADER + (b"\x00" * 26)
        disguised_entries, disguised_errors = MODULE.collect_zip_entries(
            io.BytesIO(zip_header_prefix + valid_zip),
            "最终 ZIP",
        )
        self.assertEqual({}, disguised_entries)
        self.assertTrue(
            any("本地文件头不在偏移 0" in error for error in disguised_errors)
        )

    def test_outer_and_hap_resource_limits_block_reads(self) -> None:
        two_entries = zip_bytes([("one.txt", b"1234"), ("two.txt", b"5678")])
        with mock.patch.object(MODULE, "MAX_ARCHIVE_ENTRIES", 1), mock.patch.object(
            MODULE.zipfile.ZipFile,
            "read",
            side_effect=AssertionError("read must not run after global limit failure"),
        ) as reader:
            entries, count_errors = MODULE.collect_zip_entries(
                io.BytesIO(two_entries),
                "最终 ZIP",
            )
        self.assertEqual({}, entries)
        self.assertTrue(any("条目数超过内部上限" in error for error in count_errors))
        reader.assert_not_called()

        with mock.patch.object(MODULE, "MAX_OUTER_TOTAL_BYTES", 7), mock.patch.object(
            MODULE.zipfile.ZipFile,
            "read",
            side_effect=AssertionError("read must not run after total limit failure"),
        ) as reader:
            entries, total_errors = MODULE.collect_zip_entries(
                io.BytesIO(two_entries),
                "最终 ZIP",
            )
        self.assertEqual({}, entries)
        self.assertTrue(any("解压后总大小超过内部上限" in error for error in total_errors))
        reader.assert_not_called()

        one_entry = zip_bytes([("large.txt", b"1234")])
        with mock.patch.object(MODULE, "MAX_OUTER_ENTRY_BYTES", 3), mock.patch.object(
            MODULE.zipfile.ZipFile,
            "read",
            side_effect=AssertionError("read must not run after entry limit failure"),
        ) as reader:
            entries, entry_errors = MODULE.collect_zip_entries(
                io.BytesIO(one_entry),
                "最终 ZIP",
            )
        self.assertEqual({}, entries)
        self.assertTrue(any("条目解压大小超过内部上限" in error for error in entry_errors))
        reader.assert_not_called()

        compressed = zip_bytes([("repeated.txt", b"A" * 4096)])
        with mock.patch.object(MODULE, "MAX_ARCHIVE_COMPRESSION_RATIO", 2), mock.patch.object(
            MODULE.zipfile.ZipFile,
            "read",
            side_effect=AssertionError("read must not run after ratio failure"),
        ) as reader:
            entries, ratio_errors = MODULE.collect_zip_entries(
                io.BytesIO(compressed),
                "最终 ZIP",
            )
        self.assertEqual({}, entries)
        self.assertTrue(any("条目压缩比超过内部上限" in error for error in ratio_errors))
        reader.assert_not_called()

        with mock.patch.object(MODULE, "MAX_HAP_ENTRY_BYTES", 3), mock.patch.object(
            MODULE.zipfile.ZipFile,
            "read",
            side_effect=AssertionError("HAP read must not run after entry limit failure"),
        ) as reader:
            hap_errors = MODULE.check_hap_content("release/app.hap", one_entry)
        self.assertTrue(any("条目解压大小超过内部上限" in error for error in hap_errors))
        reader.assert_not_called()

    def test_zip_entry_view_streams_compare_hash_and_secret_scan(self) -> None:
        content = b"fixed streamed entry content"
        archive_bytes = zip_bytes([("evidence/artifacts/fixed.txt", content)])
        with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
            infos, errors = MODULE._archive_infos(
                archive,
                "固定输入 ZIP",
                max_entry_bytes=MODULE.MAX_OUTER_ENTRY_BYTES,
                max_total_bytes=MODULE.MAX_OUTER_TOTAL_BYTES,
                require_first_header_at_zero=True,
            )
            view = MODULE.ZipEntryView(archive, infos)
            with mock.patch.object(
                archive,
                "read",
                side_effect=AssertionError("stream operations must not use ZipFile.read"),
            ) as reader:
                self.assertEqual(len(content), view.byte_count("evidence/artifacts/fixed.txt"))
                self.assertEqual(
                    hashlib.sha256(content).hexdigest(),
                    view.sha256("evidence/artifacts/fixed.txt"),
                )
                self.assertTrue(view.matches("evidence/artifacts/fixed.txt", content))
                self.assertEqual([], view.secret_hits("evidence/artifacts/fixed.txt"))
            reader.assert_not_called()
        self.assertEqual([], errors)

    def test_invalid_utf8_filename_is_a_structured_outer_and_hap_failure(self) -> None:
        malformed = zip_with_invalid_utf8_filename()

        entries, outer_errors = MODULE.collect_zip_entries(
            io.BytesIO(malformed),
            "最终 ZIP",
        )
        hap_errors = MODULE.check_hap_content("release/app.hap", malformed)
        output = "\n".join(outer_errors + hap_errors)

        self.assertEqual({}, entries)
        self.assertEqual(2, output.count("UnicodeDecodeError"))
        self.assertNotIn("0xff", output.casefold())
        self.assertNotIn("nvalid.bin", output)

    def test_dynamic_import_disables_bytecode_writes(self) -> None:
        self.assertTrue(MODULE.sys.dont_write_bytecode)

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
