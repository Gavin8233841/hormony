#!/usr/bin/env python3
"""只读核验竞赛正式 PDF、MP4 与 Demo/源码 ZIP 三文件。"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import math
import os
import re
import subprocess
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import BinaryIO, NamedTuple


sys.dont_write_bytecode = True

RELEASE_GATE_PATH = Path(__file__).with_name("validate-release-bundle.py")
RELEASE_GATE_SPEC = importlib.util.spec_from_file_location(
    "validate_release_bundle_for_official_deliverables",
    RELEASE_GATE_PATH,
)
if RELEASE_GATE_SPEC is None or RELEASE_GATE_SPEC.loader is None:
    raise RuntimeError(f"无法加载发布包门禁: {RELEASE_GATE_PATH}")
RELEASE_GATE = importlib.util.module_from_spec(RELEASE_GATE_SPEC)
RELEASE_GATE_SPEC.loader.exec_module(RELEASE_GATE)

PDF_PAGE_LIMIT = 20
VIDEO_DURATION_LIMIT_SECONDS = Decimal("300")
DEFAULT_TOOL_TIMEOUT_SECONDS = 20.0
MAX_TOOL_OUTPUT_BYTES = 1024 * 1024
HASH_CHUNK_BYTES = 1024 * 1024
PDF_PAGES_PATTERN = re.compile(rb"(?m)^Pages:[ \t]*([0-9]{1,9})[ \t]*\r?$")
PDF_ENCRYPTED_PATTERN = re.compile(
    rb"(?mi)^Encrypted:[ \t]*(yes|no)(?:[ \t].*)?\r?$"
)


class ArtifactEvidence(NamedTuple):
    label: str
    byte_count: int
    sha256: str
    details: str


class PdfProbe(NamedTuple):
    pages: int
    encrypted: bool | None


class VideoProbe(NamedTuple):
    duration_seconds: Decimal
    video_stream_count: int
    format_names: tuple[str, ...]


def expected_filenames(team_name: str, work_name: str) -> tuple[str, str, str]:
    return (
        f"01-作品说明文档+{team_name}.pdf",
        f"02-演示视频+{team_name}.mp4",
        f"03-{work_name}+{team_name}.zip",
    )


def _name_errors(value: str, label: str) -> list[str]:
    if not value or value.strip() != value:
        return [f"{label}不得为空或包含首尾空白"]
    if value in {".", ".."}:
        return [f"{label}不得是路径保留段"]
    if any(character in value for character in ("/", "\\", "\0")):
        return [f"{label}不得包含路径分隔符或 NUL"]
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        return [f"{label}不得包含控制字符"]
    return []


def artifact_path_errors(
    path: Path,
    expected_filename: str,
    expected_suffix: str,
    label: str,
) -> list[str]:
    errors: list[str] = []
    try:
        is_symlink = path.is_symlink()
    except OSError:
        is_symlink = False
        errors.append(f"{label}路径元数据无法读取")
    if is_symlink:
        errors.append(f"{label}文件拒绝符号链接")

    try:
        is_file = path.is_file()
    except OSError:
        is_file = False
    if not is_file:
        errors.append(f"{label}路径必须指向现有普通文件")
    if path.suffix != expected_suffix:
        errors.append(f"{label}后缀必须精确为 {expected_suffix}")
    if path.name != expected_filename:
        errors.append(f"{label}文件名不符合正式命名合同")
    return errors


def hash_stream(
    stream: BinaryIO,
    chunk_bytes: int = HASH_CHUNK_BYTES,
) -> tuple[int, str]:
    if chunk_bytes <= 0:
        raise ValueError("chunk_bytes 必须大于 0")
    digest = hashlib.sha256()
    byte_count = 0
    while True:
        chunk = stream.read(chunk_bytes)
        if not chunk:
            break
        digest.update(chunk)
        byte_count += len(chunk)
    return byte_count, digest.hexdigest()


def hash_file(path: Path) -> tuple[int, str]:
    with path.open("rb") as stream:
        return hash_stream(stream)


def tool_path_errors(path: Path, label: str) -> list[str]:
    errors: list[str] = []
    if not path.is_absolute():
        errors.append(f"{label}工具路径必须是绝对路径")
    try:
        is_symlink = path.is_symlink()
    except OSError:
        is_symlink = False
        errors.append(f"{label}工具路径元数据无法读取")
    if is_symlink:
        errors.append(f"{label}工具拒绝符号链接")
    try:
        is_file = path.is_file()
    except OSError:
        is_file = False
    if not is_file:
        errors.append(f"{label}工具路径必须指向现有普通文件")
    return errors


def run_tool(
    command_path: Path,
    arguments: list[str],
    label: str,
    timeout_seconds: float,
) -> tuple[bytes | None, list[str]]:
    path_errors = tool_path_errors(command_path, label)
    if path_errors:
        return None, path_errors
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    environment["LANG"] = "C"
    try:
        result = subprocess.run(
            [str(command_path), *arguments],
            check=False,
            capture_output=True,
            timeout=timeout_seconds,
            env=environment,
            shell=False,
        )
    except FileNotFoundError:
        return None, [f"{label}工具不可用"]
    except subprocess.TimeoutExpired:
        return None, [f"{label}工具执行超时"]
    except (OSError, ValueError) as error:
        return None, [f"{label}工具无法启动 ({type(error).__name__})"]

    if result.returncode != 0:
        return None, [f"{label}工具返回非零退出码: {result.returncode}"]
    if not isinstance(result.stdout, bytes):
        return None, [f"{label}工具输出类型无效"]
    if len(result.stdout) > MAX_TOOL_OUTPUT_BYTES:
        return None, [f"{label}工具输出超过内部解析上限"]
    return result.stdout, []


def parse_pdfinfo_output(output: bytes) -> tuple[PdfProbe | None, list[str]]:
    matches = PDF_PAGES_PATTERN.findall(output)
    if len(matches) != 1:
        return None, ["pdfinfo 输出缺少唯一有效 Pages 字段"]
    pages = int(matches[0])
    if pages < 1:
        return None, ["PDF 页数必须大于 0"]
    errors: list[str] = []
    encrypted_matches = PDF_ENCRYPTED_PATTERN.findall(output)
    if len(encrypted_matches) != 1:
        errors.append("pdfinfo 输出缺少唯一有效 Encrypted 字段")
        encrypted: bool | None = None
    else:
        encrypted = encrypted_matches[0].lower() == b"yes"
    if encrypted:
        errors.append("PDF 不得加密")
    if pages > PDF_PAGE_LIMIT:
        errors.append(f"PDF 整份页数超过内部硬门禁 {PDF_PAGE_LIMIT} 页")
    return PdfProbe(pages, encrypted), errors


def parse_ffprobe_output(output: bytes) -> tuple[VideoProbe | None, list[str]]:
    try:
        document = json.loads(output)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return None, ["ffprobe 输出不是有效 JSON"]
    if not isinstance(document, dict):
        return None, ["ffprobe 输出顶层必须是对象"]

    streams = document.get("streams")
    format_record = document.get("format")
    if not isinstance(streams, list) or not isinstance(format_record, dict):
        return None, ["ffprobe 输出缺少 streams 或 format 对象"]
    if any(not isinstance(stream, dict) for stream in streams):
        return None, ["ffprobe streams 包含无效条目"]

    duration_value = format_record.get("duration")
    format_name_value = format_record.get("format_name")
    if not isinstance(duration_value, str) or not isinstance(format_name_value, str):
        return None, ["ffprobe 输出缺少字符串 duration 或 format_name 字段"]
    try:
        duration = Decimal(duration_value)
    except InvalidOperation:
        return None, ["ffprobe duration 字段无效"]
    if not duration.is_finite() or duration <= 0:
        return None, ["MP4 时长必须是大于 0 的有限数值"]

    video_stream_count = sum(
        stream.get("codec_type") == "video" for stream in streams
    )
    format_names = tuple(format_name_value.split(","))
    errors: list[str] = []
    if video_stream_count < 1:
        errors.append("MP4 至少需要一个视频流")
    if not format_names or any(not name for name in format_names) or "mp4" not in format_names:
        errors.append("ffprobe format_name 必须包含精确的 mp4 token")
    if duration > VIDEO_DURATION_LIMIT_SECONDS:
        errors.append("MP4 时长不得超过 300 秒")
    return VideoProbe(duration, video_stream_count, format_names), errors


def probe_pdf(
    path: Path,
    command_path: Path,
    timeout_seconds: float,
) -> tuple[PdfProbe | None, list[str]]:
    output, errors = run_tool(
        command_path, [str(path)], "pdfinfo", timeout_seconds
    )
    if output is None:
        return None, errors
    probe, parse_errors = parse_pdfinfo_output(output)
    return probe, [*errors, *parse_errors]


def probe_video(
    path: Path,
    command_path: Path,
    timeout_seconds: float,
) -> tuple[VideoProbe | None, list[str]]:
    output, errors = run_tool(
        command_path,
        [
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type:format=format_name,duration",
            "-of",
            "json",
            str(path),
        ],
        "ffprobe",
        timeout_seconds,
    )
    if output is None:
        return None, errors
    probe, parse_errors = parse_ffprobe_output(output)
    return probe, [*errors, *parse_errors]


def run_release_bundle_gate(path: Path) -> list[str]:
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            exit_code = RELEASE_GATE.main(["--bundle-path", str(path)])
    except SystemExit as error:
        exit_code = error.code if isinstance(error.code, int) else 1
    except Exception as error:  # pragma: no cover - defensive boundary
        return [f"ZIP 发布包门禁异常 ({type(error).__name__})"]
    if exit_code != 0:
        return [f"ZIP 未通过 validate-release-bundle.py，exit={exit_code}"]
    return []


def _hash_evidence(
    path: Path,
    label: str,
    details: str,
) -> tuple[ArtifactEvidence | None, list[str]]:
    try:
        byte_count, sha256 = hash_file(path)
    except OSError as error:
        return None, [f"{label}无法完成只读哈希 ({type(error).__name__})"]
    return ArtifactEvidence(label, byte_count, sha256, details), []


def validate_official_deliverables(
    pdf_path: Path,
    video_path: Path,
    bundle_path: Path,
    team_name: str,
    work_name: str,
    pdfinfo_path: Path,
    ffprobe_path: Path,
    timeout_seconds: float = DEFAULT_TOOL_TIMEOUT_SECONDS,
) -> tuple[list[ArtifactEvidence], list[str]]:
    errors = [
        *_name_errors(team_name, "team-name"),
        *_name_errors(work_name, "work-name"),
    ]
    if errors:
        return [], errors
    pdf_filename, video_filename, bundle_filename = expected_filenames(
        team_name, work_name
    )

    specifications = (
        (pdf_path, pdf_filename, ".pdf", "PDF"),
        (video_path, video_filename, ".mp4", "MP4"),
        (bundle_path, bundle_filename, ".zip", "ZIP"),
    )
    valid_labels: set[str] = set()
    for path, filename, suffix, label in specifications:
        path_errors = artifact_path_errors(path, filename, suffix, label)
        errors.extend(path_errors)
        if not path_errors:
            valid_labels.add(label)

    evidence: list[ArtifactEvidence] = []
    if "PDF" in valid_labels:
        pdf_probe, probe_errors = probe_pdf(
            pdf_path, pdfinfo_path, timeout_seconds
        )
        errors.extend(probe_errors)
        if pdf_probe is None:
            details = "pages=unavailable; encrypted=unavailable"
        else:
            encrypted = (
                "unavailable"
                if pdf_probe.encrypted is None
                else "yes" if pdf_probe.encrypted else "no"
            )
            details = f"pages={pdf_probe.pages}; encrypted={encrypted}"
        item, hash_errors = _hash_evidence(pdf_path, "PDF", details)
        errors.extend(hash_errors)
        if item is not None:
            evidence.append(item)

    if "MP4" in valid_labels:
        video_probe, probe_errors = probe_video(
            video_path, ffprobe_path, timeout_seconds
        )
        errors.extend(probe_errors)
        if video_probe is None:
            details = (
                "duration=unavailable; videoStreams=unavailable; "
                "format=unavailable"
            )
        else:
            detected_formats = ",".join(video_probe.format_names) or "unavailable"
            details = (
                f"duration={format(video_probe.duration_seconds, 'f')}s; "
                f"videoStreams={video_probe.video_stream_count}; "
                f"format={detected_formats}"
            )
        item, hash_errors = _hash_evidence(video_path, "MP4", details)
        errors.extend(hash_errors)
        if item is not None:
            evidence.append(item)

    if "ZIP" in valid_labels:
        release_gate_errors = run_release_bundle_gate(bundle_path)
        errors.extend(release_gate_errors)
        item, hash_errors = _hash_evidence(
            bundle_path,
            "ZIP",
            "releaseBundleGate=" + ("failed" if release_gate_errors else "passed"),
        )
        errors.extend(hash_errors)
        if item is not None:
            evidence.append(item)
    return evidence, errors


def _positive_timeout(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("必须是数值") from error
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("必须是大于 0 的有限数值")
    return parsed


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdf-path", type=Path, required=True)
    parser.add_argument("--video-path", type=Path, required=True)
    parser.add_argument("--bundle-path", type=Path, required=True)
    parser.add_argument("--team-name", required=True)
    parser.add_argument("--work-name", required=True)
    parser.add_argument("--pdfinfo-path", type=Path, required=True)
    parser.add_argument("--ffprobe-path", type=Path, required=True)
    parser.add_argument(
        "--tool-timeout-seconds",
        type=_positive_timeout,
        default=DEFAULT_TOOL_TIMEOUT_SECONDS,
    )
    return parser.parse_args(argv)


def _print_evidence(evidence: list[ArtifactEvidence]) -> None:
    for item in evidence:
        print(
            f"  - {item.label}: {item.details}; bytes={item.byte_count}; "
            f"sha256={item.sha256}"
        )


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    evidence, errors = validate_official_deliverables(
        pdf_path=args.pdf_path,
        video_path=args.video_path,
        bundle_path=args.bundle_path,
        team_name=args.team_name,
        work_name=args.work_name,
        pdfinfo_path=args.pdfinfo_path,
        ffprobe_path=args.ffprobe_path,
        timeout_seconds=args.tool_timeout_seconds,
    )
    if errors:
        print(f"[FAIL] 正式三文件门禁: {len(errors)} 项")
        _print_evidence(evidence)
        for error in errors:
            print(f"  - {error}")
        print("\nSOME CHECKS FAILED")
        return 1

    print("[PASS] 正式三文件门禁")
    _print_evidence(evidence)
    print(
        "证据边界: 仅证明本地三文件的精确命名、格式元数据、只读哈希及 "
        "Demo/源码 ZIP 门禁通过；不证明官方模板内容、视频完整播放、HAP 安装运行或门户上传通过。"
    )
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
