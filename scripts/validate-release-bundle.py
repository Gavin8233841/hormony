#!/usr/bin/env python3
"""只读核验最终 Demo/源码 ZIP、Git 源码快照与非 Git 附件。"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
import math
import os
import re
import struct
import subprocess
import sys
import zipfile
import zlib
from collections.abc import Callable, Iterator, Mapping
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import BinaryIO, NamedTuple


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
CONTENT_GATE_PATH = Path(__file__).with_name("validate-competition-content.py")
CONTENT_GATE_SPEC = importlib.util.spec_from_file_location(
    "validate_competition_content_for_release",
    CONTENT_GATE_PATH,
)
if CONTENT_GATE_SPEC is None or CONTENT_GATE_SPEC.loader is None:
    raise RuntimeError(f"无法加载内容门禁: {CONTENT_GATE_PATH}")
CONTENT_GATE = importlib.util.module_from_spec(CONTENT_GATE_SPEC)
CONTENT_GATE_SPEC.loader.exec_module(CONTENT_GATE)

EVIDENCE_GATE_PATH = Path(__file__).with_name("validate-release-evidence.py")
EVIDENCE_GATE_SPEC = importlib.util.spec_from_file_location(
    "validate_release_evidence_for_bundle",
    EVIDENCE_GATE_PATH,
)
if EVIDENCE_GATE_SPEC is None or EVIDENCE_GATE_SPEC.loader is None:
    raise RuntimeError(f"无法加载发布证据索引门禁: {EVIDENCE_GATE_PATH}")
EVIDENCE_GATE = importlib.util.module_from_spec(EVIDENCE_GATE_SPEC)
EVIDENCE_GATE_SPEC.loader.exec_module(EVIDENCE_GATE)

COMPETITION_GATE_PATH = Path(__file__).with_name("validate-competition-evidence.py")
COMPETITION_GATE_SPEC = importlib.util.spec_from_file_location(
    "validate_competition_evidence_for_bundle",
    COMPETITION_GATE_PATH,
)
if COMPETITION_GATE_SPEC is None or COMPETITION_GATE_SPEC.loader is None:
    raise RuntimeError(f"无法加载评分证据门禁: {COMPETITION_GATE_PATH}")
COMPETITION_GATE = importlib.util.module_from_spec(COMPETITION_GATE_SPEC)
COMPETITION_GATE_SPEC.loader.exec_module(COMPETITION_GATE)

RELEASE_MANIFEST_PATH = "release-manifest.json"
COMPETITION_PLAN_PATH = COMPETITION_GATE.DEFAULT_PLAN_PATH.relative_to(ROOT).as_posix()
RELEASE_MANIFEST_FIELDS = frozenset({"sourceCommit", "nonGitFiles"})
NON_GIT_FILE_FIELDS = frozenset({"path", "role", "bytes", "sha256"})
REQUIRED_NON_GIT_ROLES = frozenset(
    {
        "hap",
        "third-party-license-index",
        "originality-declaration",
        "ai-usage-declaration",
        "release-evidence-index",
    }
)
EVIDENCE_ARTIFACT_ROLE = "evidence-artifact"
ALLOWED_NON_GIT_ROLES = REQUIRED_NON_GIT_ROLES | {EVIDENCE_ARTIFACT_ROLE}
EVIDENCE_ARTIFACT_PREFIX = EVIDENCE_GATE.EVIDENCE_ARTIFACT_PREFIX
EVIDENCE_ARTIFACT_SUFFIXES = frozenset(
    {".har", ".jpeg", ".jpg", ".json", ".log", ".mp4", ".png", ".txt", ".xml"}
)
MAX_EVIDENCE_ARTIFACTS = 50
MAX_EVIDENCE_ARTIFACT_BYTES = 64 * 1024 * 1024
MAX_EVIDENCE_ARTIFACT_TOTAL_BYTES = 256 * 1024 * 1024
MAX_SCREENSHOT_PARSE_BYTES = 32 * 1024 * 1024
MAX_UI_TREE_PARSE_BYTES = 8 * 1024 * 1024
MAX_IMAGE_DIMENSION_PX = 32768
MAX_MEDIA_PROBE_OUTPUT_BYTES = 1024 * 1024
DEFAULT_MEDIA_PROBE_TIMEOUT_SECONDS = 20.0
FULL_COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
MAX_RELEASE_MANIFEST_BYTES = 64 * 1024
MAX_COMPETITION_PLAN_BYTES = 256 * 1024
MAX_ARCHIVE_PATH_BYTES = 512
MAX_ARCHIVE_ENTRIES = 10_000
MAX_ARCHIVE_COMPRESSION_RATIO = 200
MAX_OUTER_ENTRY_BYTES = 512 * 1024 * 1024
MAX_OUTER_TOTAL_BYTES = 1024 * 1024 * 1024
MAX_HAP_ENTRY_BYTES = 64 * 1024 * 1024
MAX_HAP_TOTAL_BYTES = 256 * 1024 * 1024
RAW_SCAN_CHUNK_BYTES = 1024 * 1024
RAW_SCAN_OVERLAP_BYTES = 4096
ZIP_LOCAL_FILE_HEADER = b"PK\x03\x04"
ZIP_END_OF_CENTRAL_DIRECTORY = b"PK\x05\x06"
ZIP_END_OF_CENTRAL_DIRECTORY_BYTES = 22
ZIP_MAX_COMMENT_BYTES = 65_535
STREAM_SECRET_PREFIX_RULES = (
    (
        "literal-bearer-authorization",
        re.compile(
            rb"\bAuthorization\b\s*[:=]\s*[\"']Bearer [A-Za-z0-9._~+/-]{12}",
            re.IGNORECASE,
        ),
    ),
    (
        "literal-server-secret",
        re.compile(
            rb"\b(?:MODEL_API_KEY|VERCEL_TOKEN)\b\s*[:=]\s*[\"'](?!<)[^\"'\r\n]{16}"
        ),
    ),
)
REGULAR_GIT_MODES = frozenset({"100644", "100755"})
UI_TREE_BOUNDS_PATTERN = re.compile(
    r"^\[(-?[0-9]+),(-?[0-9]+)\]\[(-?[0-9]+),(-?[0-9]+)\]$"
)


class NonGitFileRecord(NamedTuple):
    path: str
    role: str
    byte_count: int
    sha256: str


class ReleaseManifest(NamedTuple):
    source_commit: str | None
    non_git_files: tuple[NonGitFileRecord, ...]


class GitTreeRecord(NamedTuple):
    mode: str
    object_type: str
    object_id: str


class DuplicateJsonKeyError(ValueError):
    pass


class ZipEntryView(Mapping[str, bytes]):
    def __init__(
        self,
        archive: zipfile.ZipFile,
        infos: list[zipfile.ZipInfo],
    ) -> None:
        self._archive = archive
        self._infos = {info.filename: info for info in infos}
        self._hashes: dict[str, str] = {}

    def __getitem__(self, name: str) -> bytes:
        info = self._infos.get(name)
        if info is None:
            raise KeyError(name)
        return self._archive.read(info)

    def __iter__(self) -> Iterator[str]:
        return iter(self._infos)

    def __len__(self) -> int:
        return len(self._infos)

    def byte_count(self, name: str) -> int:
        return self._infos[name].file_size

    def sha256(self, name: str) -> str:
        cached = self._hashes.get(name)
        if cached is not None:
            return cached
        digest = hashlib.sha256()
        with self._archive.open(self._infos[name]) as handle:
            while True:
                chunk = handle.read(RAW_SCAN_CHUNK_BYTES)
                if not chunk:
                    break
                digest.update(chunk)
        value = digest.hexdigest()
        self._hashes[name] = value
        return value

    def matches(self, name: str, expected: bytes) -> bool:
        offset = 0
        with self._archive.open(self._infos[name]) as handle:
            while True:
                chunk = handle.read(RAW_SCAN_CHUNK_BYTES)
                if not chunk:
                    break
                if expected[offset : offset + len(chunk)] != chunk:
                    return False
                offset += len(chunk)
        return offset == len(expected)

    def secret_hits(self, name: str) -> list[str]:
        with self._archive.open(self._infos[name]) as handle:
            return _stream_secret_hits(handle)


def _entry_byte_count(entries: Mapping[str, bytes], name: str) -> int:
    if isinstance(entries, ZipEntryView):
        return entries.byte_count(name)
    return len(entries[name])


def _entry_sha256(entries: Mapping[str, bytes], name: str) -> str:
    if isinstance(entries, ZipEntryView):
        return entries.sha256(name)
    return hashlib.sha256(entries[name]).hexdigest()


def _entry_matches(
    entries: Mapping[str, bytes],
    name: str,
    expected: bytes,
) -> bool:
    if isinstance(entries, ZipEntryView):
        return entries.matches(name, expected)
    return entries[name] == expected


def _entry_secret_hits(entries: Mapping[str, bytes], name: str) -> list[str]:
    if isinstance(entries, ZipEntryView):
        return entries.secret_hits(name)
    return _secret_hits(entries[name])


def _secret_hits(content: bytes) -> list[str]:
    return [
        rule_name
        for rule_name, rule in CONTENT_GATE.SECRET_RULES
        if rule.search(content)
    ]


def _stream_secret_hits(handle: BinaryIO) -> list[str]:
    hits: set[str] = set()
    overlap = b""
    while True:
        chunk = handle.read(RAW_SCAN_CHUNK_BYTES)
        if not chunk:
            break
        window = overlap + chunk
        hits.update(_secret_hits(window))
        hits.update(
            rule_name
            for rule_name, rule in STREAM_SECRET_PREFIX_RULES
            if rule.search(window)
        )
        overlap = window[-RAW_SCAN_OVERLAP_BYTES:]
    return sorted(hits)


def _png_structure_valid(content: bytes) -> bool:
    if not content.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    offset = 8
    seen_ihdr = False
    seen_idat = False
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    idat_parts: list[bytes] = []
    while offset + 12 <= len(content):
        length = struct.unpack_from(">I", content, offset)[0]
        kind = content[offset + 4 : offset + 8]
        payload_start = offset + 8
        payload_end = payload_start + length
        crc_end = payload_end + 4
        if crc_end > len(content):
            return False
        expected_crc = struct.unpack_from(">I", content, payload_end)[0]
        actual_crc = zlib.crc32(kind + content[payload_start:payload_end]) & 0xFFFFFFFF
        if expected_crc != actual_crc:
            return False
        if not seen_ihdr:
            if kind != b"IHDR" or length != 13:
                return False
            width, height, bit_depth, color_type, compression, filter_method, interlace = (
                struct.unpack_from(">IIBBBBB", content, payload_start)
            )
            if not (0 < width <= MAX_IMAGE_DIMENSION_PX and 0 < height <= MAX_IMAGE_DIMENSION_PX):
                return False
            valid_depths = {
                0: {1, 2, 4, 8, 16},
                2: {8, 16},
                3: {1, 2, 4, 8},
                4: {8, 16},
                6: {8, 16},
            }
            if (
                bit_depth not in valid_depths.get(color_type, set())
                or compression != 0
                or filter_method != 0
                or interlace != 0
            ):
                return False
            seen_ihdr = True
        elif kind == b"IHDR":
            return False
        if kind == b"IDAT":
            seen_idat = True
            idat_parts.append(content[payload_start:payload_end])
        if kind == b"IEND":
            if length != 0 or not seen_ihdr or not seen_idat or crc_end != len(content):
                return False
            try:
                decoded = zlib.decompress(b"".join(idat_parts))
            except zlib.error:
                return False
            channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
            row_bytes = (width * channels * bit_depth + 7) // 8
            stride = row_bytes + 1
            return (
                len(decoded) == height * stride
                and all(decoded[row * stride] <= 4 for row in range(height))
            )
        offset = crc_end
    return False


def _jpeg_structure_valid(content: bytes) -> bool:
    if len(content) < 4 or not content.startswith(b"\xff\xd8") or not content.endswith(b"\xff\xd9"):
        return False
    offset = 2
    saw_dimensions = False
    sof_markers = {
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
        0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
    }
    while offset < len(content) - 2:
        if content[offset] != 0xFF:
            return False
        while offset < len(content) and content[offset] == 0xFF:
            offset += 1
        if offset >= len(content):
            return False
        marker = content[offset]
        offset += 1
        if marker == 0xD9:
            break
        if marker in {0x01, *range(0xD0, 0xD8)}:
            continue
        if offset + 2 > len(content):
            return False
        segment_length = struct.unpack_from(">H", content, offset)[0]
        if segment_length < 2 or offset + segment_length > len(content):
            return False
        if marker in sof_markers:
            if segment_length < 7:
                return False
            height, width = struct.unpack_from(">HH", content, offset + 3)
            if not (0 < width <= MAX_IMAGE_DIMENSION_PX and 0 < height <= MAX_IMAGE_DIMENSION_PX):
                return False
            saw_dimensions = True
        if marker == 0xDA:
            return saw_dimensions and content.endswith(b"\xff\xd9")
        offset += segment_length
    return saw_dimensions


def _ui_tree_structure_valid(content: bytes) -> bool:
    try:
        root = json.loads(content, object_pairs_hook=EVIDENCE_GATE._strict_object)
    except (
        UnicodeDecodeError,
        json.JSONDecodeError,
        EVIDENCE_GATE.DuplicateJsonKeyError,
        RecursionError,
        ValueError,
    ):
        return False
    if not isinstance(root, dict):
        return False
    attributes = root.get("attributes")
    children = root.get("children")
    if not isinstance(attributes, dict) or not isinstance(children, list):
        return False
    if (
        not isinstance(attributes.get("pagePath"), str)
        or not attributes["pagePath"].startswith("pages/")
    ):
        return False
    bounds = attributes.get("bounds")
    match = UI_TREE_BOUNDS_PATTERN.fullmatch(bounds) if isinstance(bounds, str) else None
    if match is None:
        return False
    left, top, right, bottom = (int(value) for value in match.groups())
    if right <= left or bottom <= top or not children:
        return False
    stack = list(children)
    visited = 0
    while stack:
        node = stack.pop()
        visited += 1
        if visited > 100_000 or not isinstance(node, dict):
            return False
        node_children = node.get("children", [])
        if not isinstance(node_children, list):
            return False
        stack.extend(node_children)
        node_attributes = node.get("attributes")
        if not isinstance(node_attributes, dict):
            continue
        visible = node_attributes.get("visible") in {True, "true"}
        text = node_attributes.get("text")
        node_bounds = node_attributes.get("bounds")
        node_match = (
            UI_TREE_BOUNDS_PATTERN.fullmatch(node_bounds)
            if isinstance(node_bounds, str)
            else None
        )
        if visible and isinstance(text, str) and text.strip() and node_match is not None:
            node_left, node_top, node_right, node_bottom = (
                int(value) for value in node_match.groups()
            )
            if node_right > node_left and node_bottom > node_top:
                return True
    return False


def _mp4_boxes(
    content: bytes,
    start: int,
    end: int,
) -> list[tuple[bytes, int, int]] | None:
    boxes: list[tuple[bytes, int, int]] = []
    offset = start
    while offset < end:
        if offset + 8 > end:
            return None
        size = struct.unpack_from(">I", content, offset)[0]
        kind = content[offset + 4 : offset + 8]
        header_size = 8
        if size == 1:
            if offset + 16 > end:
                return None
            size = struct.unpack_from(">Q", content, offset + 8)[0]
            header_size = 16
        elif size == 0:
            size = end - offset
        if size < header_size or offset + size > end:
            return None
        boxes.append((kind, offset + header_size, offset + size))
        offset += size
    return boxes if offset == end else None


def _mp4_structure_valid(content: bytes) -> bool:
    top = _mp4_boxes(content, 0, len(content))
    if top is None:
        return False
    ftyp = next((box for box in top if box[0] == b"ftyp"), None)
    moov = next((box for box in top if box[0] == b"moov"), None)
    mdats = [box for box in top if box[0] == b"mdat"]
    if ftyp is None or moov is None or not mdats:
        return False
    if ftyp[2] - ftyp[1] < 8 or not any(end > start for _, start, end in mdats):
        return False
    moov_children = _mp4_boxes(content, moov[1], moov[2])
    if moov_children is None:
        return False
    for trak in (box for box in moov_children if box[0] == b"trak"):
        trak_children = _mp4_boxes(content, trak[1], trak[2])
        if trak_children is None:
            return False
        for mdia in (box for box in trak_children if box[0] == b"mdia"):
            mdia_children = _mp4_boxes(content, mdia[1], mdia[2])
            if mdia_children is None:
                return False
            for hdlr in (box for box in mdia_children if box[0] == b"hdlr"):
                if hdlr[2] - hdlr[1] >= 12 and content[hdlr[1] + 8 : hdlr[1] + 12] == b"vide":
                    return True
    return False


EvidenceMediaProbe = Callable[[str, str, bytes], list[str]]


def _ffprobe_media_errors(
    path: str,
    kind: str,
    content: bytes,
    tool_path: Path,
) -> list[str]:
    environment = {"LC_ALL": "C", "LANG": "C"}
    for name in ("SystemRoot", "ComSpec", "PATH"):
        value = os.environ.get(name)
        if value:
            environment[name] = value
    try:
        result = subprocess.run(
            [
                str(tool_path),
                "-v",
                "error",
                "-count_frames",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=codec_type,codec_name,width,height,nb_read_frames:format=format_name,duration",
                "-of",
                "json",
                "pipe:0",
            ],
            input=content,
            check=False,
            capture_output=True,
            timeout=DEFAULT_MEDIA_PROBE_TIMEOUT_SECONDS,
            env=environment,
            shell=False,
        )
    except FileNotFoundError:
        return ["黄金演示 ffprobe 工具不可用"]
    except subprocess.TimeoutExpired:
        return ["黄金演示 ffprobe 执行超时"]
    except (OSError, ValueError) as error:
        return [f"黄金演示 ffprobe 无法启动 ({type(error).__name__})"]
    if result.returncode != 0:
        return ["黄金演示媒体无法由 ffprobe 解码"]
    if (
        not isinstance(result.stdout, bytes)
        or not isinstance(result.stderr, bytes)
        or len(result.stdout) > MAX_MEDIA_PROBE_OUTPUT_BYTES
        or len(result.stderr) > MAX_MEDIA_PROBE_OUTPUT_BYTES
    ):
        return ["黄金演示 ffprobe 输出无效"]
    if result.stderr.strip():
        return ["黄金演示媒体 ffprobe 解码报告错误"]
    try:
        document = json.loads(result.stdout)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return ["黄金演示 ffprobe 输出不是有效 JSON"]
    if not isinstance(document, dict):
        return ["黄金演示 ffprobe 输出顶层无效"]
    streams = document.get("streams")
    format_record = document.get("format")
    if not isinstance(streams, list) or not isinstance(format_record, dict):
        return ["黄金演示 ffprobe 输出缺少 streams/format"]
    video_streams = [
        stream
        for stream in streams
        if isinstance(stream, dict) and stream.get("codec_type") == "video"
    ]
    if len(video_streams) != 1:
        return ["黄金演示媒体必须恰好包含一个可解码视频流"]
    stream = video_streams[0]
    frame_count = stream.get("nb_read_frames")
    if (
        not isinstance(frame_count, str)
        or not frame_count.isascii()
        or not frame_count.isdigit()
        or int(frame_count) < 1
    ):
        return ["黄金演示媒体未解码出正帧数"]
    width = stream.get("width")
    height = stream.get("height")
    if (
        not isinstance(width, int)
        or isinstance(width, bool)
        or not isinstance(height, int)
        or isinstance(height, bool)
        or not (0 < width <= MAX_IMAGE_DIMENSION_PX)
        or not (0 < height <= MAX_IMAGE_DIMENSION_PX)
    ):
        return ["黄金演示媒体缺少有效解码尺寸"]
    suffix = PurePosixPath(path).suffix.casefold()
    codec_name = stream.get("codec_name")
    if kind == "screenshot":
        expected_codecs = {"png"} if suffix == ".png" else {"mjpeg"}
        if codec_name not in expected_codecs:
            return ["黄金演示截图解码格式与后缀不一致"]
        return []
    if kind == "video":
        format_name = format_record.get("format_name")
        duration_value = format_record.get("duration")
        if not isinstance(format_name, str) or "mp4" not in format_name.split(","):
            return ["黄金演示视频 ffprobe format_name 缺少 mp4"]
        if not isinstance(duration_value, str):
            return ["黄金演示视频 ffprobe 缺少 duration"]
        try:
            duration = float(duration_value)
        except ValueError:
            return ["黄金演示视频 ffprobe duration 无效"]
        if not math.isfinite(duration) or duration <= 0 or duration > 300:
            return ["黄金演示视频时长必须大于 0 且不超过 300 秒"]
    return []


def _runtime_evidence_format_errors(
    entries: Mapping[str, bytes],
    evidence_content: bytes,
    media_probe: EvidenceMediaProbe | None,
) -> list[str]:
    bindings, binding_errors = EVIDENCE_GATE.evidence_record_bindings(evidence_content)
    errors = list(binding_errors)
    demo = bindings.get("golden-demo")
    if demo is None or demo.level not in {"模拟器通过", "真机通过"}:
        return errors
    missing_probe_reported = False
    for path, kind in sorted(demo.artifact_references):
        if path not in entries:
            continue
        size = _entry_byte_count(entries, path)
        suffix = PurePosixPath(path).suffix.casefold()
        if kind == "screenshot":
            if size > MAX_SCREENSHOT_PARSE_BYTES:
                errors.append("黄金演示截图超过结构解析上限")
                continue
            content = entries[path]
            valid = (
                _png_structure_valid(content)
                if suffix == ".png"
                else _jpeg_structure_valid(content)
                if suffix in {".jpeg", ".jpg"}
                else False
            )
            if not valid:
                errors.append("黄金演示 PNG 结构无效" if suffix == ".png" else "黄金演示 JPEG 结构无效")
            elif media_probe is None:
                if not missing_probe_reported:
                    errors.append("黄金演示设备通过必须提供外部 ffprobe 媒体解码器")
                    missing_probe_reported = True
            else:
                errors.extend(media_probe(path, kind, content))
        elif kind == "ui-tree":
            if size > MAX_UI_TREE_PARSE_BYTES:
                errors.append("黄金演示 UI tree 超过结构解析上限")
                continue
            if suffix != ".json" or not _ui_tree_structure_valid(entries[path]):
                errors.append("黄金演示 UI tree JSON 结构无效")
        elif kind == "video":
            if size > MAX_EVIDENCE_ARTIFACT_BYTES:
                errors.append("黄金演示 MP4 超过结构解析上限")
                continue
            if suffix != ".mp4" or not _mp4_structure_valid(entries[path]):
                errors.append("黄金演示 MP4 结构无效")
            elif media_probe is None:
                if not missing_probe_reported:
                    errors.append("黄金演示设备通过必须提供外部 ffprobe 媒体解码器")
                    missing_probe_reported = True
            else:
                errors.extend(media_probe(path, kind, entries[path]))
    return errors


def _outer_container_errors(
    source: Path | io.BytesIO,
    label: str,
) -> list[str]:
    errors: list[str] = []
    handle: BinaryIO
    should_close = False
    original_position: int | None = None
    try:
        if isinstance(source, Path):
            handle = source.open("rb")
            should_close = True
        else:
            handle = source
            original_position = handle.tell()

        handle.seek(0, 2)
        total_bytes = handle.tell()
        handle.seek(0)
        first_signature = handle.read(4)
        if first_signature not in (
            ZIP_LOCAL_FILE_HEADER,
            ZIP_END_OF_CENTRAL_DIRECTORY,
        ):
            errors.append(f"{label} ZIP 在首个结构前包含额外前缀")

        handle.seek(0)
        for rule_name in _stream_secret_hits(handle):
            errors.append(f"{label} ZIP 原始容器敏感信息命中 ({rule_name})")

        tail_bytes = min(
            total_bytes,
            ZIP_END_OF_CENTRAL_DIRECTORY_BYTES + ZIP_MAX_COMMENT_BYTES,
        )
        handle.seek(total_bytes - tail_bytes)
        tail = handle.read(tail_bytes)
        relative_offset = tail.rfind(ZIP_END_OF_CENTRAL_DIRECTORY)
        if relative_offset < 0:
            errors.append(f"{label} ZIP 缺少末尾中央目录结束记录")
        elif relative_offset + ZIP_END_OF_CENTRAL_DIRECTORY_BYTES > len(tail):
            errors.append(f"{label} ZIP 中央目录结束记录不完整")
        else:
            comment_bytes = struct.unpack_from("<H", tail, relative_offset + 20)[0]
            expected_end = (
                total_bytes
                - tail_bytes
                + relative_offset
                + ZIP_END_OF_CENTRAL_DIRECTORY_BYTES
                + comment_bytes
            )
            if expected_end != total_bytes:
                errors.append(f"{label} ZIP 在中央目录结束记录后包含尾随数据")
    except (OSError, ValueError):
        errors.append(f"{label} ZIP 原始容器无法只读检查")
    finally:
        if should_close:
            handle.close()
        elif original_position is not None:
            try:
                handle.seek(original_position)
            except (OSError, ValueError):
                pass
    return errors


def _path_display(name: str) -> str:
    encoded = name.encode("utf-8", errors="surrogatepass")
    if _secret_hits(encoded):
        return "<redacted-path>"
    if any(ord(character) < 32 or ord(character) == 127 for character in name):
        return "<path-with-control-character>"
    if len(encoded) > MAX_ARCHIVE_PATH_BYTES:
        return f"<path utf8-bytes={len(encoded)}>"
    return name


def _path_list(names: list[str], limit: int = 8) -> str:
    return ", ".join(_path_display(name) for name in names[:limit])


def _strict_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError
        result[key] = value
    return result


def archive_path_reason(name: str, is_directory: bool = False) -> str | None:
    checked = name[:-1] if is_directory and name.endswith("/") else name
    if not checked or checked == ".":
        return "路径为空或指向当前目录"
    encoded = checked.encode("utf-8", errors="surrogatepass")
    if len(encoded) > MAX_ARCHIVE_PATH_BYTES:
        return f"路径 UTF-8 长度超过内部上限 {MAX_ARCHIVE_PATH_BYTES} 字节"
    if any(ord(character) < 32 or ord(character) == 127 for character in checked):
        return "路径包含控制字符"

    shared_reason = CONTENT_GATE.invalid_relative_path_reason(checked)
    if shared_reason is not None:
        return shared_reason

    parts = checked.split("/")
    if any(":" in part for part in parts):
        return "路径包含 Windows 冒号或数据流前缀"
    if any(part.endswith((" ", ".")) for part in parts):
        return "路径包含 Windows 会折叠的尾随空格或句点"

    reserved = {"con", "prn", "aux", "nul"}
    reserved.update(f"com{index}" for index in range(1, 10))
    reserved.update(f"lpt{index}" for index in range(1, 10))
    for part in parts:
        if part.split(".", 1)[0].casefold() in reserved:
            return "路径包含 Windows 保留设备名"
    return None


def release_attachment_forbidden_reason(name: str, role: str) -> str | None:
    path = PurePosixPath(name)
    blocked = next(
        (
            part
            for part in path.parts
            if part.casefold() in CONTENT_GATE.FORBIDDEN_DIRECTORY_NAMES
        ),
        None,
    )
    if blocked is not None:
        return f"包含禁止目录 {blocked}"

    normalized_name = path.name.casefold()
    if normalized_name.startswith(".env") and normalized_name != ".env.example":
        return "包含环境凭证文件"
    if normalized_name in CONTENT_GATE.FORBIDDEN_FILE_NAMES:
        return f"包含本地配置或系统文件 {path.name}"

    suffix = path.suffix.casefold()
    hap_exception = role == "hap" and suffix == ".hap"
    evidence_exception = (
        role == EVIDENCE_ARTIFACT_ROLE
        and suffix in EVIDENCE_ARTIFACT_SUFFIXES
    )
    if suffix in CONTENT_GATE.FORBIDDEN_FILE_SUFFIXES and not (
        hap_exception or evidence_exception
    ):
        return f"包含禁止文件类型 {path.suffix}"
    return None


def parse_release_manifest(content: bytes) -> tuple[ReleaseManifest, list[str]]:
    errors: list[str] = []
    if len(content) > MAX_RELEASE_MANIFEST_BYTES:
        return ReleaseManifest(None, ()), [
            f"{RELEASE_MANIFEST_PATH} 超过内部上限 {MAX_RELEASE_MANIFEST_BYTES} 字节"
        ]
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        return ReleaseManifest(None, ()), [f"{RELEASE_MANIFEST_PATH} 必须是 UTF-8 JSON"]

    try:
        document = json.loads(text, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return ReleaseManifest(None, ()), [f"{RELEASE_MANIFEST_PATH} JSON 包含重复键"]
    except json.JSONDecodeError as error:
        return ReleaseManifest(None, ()), [
            f"{RELEASE_MANIFEST_PATH} JSON 无效: line={error.lineno}, column={error.colno}"
        ]
    except (RecursionError, ValueError):
        return ReleaseManifest(None, ()), [
            f"{RELEASE_MANIFEST_PATH} JSON 结构或数值超出内部安全边界"
        ]

    if not isinstance(document, dict):
        return ReleaseManifest(None, ()), [f"{RELEASE_MANIFEST_PATH} 顶层必须为对象"]

    actual_fields = set(document)
    missing_fields = sorted(RELEASE_MANIFEST_FIELDS - actual_fields)
    unexpected_fields = sorted(actual_fields - RELEASE_MANIFEST_FIELDS)
    if missing_fields:
        errors.append(
            f"{RELEASE_MANIFEST_PATH} 缺少字段: {','.join(missing_fields)}"
        )
    if unexpected_fields:
        errors.append(
            f"{RELEASE_MANIFEST_PATH} 包含未定义字段: {','.join(unexpected_fields)}"
        )

    raw_source_commit = document.get("sourceCommit")
    source_commit: str | None = None
    if not isinstance(raw_source_commit, str) or FULL_COMMIT_PATTERN.fullmatch(
        raw_source_commit
    ) is None:
        errors.append(
            f"{RELEASE_MANIFEST_PATH}.sourceCommit 必须为 40 位小写十六进制完整提交哈希"
        )
    else:
        source_commit = raw_source_commit

    raw_files = document.get("nonGitFiles")
    if not isinstance(raw_files, list):
        errors.append(f"{RELEASE_MANIFEST_PATH}.nonGitFiles 必须为对象数组")
        raw_files = []
    elif len(raw_files) > len(REQUIRED_NON_GIT_ROLES) + MAX_EVIDENCE_ARTIFACTS:
        errors.append(
            f"{RELEASE_MANIFEST_PATH}.nonGitFiles 项数超过内部上限 "
            f"{len(REQUIRED_NON_GIT_ROLES) + MAX_EVIDENCE_ARTIFACTS}"
        )

    records: list[NonGitFileRecord] = []
    seen_paths: set[str] = set()
    seen_folded_paths: dict[str, str] = {}
    role_counts: Counter[str] = Counter()
    for index, item in enumerate(raw_files):
        label = f"{RELEASE_MANIFEST_PATH}.nonGitFiles[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} 必须为对象")
            continue

        actual_item_fields = set(item)
        missing_item_fields = sorted(NON_GIT_FILE_FIELDS - actual_item_fields)
        unexpected_item_fields = sorted(actual_item_fields - NON_GIT_FILE_FIELDS)
        if missing_item_fields:
            errors.append(f"{label} 缺少字段: {','.join(missing_item_fields)}")
        if unexpected_item_fields:
            errors.append(
                f"{label} 包含未定义字段: {','.join(unexpected_item_fields)}"
            )

        valid = not missing_item_fields and not unexpected_item_fields
        raw_path = item.get("path")
        if not isinstance(raw_path, str) or not raw_path:
            errors.append(f"{label}.path 必须为非空字符串")
            valid = False
        else:
            path_reason = archive_path_reason(raw_path)
            if path_reason is not None:
                errors.append(
                    f"{label}.path 无效: {_path_display(raw_path)} ({path_reason})"
                )
                valid = False
            if raw_path == RELEASE_MANIFEST_PATH:
                errors.append(f"{label}.path 不得指向 {RELEASE_MANIFEST_PATH}")
                valid = False
            folded_path = raw_path.casefold()
            if raw_path in seen_paths:
                errors.append(
                    f"{RELEASE_MANIFEST_PATH}.nonGitFiles 路径重复: "
                    f"{_path_display(raw_path)}"
                )
                valid = False
            elif folded_path in seen_folded_paths:
                errors.append(
                    f"{RELEASE_MANIFEST_PATH}.nonGitFiles 路径大小写折叠后重复: "
                    f"{_path_display(seen_folded_paths[folded_path])} / "
                    f"{_path_display(raw_path)}"
                )
                valid = False
            seen_paths.add(raw_path)
            seen_folded_paths.setdefault(folded_path, raw_path)

        raw_role = item.get("role")
        if not isinstance(raw_role, str) or raw_role not in ALLOWED_NON_GIT_ROLES:
            errors.append(
                f"{label}.role 必须为允许角色之一: "
                + ",".join(sorted(ALLOWED_NON_GIT_ROLES))
            )
            valid = False
        else:
            role_counts[raw_role] += 1

        raw_bytes = item.get("bytes")
        if (
            not isinstance(raw_bytes, int)
            or isinstance(raw_bytes, bool)
            or raw_bytes <= 0
        ):
            errors.append(f"{label}.bytes 必须为正整数")
            valid = False

        raw_sha256 = item.get("sha256")
        if not isinstance(raw_sha256, str) or SHA256_PATTERN.fullmatch(
            raw_sha256
        ) is None:
            errors.append(f"{label}.sha256 必须为 64 位小写十六进制 SHA-256")
            valid = False

        if isinstance(raw_path, str) and isinstance(raw_role, str):
            if raw_role == EVIDENCE_ARTIFACT_ROLE:
                if not raw_path.startswith(EVIDENCE_ARTIFACT_PREFIX):
                    errors.append(
                        f"{label}.path evidence-artifact 必须位于 "
                        f"{EVIDENCE_ARTIFACT_PREFIX}"
                    )
                    valid = False
                if PurePosixPath(raw_path).suffix.casefold() not in EVIDENCE_ARTIFACT_SUFFIXES:
                    errors.append(
                        f"{label}.path evidence-artifact 后缀不在允许集合"
                    )
                    valid = False
            forbidden_reason = release_attachment_forbidden_reason(
                raw_path,
                raw_role,
            )
            if forbidden_reason is not None:
                errors.append(
                    f"{label}.path 包含发布包禁止项: {_path_display(raw_path)} "
                    f"({forbidden_reason})"
                )
                valid = False

        if valid:
            records.append(
                NonGitFileRecord(raw_path, raw_role, raw_bytes, raw_sha256)
            )

    for role in sorted(REQUIRED_NON_GIT_ROLES):
        count = role_counts[role]
        if count != 1:
            errors.append(
                f"{RELEASE_MANIFEST_PATH}.nonGitFiles 角色 {role} 必须且只能出现一次，实际 {count}"
            )
    evidence_count = role_counts[EVIDENCE_ARTIFACT_ROLE]
    if evidence_count > MAX_EVIDENCE_ARTIFACTS:
        errors.append(
            f"{RELEASE_MANIFEST_PATH}.nonGitFiles evidence-artifact 数量超过 "
            f"{MAX_EVIDENCE_ARTIFACTS}"
        )
    evidence_records = [
        record for record in records if record.role == EVIDENCE_ARTIFACT_ROLE
    ]
    for record in evidence_records:
        if record.byte_count > MAX_EVIDENCE_ARTIFACT_BYTES:
            errors.append(
                f"evidence-artifact 单项大小超过 {MAX_EVIDENCE_ARTIFACT_BYTES}: "
                f"{_path_display(record.path)}"
            )
    evidence_total = sum(record.byte_count for record in evidence_records)
    if evidence_total > MAX_EVIDENCE_ARTIFACT_TOTAL_BYTES:
        errors.append(
            f"evidence-artifact 总大小超过 {MAX_EVIDENCE_ARTIFACT_TOTAL_BYTES}"
        )

    return ReleaseManifest(source_commit, tuple(records)), errors


def _archive_infos(
    archive: zipfile.ZipFile,
    label: str,
    *,
    max_entry_bytes: int,
    max_total_bytes: int,
    require_first_header_at_zero: bool,
) -> tuple[list[zipfile.ZipInfo], list[str]]:
    readable: list[zipfile.ZipInfo] = []
    errors: list[str] = []
    seen_exact: set[str] = set()
    seen_casefold: dict[str, str] = {}
    infos = archive.infolist()
    resource_blocked = False

    if (
        require_first_header_at_zero
        and infos
        and min(info.header_offset for info in infos) != 0
    ):
        errors.append(f"{label} ZIP 首个被引用的本地文件头不在偏移 0")
        resource_blocked = True
    if len(infos) > MAX_ARCHIVE_ENTRIES:
        errors.append(
            f"{label} 条目数超过内部上限: "
            f"{len(infos)}>{MAX_ARCHIVE_ENTRIES}"
        )
        resource_blocked = True
    total_bytes = sum(info.file_size for info in infos if not info.is_dir())
    if total_bytes > max_total_bytes:
        errors.append(
            f"{label} 解压后总大小超过内部上限: "
            f"{total_bytes}>{max_total_bytes}"
        )
        resource_blocked = True

    for rule_name in _secret_hits(archive.comment):
        errors.append(f"{label} ZIP 注释敏感信息命中 ({rule_name})")

    for info in infos:
        entry_blocked = False
        original_name = info.orig_filename
        metadata = [
            ("条目原始文件名", original_name.encode("utf-8", errors="surrogatepass")),
            ("条目注释", info.comment),
            ("条目扩展字段", info.extra),
        ]
        if original_name != info.filename:
            metadata.append(
                (
                    "条目解析文件名",
                    info.filename.encode("utf-8", errors="surrogatepass"),
                )
            )
        for metadata_kind, metadata_content in metadata:
            for rule_name in _secret_hits(metadata_content):
                errors.append(
                    f"{label} {metadata_kind}敏感信息命中 ({rule_name})"
                )

        original_display_name = _path_display(original_name)
        original_reason = archive_path_reason(
            original_name,
            original_name.endswith("/"),
        )
        if original_reason is not None:
            errors.append(
                f"{label} ZIP 原始路径无效: {original_display_name} "
                f"({original_reason})"
            )
            entry_blocked = True
        if original_name != info.filename:
            errors.append(
                f"{label} ZIP 元数据 orig_filename（原始文件名）与 "
                f"filename（解析文件名）不一致: "
                f"{original_display_name}"
            )
            entry_blocked = True

        normalized = info.filename[:-1] if info.is_dir() and info.filename.endswith("/") else info.filename
        display_name = _path_display(info.filename)
        reason = archive_path_reason(info.filename, info.is_dir())
        if reason is not None:
            errors.append(f"{label} 路径无效: {display_name} ({reason})")
            entry_blocked = True

        folded = normalized.casefold()
        if normalized in seen_exact:
            errors.append(f"{label} 包含重复条目: {display_name}")
            continue
        if folded in seen_casefold:
            errors.append(
                f"{label} 包含大小写折叠后重复条目: "
                f"{_path_display(seen_casefold[folded])} / {display_name}"
            )
            continue
        seen_exact.add(normalized)
        seen_casefold[folded] = info.filename

        unix_type = (info.external_attr >> 16) & 0o170000
        if unix_type == 0o120000:
            errors.append(f"{label} 包含符号链接: {display_name}")
            continue
        if unix_type not in (0, 0o040000, 0o100000):
            errors.append(f"{label} 包含不支持的特殊文件: {display_name}")
            continue
        if info.flag_bits & 0x1:
            errors.append(f"{label} 包含加密条目，无法审计: {display_name}")
            continue
        if info.is_dir():
            continue
        if info.file_size > max_entry_bytes:
            errors.append(
                f"{label} 条目解压大小超过内部上限: {display_name} "
                f"({info.file_size}>{max_entry_bytes})"
            )
            continue
        if info.file_size > 0 and (
            info.compress_size == 0
            or info.file_size
            > info.compress_size * MAX_ARCHIVE_COMPRESSION_RATIO
        ):
            errors.append(
                f"{label} 条目压缩比超过内部上限: {display_name} "
                f"(max={MAX_ARCHIVE_COMPRESSION_RATIO}:1)"
            )
            continue
        if not entry_blocked:
            readable.append(info)
    if resource_blocked:
        readable.clear()
    return readable, errors


def collect_zip_entries(
    source: Path | io.BytesIO,
    label: str,
) -> tuple[dict[str, bytes], list[str]]:
    entries: dict[str, bytes] = {}
    errors = _outer_container_errors(source, label)
    try:
        with zipfile.ZipFile(source) as archive:
            infos, info_errors = _archive_infos(
                archive,
                label,
                max_entry_bytes=MAX_OUTER_ENTRY_BYTES,
                max_total_bytes=MAX_OUTER_TOTAL_BYTES,
                require_first_header_at_zero=True,
            )
            errors.extend(info_errors)
            for info in infos:
                try:
                    entries[info.filename] = archive.read(info)
                except (NotImplementedError, OSError, RuntimeError, zipfile.BadZipFile) as error:
                    errors.append(
                        f"{label} 条目无法读取: {_path_display(info.filename)} "
                        f"({type(error).__name__})"
                    )
    except (
        OSError,
        UnicodeDecodeError,
        zipfile.BadZipFile,
        zipfile.LargeZipFile,
    ) as error:
        errors.append(f"{label} 无法作为 ZIP 读取 ({type(error).__name__})")
    return entries, errors


def read_release_zip(path: Path) -> tuple[dict[str, bytes], list[str], Path]:
    resolved = path.resolve()
    if not resolved.is_file() or resolved.suffix.casefold() != ".zip":
        return {}, [f"--bundle-path 必须指向现有 .zip 文件: {resolved}"], resolved
    entries, errors = collect_zip_entries(resolved, "最终 ZIP")
    return entries, errors, resolved


def _figure_evidence_binding_errors(
    entries: Mapping[str, bytes],
    evidence_content: bytes,
) -> list[str]:
    if COMPETITION_PLAN_PATH not in entries:
        return ["最终 ZIP 缺少两图状态绑定所需竞赛计划"]
    if _entry_byte_count(entries, COMPETITION_PLAN_PATH) > MAX_COMPETITION_PLAN_BYTES:
        return ["竞赛计划超过内部上限，无法绑定两图运行证据"]
    try:
        plan_content = entries[COMPETITION_PLAN_PATH].decode("utf-8")
    except UnicodeDecodeError:
        return ["竞赛计划不是 UTF-8，无法绑定两图运行证据"]

    requirements, requirement_errors = (
        COMPETITION_GATE.figure_evidence_requirements(plan_content)
    )
    record_bindings, record_errors = EVIDENCE_GATE.evidence_record_bindings(
        evidence_content
    )
    errors = [*requirement_errors, *record_errors]
    for requirement in requirements:
        binding = record_bindings.get(requirement.evidence_id)
        if binding is None:
            errors.append(
                f"{requirement.figure_id} 引用的发布证据 ID 不存在: "
                f"{requirement.evidence_id}"
            )
            continue
        if requirement.level == "未验证":
            if binding.level in {"模拟器通过", "真机通过"}:
                errors.append(
                    f"{requirement.figure_id} 仍为未验证，但 golden-demo 已为 "
                    f"{binding.level}，必须迁移状态并绑定图片"
                )
            continue
        if binding.level != requirement.level:
            errors.append(
                f"{requirement.figure_id} 的 {requirement.level} 与 golden-demo "
                f"等级 {binding.level} 不一致"
            )
        if requirement.artifact not in binding.artifact_paths:
            errors.append(
                f"{requirement.figure_id} 图片未被 golden-demo artifacts 引用"
            )
        elif (requirement.artifact, "screenshot") not in binding.artifact_references:
            errors.append(
                f"{requirement.figure_id} 图片必须使用 golden-demo screenshot 类型"
            )
    return errors


def validate_release_zip_file(
    path: Path,
    ffprobe_path: Path | None = None,
) -> tuple[list[str], Path, str | None, int, int]:
    resolved = path.resolve()
    if not resolved.is_file() or resolved.suffix.casefold() != ".zip":
        return [f"--bundle-path 必须指向现有 .zip 文件: {resolved}"], resolved, None, 0, 0

    errors = _outer_container_errors(resolved, "最终 ZIP")
    expected_commit, commit_errors = current_git_commit()
    errors.extend(commit_errors)
    declared_commit: str | None = None
    source_count = 0
    extra_count = 0
    media_probe: EvidenceMediaProbe | None = None
    if ffprobe_path is not None:
        if (
            not ffprobe_path.is_absolute()
            or not ffprobe_path.is_file()
            or ffprobe_path.is_symlink()
        ):
            errors.append("--ffprobe-path 必须指向现有绝对普通文件且不得为符号链接")
        else:
            resolved_ffprobe = ffprobe_path.resolve()
            media_probe = lambda path, kind, content: _ffprobe_media_errors(
                path,
                kind,
                content,
                resolved_ffprobe,
            )
    try:
        with zipfile.ZipFile(resolved) as archive:
            infos, info_errors = _archive_infos(
                archive,
                "最终 ZIP",
                max_entry_bytes=MAX_OUTER_ENTRY_BYTES,
                max_total_bytes=MAX_OUTER_TOTAL_BYTES,
                require_first_header_at_zero=True,
            )
            errors.extend(info_errors)
            entries = ZipEntryView(archive, infos)

            expected_sources: dict[str, bytes] | None = None
            manifest_content = (
                entries[RELEASE_MANIFEST_PATH]
                if RELEASE_MANIFEST_PATH in entries
                and entries.byte_count(RELEASE_MANIFEST_PATH)
                <= MAX_RELEASE_MANIFEST_BYTES
                else None
            )
            if manifest_content:
                manifest, _ = parse_release_manifest(manifest_content)
                if manifest.source_commit is not None:
                    declared_commit = manifest.source_commit
                    expected_sources, source_errors = load_git_source_snapshot(
                        manifest.source_commit
                    )
                    errors.extend(source_errors)
            errors.extend(
                check_release_bundle_entries(
                    entries,
                    expected_sources,
                    expected_commit,
                    media_probe,
                )
            )
            source_count = len(expected_sources or {})
            extra_count = len(entries) - source_count - 1
    except (
        OSError,
        UnicodeDecodeError,
        zipfile.BadZipFile,
        zipfile.LargeZipFile,
    ) as error:
        errors.append(f"最终 ZIP 无法作为 ZIP 流式读取 ({type(error).__name__})")
    return errors, resolved, declared_commit, source_count, extra_count


def check_hap_content(path: str, content: bytes) -> list[str]:
    display_path = _path_display(path)
    if not content:
        return [f"HAP 为空: {display_path}"]

    errors: list[str] = []
    for rule_name in _secret_hits(content):
        errors.append(f"HAP 容器敏感信息命中 ({rule_name})")
    try:
        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            infos, info_errors = _archive_infos(
                archive,
                f"HAP {display_path}",
                max_entry_bytes=MAX_HAP_ENTRY_BYTES,
                max_total_bytes=MAX_HAP_TOTAL_BYTES,
                require_first_header_at_zero=False,
            )
            errors.extend(info_errors)
            if not any(not info.is_dir() for info in archive.infolist()):
                errors.append(f"HAP 不含文件条目: {display_path}")
            for info in infos:
                try:
                    entry_content = archive.read(info)
                except (NotImplementedError, OSError, RuntimeError, zipfile.BadZipFile) as error:
                    errors.append(
                        f"HAP 内部条目无法读取: {display_path}!/"
                        f"{_path_display(info.filename)} "
                        f"({type(error).__name__})"
                    )
                    continue
                for rule_name in _secret_hits(entry_content):
                    errors.append(f"HAP 内部条目内容敏感信息命中 ({rule_name})")
    except (
        OSError,
        UnicodeDecodeError,
        zipfile.BadZipFile,
        zipfile.LargeZipFile,
    ) as error:
        errors.append(
            f"HAP 无法作为 ZIP 读取: {display_path} ({type(error).__name__})"
        )
    return errors


def check_release_bundle_entries(
    entries: Mapping[str, bytes],
    expected_sources: dict[str, bytes] | None,
    expected_source_commit: str | None,
    media_probe: EvidenceMediaProbe | None = None,
) -> list[str]:
    errors: list[str] = []

    folded_paths: dict[str, str] = {}
    for name in sorted(entries):
        reason = archive_path_reason(name)
        if reason is not None:
            errors.append(f"最终 ZIP 路径无效: {_path_display(name)} ({reason})")
        folded = name.casefold()
        if folded in folded_paths and folded_paths[folded] != name:
            errors.append(
                f"最终 ZIP 包含大小写折叠后重复条目: "
                f"{_path_display(folded_paths[folded])} / {_path_display(name)}"
            )
        folded_paths[folded] = name

    if RELEASE_MANIFEST_PATH not in entries:
        manifest = ReleaseManifest(None, ())
        errors.append(f"最终 ZIP 缺少包根 {RELEASE_MANIFEST_PATH}")
    elif _entry_byte_count(entries, RELEASE_MANIFEST_PATH) > MAX_RELEASE_MANIFEST_BYTES:
        manifest = ReleaseManifest(None, ())
        errors.append(
            f"{RELEASE_MANIFEST_PATH} 超过内部上限 {MAX_RELEASE_MANIFEST_BYTES} 字节"
        )
    else:
        manifest_content = entries[RELEASE_MANIFEST_PATH]
        if not manifest_content:
            manifest = ReleaseManifest(None, ())
            errors.append(f"包根 {RELEASE_MANIFEST_PATH} 为空")
        else:
            manifest, manifest_errors = parse_release_manifest(manifest_content)
            errors.extend(manifest_errors)

    if (
        expected_source_commit is not None
        and manifest.source_commit is not None
        and manifest.source_commit != expected_source_commit
    ):
        errors.append(
            f"{RELEASE_MANIFEST_PATH}.sourceCommit 与已解析 Git 提交不一致"
        )

    source_names: set[str] = set()
    if expected_sources is None:
        errors.append("未能取得 sourceCommit 对应的 Git manifest 源码快照")
    else:
        source_names = set(expected_sources)
        actual_names = set(entries)
        missing_sources = sorted(source_names - actual_names)
        if missing_sources:
            errors.append(
                f"最终 ZIP 缺少 Git manifest 源码 {len(missing_sources)} 项: "
                + _path_list(missing_sources)
            )
        for name in sorted(source_names & actual_names):
            if not _entry_matches(entries, name, expected_sources[name]):
                errors.append(
                    f"最终 ZIP 源码与 Git manifest 逐字不一致: "
                    f"{_path_display(name)}"
                )

    declared = {record.path: record for record in manifest.non_git_files}
    declared_names = set(declared)
    overlap = sorted(declared_names & source_names)
    if overlap:
        errors.append(
            "release-manifest.json 将 Git 源码错误声明为 nonGitFiles: "
            + _path_list(overlap)
        )

    if expected_sources is not None:
        actual_extra_names = set(entries) - source_names - {RELEASE_MANIFEST_PATH}
        missing_declared = sorted(declared_names - actual_extra_names)
        undeclared = sorted(actual_extra_names - declared_names)
        if missing_declared:
            errors.append(
                f"最终 ZIP 缺少 nonGitFiles 已声明文件 {len(missing_declared)} 项: "
                + _path_list(missing_declared)
            )
        if undeclared:
            errors.append(
                f"最终 ZIP 包含未在 nonGitFiles 声明的额外文件 {len(undeclared)} 项: "
                + _path_list(undeclared)
            )

    for record in manifest.non_git_files:
        if record.role == "hap" and PurePosixPath(record.path).suffix.casefold() != ".hap":
            errors.append(
                f"角色 hap 的 path 必须以 .hap 结尾: "
                f"{_path_display(record.path)}"
            )
        if record.role != "hap" and PurePosixPath(record.path).suffix.casefold() == ".hap":
            errors.append(
                f".hap 文件只能使用角色 hap: {_path_display(record.path)}"
            )
        if record.path not in entries:
            continue
        if _entry_byte_count(entries, record.path) != record.byte_count:
            errors.append(
                f"nonGitFiles.bytes 与实际文件大小不一致: "
                f"{_path_display(record.path)}"
            )
        actual_hash = _entry_sha256(entries, record.path)
        if actual_hash != record.sha256:
            errors.append(
                f"nonGitFiles.sha256 与实际文件哈希不一致: "
                f"{_path_display(record.path)}"
            )

    records_by_role = {record.role: record for record in manifest.non_git_files}
    evidence_record = records_by_role.get("release-evidence-index")
    hap_record = records_by_role.get("hap")
    if evidence_record is not None:
        evidence_content = None
        if evidence_record.path in entries:
            if (
                _entry_byte_count(entries, evidence_record.path)
                > EVIDENCE_GATE.MAX_EVIDENCE_INDEX_BYTES
            ):
                errors.append(
                    "发布证据索引条目超过内部上限，拒绝读取正文"
                )
            else:
                evidence_content = entries[evidence_record.path]
        hap_content = entries.get(hap_record.path) if hap_record is not None else None
        if evidence_content is not None:
            if manifest.source_commit is None or hap_content is None:
                errors.append("发布证据索引无法绑定有效 sourceCommit 与唯一 HAP")
            else:
                artifact_bindings: dict[str, EVIDENCE_GATE.ArtifactBinding] = {}
                for name in entries:
                    if name == RELEASE_MANIFEST_PATH:
                        continue
                    declared_record = declared.get(name)
                    role = (
                        declared_record.role
                        if declared_record is not None
                        else "git-source" if name in source_names else "undeclared"
                    )
                    artifact_bindings[name] = EVIDENCE_GATE.ArtifactBinding(
                        _entry_byte_count(entries, name),
                        _entry_sha256(entries, name),
                        role,
                        entries[name]
                        if role == EVIDENCE_ARTIFACT_ROLE
                        and _entry_byte_count(entries, name)
                        <= EVIDENCE_GATE.MAX_ONLINE_CAPTURE_BYTES
                        else None,
                    )
                _, evidence_errors = EVIDENCE_GATE.validate_release_evidence(
                    evidence_content,
                    manifest.source_commit,
                    _entry_sha256(entries, hap_record.path),
                    artifact_bindings,
                )
                errors.extend(evidence_errors)
                errors.extend(
                    _figure_evidence_binding_errors(entries, evidence_content)
                )
                errors.extend(
                    _runtime_evidence_format_errors(
                        entries,
                        evidence_content,
                        media_probe,
                    )
                )
                owners, owner_errors = EVIDENCE_GATE.artifact_reference_owners(
                    evidence_content
                )
                errors.extend(owner_errors)
                evidence_artifact_names = {
                    record.path
                    for record in manifest.non_git_files
                    if record.role == EVIDENCE_ARTIFACT_ROLE
                }
                unreferenced = sorted(evidence_artifact_names - set(owners))
                if unreferenced:
                    errors.append(
                        "evidence-artifact 未被任何发布证据 ID 引用: "
                        + _path_list(unreferenced)
                    )

    hap_paths = sorted(
        name for name in entries if PurePosixPath(name).suffix.casefold() == ".hap"
    )
    if len(hap_paths) != 1:
        errors.append(f"最终 ZIP 必须且只能包含一个 HAP，实际 {len(hap_paths)}")
    for hap_path in hap_paths:
        errors.extend(check_hap_content(hap_path, entries[hap_path]))

    notice = entries.get(CONTENT_GATE.COMPETITION_NOTICE)
    if notice is not None and CONTENT_GATE.PENDING_SUBMISSION_MARKER in notice:
        errors.append(
            f"竞赛 NOTICE 仍含待人工处理标记: {CONTENT_GATE.COMPETITION_NOTICE}"
        )

    for name in sorted(entries):
        if PurePosixPath(name).suffix.casefold() == ".hap":
            continue
        for rule_name in _entry_secret_hits(entries, name):
            errors.append(
                f"最终 ZIP 敏感信息命中: {_path_display(name)} ({rule_name})"
            )
    return errors


def _run_git(arguments: list[str], input_bytes: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        input=input_bytes,
        check=False,
        capture_output=True,
    )


def current_git_commit() -> tuple[str | None, list[str]]:
    result = _run_git(["rev-parse", "--verify", "HEAD^{commit}"])
    if result.returncode != 0:
        return None, [f"当前 HEAD 无法解析为 Git 提交，exit={result.returncode}"]
    try:
        commit = result.stdout.strip().decode("ascii")
    except UnicodeDecodeError:
        return None, ["git rev-parse HEAD 返回了非 ASCII 提交哈希"]
    if FULL_COMMIT_PATTERN.fullmatch(commit) is None:
        return None, ["git rev-parse HEAD 未返回 40 位小写十六进制完整提交哈希"]
    return commit, []


def _parse_git_tree(content: bytes) -> tuple[dict[str, GitTreeRecord], list[str]]:
    records: dict[str, GitTreeRecord] = {}
    errors: list[str] = []
    for raw_record in content.split(b"\0"):
        if not raw_record:
            continue
        try:
            metadata, raw_name = raw_record.split(b"\t", 1)
            raw_mode, raw_type, raw_object_id = metadata.split(b" ", 2)
            name = raw_name.decode("utf-8")
            mode = raw_mode.decode("ascii")
            object_type = raw_type.decode("ascii")
            object_id = raw_object_id.decode("ascii")
        except (UnicodeDecodeError, ValueError):
            errors.append("git ls-tree 返回了无法按 UTF-8/标准元数据解析的条目")
            continue
        if name in records:
            errors.append(f"Git tree 包含重复路径: {name}")
            continue
        records[name] = GitTreeRecord(mode, object_type, object_id)
    return records, errors


def _read_git_blobs(
    selected_names: list[str],
    tree: dict[str, GitTreeRecord],
) -> tuple[dict[str, bytes], list[str]]:
    errors: list[str] = []
    regular_names: list[str] = []
    for name in selected_names:
        record = tree[name]
        if record.mode not in REGULAR_GIT_MODES or record.object_type != "blob":
            errors.append(
                f"Git manifest 选择了非普通文件: {name} ({record.mode}/{record.object_type})"
            )
        else:
            regular_names.append(name)

    request = b"".join(
        tree[name].object_id.encode("ascii") + b"\n" for name in regular_names
    )
    result = _run_git(["cat-file", "--batch"], request)
    if result.returncode != 0:
        return {}, errors + [f"git cat-file --batch 失败，exit={result.returncode}"]

    blobs: dict[str, bytes] = {}
    cursor = 0
    output = result.stdout
    for name in regular_names:
        header_end = output.find(b"\n", cursor)
        if header_end < 0:
            errors.append("git cat-file --batch 输出提前结束")
            break
        header = output[cursor:header_end].split(b" ")
        cursor = header_end + 1
        if len(header) != 3:
            errors.append("git cat-file --batch 返回了无效头部")
            break
        raw_object_id, raw_type, raw_size = header
        try:
            size = int(raw_size)
        except ValueError:
            errors.append("git cat-file --batch 返回了无效大小")
            break
        expected_object_id = tree[name].object_id.encode("ascii")
        if raw_object_id != expected_object_id or raw_type != b"blob":
            errors.append(f"git cat-file --batch 对象与 tree 不一致: {name}")
            break
        end = cursor + size
        if end >= len(output) or output[end : end + 1] != b"\n":
            errors.append(f"git cat-file --batch 内容长度无效: {name}")
            break
        blobs[name] = output[cursor:end]
        cursor = end + 1
    if cursor != len(output):
        errors.append("git cat-file --batch 返回了未消费的额外数据")
    return blobs, errors


def load_git_source_snapshot(
    source_commit: str,
) -> tuple[dict[str, bytes] | None, list[str]]:
    if FULL_COMMIT_PATTERN.fullmatch(source_commit) is None:
        return None, ["sourceCommit 不是 40 位小写十六进制完整提交哈希"]

    verify = _run_git(["rev-parse", "--verify", f"{source_commit}^{{commit}}"])
    if verify.returncode != 0:
        return None, [f"sourceCommit 无法解析为本仓库提交，exit={verify.returncode}"]
    try:
        resolved_commit = verify.stdout.strip().decode("ascii")
    except UnicodeDecodeError:
        return None, ["git rev-parse 返回了非 ASCII 提交哈希"]
    if resolved_commit != source_commit:
        return None, ["sourceCommit 未精确解析为声明的完整提交哈希"]

    manifest_result = _run_git(
        ["show", f"{source_commit}:{CONTENT_GATE.SUBMISSION_MANIFEST}"]
    )
    if manifest_result.returncode != 0:
        return None, [
            f"sourceCommit 缺少 {CONTENT_GATE.SUBMISSION_MANIFEST}，exit={manifest_result.returncode}"
        ]
    try:
        manifest_text = manifest_result.stdout.decode("utf-8")
    except UnicodeDecodeError:
        return None, [f"Git 源码 manifest 不是 UTF-8: {CONTENT_GATE.SUBMISSION_MANIFEST}"]

    include, exclude, errors = CONTENT_GATE.parse_submission_manifest(manifest_text)
    errors.extend(CONTENT_GATE.check_manifest_policy(include, exclude))

    tree_result = _run_git(["ls-tree", "-rz", "--full-tree", source_commit])
    if tree_result.returncode != 0:
        return None, errors + [f"git ls-tree 失败，exit={tree_result.returncode}"]
    tree, tree_errors = _parse_git_tree(tree_result.stdout)
    errors.extend(tree_errors)

    directory_names: set[str] = set()
    for name in tree:
        path = PurePosixPath(name)
        for parent in path.parents:
            if parent.as_posix() != ".":
                directory_names.add(parent.as_posix())

    def path_kind(name: str) -> str | None:
        record = tree.get(name)
        if record is not None:
            if record.mode == "120000":
                return "symlink"
            if record.mode in REGULAR_GIT_MODES and record.object_type == "blob":
                return "file"
            return "unsupported"
        if name in directory_names:
            return "directory"
        return None

    selected, selection_errors = CONTENT_GATE.resolve_manifest_selection(
        include,
        exclude,
        set(tree),
        path_kind,
    )
    errors.extend(selection_errors)
    if CONTENT_GATE.SUBMISSION_MANIFEST not in selected:
        errors.append(
            f"Git manifest 未选择自身: {CONTENT_GATE.SUBMISSION_MANIFEST}"
        )

    blobs, blob_errors = _read_git_blobs(sorted(selected), tree)
    errors.extend(blob_errors)
    if not blob_errors:
        errors.extend(
            CONTENT_GATE.check_submission_package(
                blobs,
                allow_pending_notice=False,
            )
        )
    if errors:
        return None, errors
    return blobs, []


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bundle-path",
        type=Path,
        required=True,
        help="明确的最终 Demo/源码 ZIP；只读检查，不解压、不改写",
    )
    parser.add_argument(
        "--ffprobe-path",
        type=Path,
        help="设备通过证据存在时，用该绝对普通文件路径解码截图和 MP4",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    (
        errors,
        resolved,
        declared_commit,
        source_count,
        extra_count,
    ) = validate_release_zip_file(args.bundle_path, args.ffprobe_path)
    if errors:
        print(f"[FAIL] 最终 Demo/源码 ZIP 门禁: {len(errors)} 项")
        for error in errors:
            print(f"  - {error}")
        print("\nSOME CHECKS FAILED")
        return 1

    print(
        f"[PASS] 最终 Demo/源码 ZIP 门禁: {resolved}; "
        f"sourceCommit={declared_commit}; 源码 {source_count} 项; "
        f"非 Git 附件 {extra_count} 项"
    )
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
