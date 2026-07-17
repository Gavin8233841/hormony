#!/usr/bin/env python3
"""只读校验正式发布证据索引与源码提交、HAP 哈希的绑定。"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import NamedTuple
from urllib.parse import urlsplit


sys.dont_write_bytecode = True

SCHEMA_VERSION = 2
MAX_EVIDENCE_INDEX_BYTES = 64 * 1024
MAX_LIST_ITEMS = 50
MAX_COMMAND_ARGUMENTS = 32
MAX_SHORT_TEXT_CHARACTERS = 300
MAX_NOTES_CHARACTERS = 2000
MAX_ARTIFACT_PATH_BYTES = 512
FULL_COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
RECORD_ID_PATTERN = re.compile(r"[a-z][a-z0-9-]{2,63}")
BUSINESS_CHECK_ID_PATTERN = re.compile(r"[a-z][a-z0-9.-]{2,63}")
RFC3339_PATTERN = re.compile(
    r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
    r"(?:Z|[+-][0-9]{2}:[0-9]{2})"
)
TOP_LEVEL_FIELDS = frozenset(
    {"schemaVersion", "sourceCommit", "hapSha256", "records", "limitations"}
)
RECORD_FIELDS = frozenset(
    {
        "id",
        "claim",
        "level",
        "recordedAt",
        "command",
        "exitCode",
        "environment",
        "artifacts",
        "businessChecks",
        "notes",
    }
)
ARTIFACT_FIELDS = frozenset({"path", "kind", "bytes", "sha256"})
BUSINESS_CHECK_FIELDS = frozenset({"id", "passed", "actual"})
ONLINE_REQUEST_FIELDS = frozenset({"id", "method", "endpoint", "httpStatus"})
RESOLUTION_FIELDS = frozenset({"widthPx", "heightPx"})
EVIDENCE_LEVELS = frozenset(
    {
        "源码确认",
        "静态诊断通过",
        "构建通过",
        "模拟器通过",
        "真机通过",
        "线上通过",
        "未验证",
    }
)
REQUIRED_RECORD_IDS = frozenset(
    {
        "source-package",
        "web-validation",
        "harmonyos-build",
        "golden-demo",
        "final-media",
        "license-and-originality",
        "portal-upload",
    }
)
MAX_RECORDS = len(REQUIRED_RECORD_IDS)
COMMAND_LEVELS = frozenset({"静态诊断通过", "构建通过"})
RUNTIME_LEVELS = frozenset({"模拟器通过", "真机通过", "线上通过"})
STATIC_ENVIRONMENT_FIELDS = frozenset({"os", "tool", "toolVersion"})
DEVICE_ENVIRONMENT_FIELDS = frozenset(
    {"device", "systemVersion", "orientation", "resolution"}
)
ONLINE_ENVIRONMENT_FIELDS = frozenset(
    {"deploymentVersion", "requests"}
)
ARTIFACT_KINDS = frozenset(
    {
        "source",
        "diagnostic",
        "build",
        "hap",
        "ui-tree",
        "screenshot",
        "video",
        "log",
        "media",
        "portal-receipt",
    }
)
DEVICE_ARTIFACT_KINDS = frozenset({"ui-tree", "screenshot", "video", "log"})
ONLINE_ARTIFACT_KINDS = frozenset({"diagnostic", "log", "portal-receipt"})
WEB_ONLINE_CHECK_IDS = frozenset(
    {
        "health.status",
        "health.model",
        "health.deployment",
        "chat.body",
        "chat.event-order",
        "chat.no-error-event",
        "chat.done",
        "chat.citations-as-returned",
        "plan.date",
        "plan.task-count",
        "plan.task-shape",
        "plan.safety",
        "quiz.no-answer-leak",
        "quiz.no-explanation-leak",
        "quiz.grading-separated",
        "quiz.grading-shape",
    }
)
WEB_BOOLEAN_CHECK_IDS = frozenset(
    {
        "chat.event-order",
        "chat.no-error-event",
        "chat.done",
        "plan.task-shape",
        "plan.safety",
        "quiz.no-answer-leak",
        "quiz.no-explanation-leak",
        "quiz.grading-separated",
        "quiz.grading-shape",
    }
)
WEB_ONLINE_REQUEST_IDS = frozenset({"health", "chat", "plan", "quiz"})
WEB_REQUEST_METHODS_AND_PATHS = {
    "health": ("GET", "/api/health"),
    "chat": ("POST", "/api/chat"),
    "plan": ("POST", "/api/plan"),
    "quiz": ("POST", "/api/quiz"),
}


class DuplicateJsonKeyError(ValueError):
    pass


class EvidenceIndexMetrics(NamedTuple):
    records: int
    verified_records: int
    unverified_records: int


def _strict_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError
        result[key] = value
    return result


def _field_errors(
    actual_fields: set[str],
    expected_fields: frozenset[str],
    label: str,
) -> list[str]:
    errors: list[str] = []
    missing = sorted(expected_fields - actual_fields)
    unexpected = sorted(actual_fields - expected_fields)
    if missing:
        errors.append(f"{label} 缺少字段: {','.join(missing)}")
    if unexpected:
        errors.append(f"{label} 包含未定义字段: {','.join(unexpected)}")
    return errors


def _nonempty_text(
    value: object,
    label: str,
    max_characters: int,
    *,
    nullable: bool = False,
) -> tuple[str | None, list[str]]:
    if nullable and value is None:
        return None, []
    if not isinstance(value, str) or not value.strip() or value.strip() != value:
        return None, [f"{label} 必须为无首尾空白的非空字符串"]
    if len(value) > max_characters:
        return None, [f"{label} 超过内部字符上限 {max_characters}"]
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        return None, [f"{label} 包含控制字符"]
    return value, []


def _string_list(value: object, label: str) -> tuple[list[str], list[str]]:
    if not isinstance(value, list):
        return [], [f"{label} 必须为字符串数组"]
    if len(value) > MAX_LIST_ITEMS:
        return [], [f"{label} 超过内部项数上限 {MAX_LIST_ITEMS}"]
    parsed: list[str] = []
    errors: list[str] = []
    for index, item in enumerate(value):
        text, item_errors = _nonempty_text(
            item,
            f"{label}[{index}]",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(item_errors)
        if text is not None:
            parsed.append(text)
    duplicates = sorted(item for item, count in Counter(parsed).items() if count > 1)
    if duplicates:
        errors.append(f"{label} 包含重复项，实际 {len(duplicates)} 类")
    return parsed, errors


def _command_arguments(
    value: object,
    label: str,
) -> tuple[list[str] | None, list[str]]:
    if value is None:
        return None, []
    if not isinstance(value, list):
        return None, [f"{label} 必须为 argv 字符串数组或 null"]
    errors: list[str] = []
    if not value or len(value) > MAX_COMMAND_ARGUMENTS:
        errors.append(f"{label} 参数数量必须为 1..{MAX_COMMAND_ARGUMENTS}")
    arguments: list[str] = []
    for index, item in enumerate(value):
        argument, argument_errors = _nonempty_text(
            item,
            f"{label}[{index}]",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(argument_errors)
        if argument is not None:
            arguments.append(argument)
    return arguments, errors


def _environment(
    value: object,
    label: str,
    level: str | None,
) -> tuple[dict[str, object], list[str]]:
    if not isinstance(value, dict):
        return {}, [f"{label} 必须为对象"]
    if level in COMMAND_LEVELS:
        expected_fields = STATIC_ENVIRONMENT_FIELDS
    elif level in {"模拟器通过", "真机通过"}:
        expected_fields = DEVICE_ENVIRONMENT_FIELDS
    elif level == "线上通过":
        expected_fields = ONLINE_ENVIRONMENT_FIELDS
    else:
        expected_fields = frozenset()
    errors = _field_errors(set(value), expected_fields, label)

    text_fields = expected_fields
    if expected_fields == ONLINE_ENVIRONMENT_FIELDS:
        text_fields = frozenset({"deploymentVersion"})
    elif expected_fields == DEVICE_ENVIRONMENT_FIELDS:
        text_fields = DEVICE_ENVIRONMENT_FIELDS - {"resolution"}
    for field in sorted(text_fields):
        _, text_errors = _nonempty_text(
            value.get(field),
            f"{label}.{field}",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(text_errors)
    if expected_fields == DEVICE_ENVIRONMENT_FIELDS:
        orientation = value.get("orientation")
        if isinstance(orientation, str) and orientation not in {"portrait", "landscape"}:
            errors.append(f"{label}.orientation 必须为 portrait 或 landscape")
        resolution = value.get("resolution")
        if not isinstance(resolution, dict):
            errors.append(f"{label}.resolution 必须为对象")
        else:
            errors.extend(
                _field_errors(set(resolution), RESOLUTION_FIELDS, f"{label}.resolution")
            )
            for field in sorted(RESOLUTION_FIELDS):
                pixels = resolution.get(field)
                if (
                    not isinstance(pixels, int)
                    or isinstance(pixels, bool)
                    or not 1 <= pixels <= 100_000
                ):
                    errors.append(f"{label}.resolution.{field} 必须为正整数")
    if expected_fields == ONLINE_ENVIRONMENT_FIELDS:
        requests = value.get("requests")
        if not isinstance(requests, list):
            errors.append(f"{label}.requests 必须为对象数组")
        elif not requests or len(requests) > MAX_LIST_ITEMS:
            errors.append(f"{label}.requests 数量必须为 1..{MAX_LIST_ITEMS}")
        else:
            seen_request_ids: set[str] = set()
            request_origins: set[tuple[str, str, int | None]] = set()
            for index, request in enumerate(requests):
                request_label = f"{label}.requests[{index}]"
                if not isinstance(request, dict):
                    errors.append(f"{request_label} 必须为对象")
                    continue
                errors.extend(
                    _field_errors(set(request), ONLINE_REQUEST_FIELDS, request_label)
                )
                request_id = request.get("id")
                if (
                    not isinstance(request_id, str)
                    or RECORD_ID_PATTERN.fullmatch(request_id) is None
                ):
                    errors.append(f"{request_label}.id 必须为小写连字符标识")
                elif request_id in seen_request_ids:
                    errors.append(f"{label}.requests 包含重复请求 ID: {request_id}")
                else:
                    seen_request_ids.add(request_id)
                method = request.get("method")
                if method not in {"GET", "POST"}:
                    errors.append(f"{request_label}.method 必须为 GET 或 POST")
                endpoint, endpoint_errors = _nonempty_text(
                    request.get("endpoint"),
                    f"{request_label}.endpoint",
                    MAX_SHORT_TEXT_CHARACTERS,
                )
                errors.extend(endpoint_errors)
                if endpoint is not None:
                    try:
                        parsed_endpoint = urlsplit(endpoint)
                        endpoint_port = parsed_endpoint.port
                    except ValueError:
                        parsed_endpoint = None
                        endpoint_port = None
                    if parsed_endpoint is None or (
                        parsed_endpoint.scheme != "https"
                        or not parsed_endpoint.hostname
                        or parsed_endpoint.username is not None
                        or parsed_endpoint.password is not None
                        or parsed_endpoint.query
                        or parsed_endpoint.fragment
                    ):
                        errors.append(
                            f"{request_label}.endpoint 必须为无凭证、query 和 fragment 的 HTTPS URL"
                        )
                    else:
                        request_origins.add(
                            (
                                parsed_endpoint.scheme,
                                parsed_endpoint.hostname.casefold(),
                                endpoint_port,
                            )
                        )
                        expected_request = WEB_REQUEST_METHODS_AND_PATHS.get(request_id)
                        if expected_request is not None:
                            expected_method, expected_path = expected_request
                            if method != expected_method or parsed_endpoint.path != expected_path:
                                errors.append(
                                    f"{request_label} 必须为 {expected_method} {expected_path}"
                                )
                http_status = request.get("httpStatus")
                if (
                    not isinstance(http_status, int)
                    or isinstance(http_status, bool)
                    or not 200 <= http_status <= 299
                ):
                    errors.append(f"{request_label}.httpStatus 必须为 200..299 整数")
            if len(request_origins) > 1:
                errors.append(f"{label}.requests 必须使用同一 HTTPS origin")
    return value, errors


def _artifact_path_reason(value: str) -> str | None:
    if len(value.encode("utf-8")) > MAX_ARTIFACT_PATH_BYTES:
        return f"UTF-8 路径超过 {MAX_ARTIFACT_PATH_BYTES} 字节"
    if value.startswith("/") or "\\" in value:
        return "必须为规范包内相对路径"
    path = PurePosixPath(value)
    if not path.parts or ".." in path.parts or ":" in path.parts[0]:
        return "不得包含绝对路径或父目录跳转"
    if path.as_posix() != value:
        return "必须为规范包内相对路径"
    return None


def _artifacts(
    value: object,
    label: str,
) -> tuple[list[dict[str, object]], list[str]]:
    if not isinstance(value, list):
        return [], [f"{label} 必须为对象数组"]
    if len(value) > MAX_LIST_ITEMS:
        return [], [f"{label} 超过内部项数上限 {MAX_LIST_ITEMS}"]
    parsed: list[dict[str, object]] = []
    errors: list[str] = []
    seen_paths: set[str] = set()
    for index, item in enumerate(value):
        item_label = f"{label}[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{item_label} 必须为对象")
            continue
        errors.extend(_field_errors(set(item), ARTIFACT_FIELDS, item_label))
        path, text_errors = _nonempty_text(
            item.get("path"),
            f"{item_label}.path",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(text_errors)
        if path is not None:
            path_reason = _artifact_path_reason(path)
            if path_reason is not None:
                errors.append(f"{item_label}.path {path_reason}")
            normalized_path = path.casefold()
            if normalized_path in seen_paths:
                errors.append(f"{label} 包含重复路径")
            seen_paths.add(normalized_path)

        kind = item.get("kind")
        if not isinstance(kind, str) or kind not in ARTIFACT_KINDS:
            errors.append(f"{item_label}.kind 不是允许的证据类型")
        byte_count = item.get("bytes")
        if (
            not isinstance(byte_count, int)
            or isinstance(byte_count, bool)
            or byte_count <= 0
        ):
            errors.append(f"{item_label}.bytes 必须为正整数")
        sha256 = item.get("sha256")
        if not isinstance(sha256, str) or SHA256_PATTERN.fullmatch(sha256) is None:
            errors.append(f"{item_label}.sha256 必须为 64 位小写 SHA-256")
        parsed.append(item)
    return parsed, errors


def _artifact_binding_errors(
    artifacts: list[dict[str, object]],
    available_artifacts: dict[str, bytes] | None,
    label: str,
) -> list[str]:
    if not artifacts:
        return []
    if available_artifacts is None:
        return [f"{label} 无实际字节 resolver，不能支持通过等级"]
    errors: list[str] = []
    for index, artifact in enumerate(artifacts):
        path = artifact.get("path")
        if not isinstance(path, str):
            continue
        content = available_artifacts.get(path)
        if content is None:
            errors.append(f"{label}[{index}] 未绑定实际发布包条目")
            continue
        if artifact.get("bytes") != len(content):
            errors.append(f"{label}[{index}].bytes 与实际发布包条目不一致")
        if artifact.get("sha256") != hashlib.sha256(content).hexdigest():
            errors.append(f"{label}[{index}].sha256 与实际发布包条目不一致")
    return errors


def _business_checks(
    value: object,
    label: str,
) -> tuple[list[dict[str, object]], list[str]]:
    if not isinstance(value, list):
        return [], [f"{label} 必须为对象数组"]
    if len(value) > MAX_LIST_ITEMS:
        return [], [f"{label} 超过内部项数上限 {MAX_LIST_ITEMS}"]
    parsed: list[dict[str, object]] = []
    errors: list[str] = []
    seen_ids: set[str] = set()
    for index, item in enumerate(value):
        item_label = f"{label}[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{item_label} 必须为对象")
            continue
        errors.extend(_field_errors(set(item), BUSINESS_CHECK_FIELDS, item_label))
        check_id = item.get("id")
        if (
            not isinstance(check_id, str)
            or BUSINESS_CHECK_ID_PATTERN.fullmatch(check_id) is None
        ):
            errors.append(f"{item_label}.id 必须为小写点号/连字符标识")
        elif check_id in seen_ids:
            errors.append(f"{label} 包含重复业务检查 ID: {check_id}")
        else:
            seen_ids.add(check_id)
        actual_label = (
            f"{item_label} ({check_id}).actual"
            if isinstance(check_id, str)
            and BUSINESS_CHECK_ID_PATTERN.fullmatch(check_id) is not None
            else f"{item_label}.actual"
        )
        if item.get("passed") is not True:
            errors.append(f"{item_label}.passed 在通过记录中必须为 true")
        actual = item.get("actual")
        if check_id in WEB_BOOLEAN_CHECK_IDS or check_id == "plan.date":
            if actual is not True:
                errors.append(f"{actual_label} 必须为 true")
        elif check_id == "health.status":
            if actual != "ready":
                errors.append(f"{actual_label} 必须精确为 ready")
        elif check_id in {"health.model", "health.deployment"}:
            _, text_errors = _nonempty_text(
                actual,
                actual_label,
                MAX_SHORT_TEXT_CHARACTERS,
            )
            errors.extend(text_errors)
        elif check_id == "chat.body" or check_id == "plan.task-count":
            if (
                not isinstance(actual, int)
                or isinstance(actual, bool)
                or actual <= 0
            ):
                errors.append(f"{actual_label} 必须为正整数")
        elif check_id == "chat.citations-as-returned":
            if (
                not isinstance(actual, int)
                or isinstance(actual, bool)
                or actual < 0
            ):
                errors.append(f"{actual_label} 必须为非负整数")
        elif isinstance(actual, str):
            _, text_errors = _nonempty_text(
                actual,
                actual_label,
                MAX_SHORT_TEXT_CHARACTERS,
            )
            errors.extend(text_errors)
        elif isinstance(actual, bool):
            if actual is not True:
                errors.append(f"{actual_label} 在通过记录中必须为 true")
        elif not isinstance(actual, int) or actual < 0:
            errors.append(f"{actual_label} 必须为非空字符串、true 或非负整数")
        parsed.append(item)
    return parsed, errors


def _valid_recorded_at(value: object) -> bool:
    if not isinstance(value, str) or RFC3339_PATTERN.fullmatch(value) is None:
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def validate_release_evidence(
    content: bytes,
    expected_source_commit: str,
    expected_hap_sha256: str,
    available_artifacts: dict[str, bytes] | None = None,
) -> tuple[EvidenceIndexMetrics, list[str]]:
    empty_metrics = EvidenceIndexMetrics(0, 0, 0)
    if len(content) > MAX_EVIDENCE_INDEX_BYTES:
        return empty_metrics, [
            f"发布证据索引超过内部上限 {MAX_EVIDENCE_INDEX_BYTES} 字节"
        ]
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        return empty_metrics, ["发布证据索引必须为 UTF-8 JSON"]
    try:
        document = json.loads(text, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return empty_metrics, ["发布证据索引 JSON 包含重复键"]
    except json.JSONDecodeError as error:
        return empty_metrics, [
            f"发布证据索引 JSON 无效: line={error.lineno}, column={error.colno}"
        ]
    except (RecursionError, ValueError):
        return empty_metrics, ["发布证据索引 JSON 结构或数值超出内部安全边界"]
    if not isinstance(document, dict):
        return empty_metrics, ["发布证据索引顶层必须为对象"]

    errors = _field_errors(set(document), TOP_LEVEL_FIELDS, "发布证据索引")
    if document.get("schemaVersion") != SCHEMA_VERSION:
        errors.append(f"发布证据索引 schemaVersion 必须为 {SCHEMA_VERSION}")

    source_commit = document.get("sourceCommit")
    if not isinstance(source_commit, str) or FULL_COMMIT_PATTERN.fullmatch(
        source_commit
    ) is None:
        errors.append("发布证据索引 sourceCommit 必须为 40 位小写完整提交哈希")
    elif source_commit != expected_source_commit:
        errors.append("发布证据索引 sourceCommit 与 release-manifest.json 不一致")

    hap_sha256 = document.get("hapSha256")
    if not isinstance(hap_sha256, str) or SHA256_PATTERN.fullmatch(hap_sha256) is None:
        errors.append("发布证据索引 hapSha256 必须为 64 位小写 SHA-256")
    elif hap_sha256 != expected_hap_sha256:
        errors.append("发布证据索引 hapSha256 与实际 HAP 字节不一致")

    limitations, limitation_errors = _string_list(
        document.get("limitations"),
        "发布证据索引 limitations",
    )
    errors.extend(limitation_errors)
    if not limitations:
        errors.append("发布证据索引 limitations 至少需要一项真实边界")

    raw_records = document.get("records")
    if not isinstance(raw_records, list):
        errors.append("发布证据索引 records 必须为对象数组")
        raw_records = []
    elif len(raw_records) != MAX_RECORDS:
        errors.append(f"发布证据索引 records 数量必须恰好为 {MAX_RECORDS}")

    seen_ids: set[str] = set()
    level_counts: Counter[str] = Counter()
    for index, raw_record in enumerate(raw_records):
        label = f"发布证据索引 records[{index}]"
        if not isinstance(raw_record, dict):
            errors.append(f"{label} 必须为对象")
            continue
        errors.extend(_field_errors(set(raw_record), RECORD_FIELDS, label))

        record_id = raw_record.get("id")
        valid_id = isinstance(record_id, str) and RECORD_ID_PATTERN.fullmatch(
            record_id
        ) is not None
        if not valid_id:
            errors.append(f"{label}.id 必须为 3..64 位小写连字符标识")
            record_label = label
        else:
            record_label = f"发布证据记录 {record_id}"
            if record_id in seen_ids:
                errors.append(f"发布证据索引 record id 重复: {record_id}")
            seen_ids.add(record_id)

        _, text_errors = _nonempty_text(
            raw_record.get("claim"),
            f"{record_label}.claim",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(text_errors)
        notes, text_errors = _nonempty_text(
            raw_record.get("notes"),
            f"{record_label}.notes",
            MAX_NOTES_CHARACTERS,
        )
        errors.extend(text_errors)

        level = raw_record.get("level")
        if not isinstance(level, str) or level not in EVIDENCE_LEVELS:
            errors.append(f"{record_label}.level 不是七种精确证据等级之一")
            level = None
        else:
            level_counts[level] += 1

        if not _valid_recorded_at(raw_record.get("recordedAt")):
            errors.append(f"{record_label}.recordedAt 必须为含时区的 RFC 3339 秒级时间")

        command, command_errors = _command_arguments(
            raw_record.get("command"),
            f"{record_label}.command",
        )
        errors.extend(command_errors)
        environment, environment_errors = _environment(
            raw_record.get("environment"),
            f"{record_label}.environment",
            level,
        )
        errors.extend(environment_errors)

        exit_code = raw_record.get("exitCode")
        if exit_code is not None and (
            not isinstance(exit_code, int) or isinstance(exit_code, bool)
        ):
            errors.append(f"{record_label}.exitCode 必须为整数或 null")
            exit_code = None
        if (command is None) != (exit_code is None):
            errors.append(f"{record_label}.command 与 exitCode 必须同时存在或同时为 null")

        artifacts, item_errors = _artifacts(
            raw_record.get("artifacts"),
            f"{record_label}.artifacts",
        )
        errors.extend(item_errors)
        errors.extend(
            _artifact_binding_errors(
                artifacts,
                available_artifacts,
                f"{record_label}.artifacts",
            )
        )
        business_checks, item_errors = _business_checks(
            raw_record.get("businessChecks"),
            f"{record_label}.businessChecks",
        )
        errors.extend(item_errors)

        artifact_kinds = {
            item.get("kind") for item in artifacts if isinstance(item.get("kind"), str)
        }
        business_check_ids = {
            item.get("id")
            for item in business_checks
            if isinstance(item.get("id"), str)
        }
        business_checks_by_id = {
            item.get("id"): item
            for item in business_checks
            if isinstance(item.get("id"), str)
        }
        raw_online_requests = environment.get("requests")
        online_request_ids = (
            {
                request.get("id")
                for request in raw_online_requests
                if isinstance(request, dict) and isinstance(request.get("id"), str)
            }
            if isinstance(raw_online_requests, list)
            else set()
        )

        if level == "源码确认":
            if command is not None or exit_code is not None:
                errors.append(f"{record_label}：源码确认不得记录执行成功")
            if "source" not in artifact_kinds:
                errors.append(f"{record_label}：源码确认必须记录 source 产物")
            if business_checks:
                errors.append(f"{record_label}：源码确认不得记录业务通过检查")
        if level in COMMAND_LEVELS:
            if command is None or exit_code != 0:
                errors.append(f"{record_label}：{level}必须记录 argv 与 exitCode=0")
            if level == "静态诊断通过" and "diagnostic" not in artifact_kinds:
                errors.append(f"{record_label}：静态诊断通过必须记录 diagnostic 产物")
            if level == "构建通过" and not artifact_kinds & {"build", "hap"}:
                errors.append(f"{record_label}：构建通过必须记录 build 或 hap 产物")
            if business_checks:
                errors.append(f"{record_label}：{level}不得记录运行时业务通过检查")
        if level == "构建通过" and record_id == "harmonyos-build":
            matching_hap = any(
                item.get("kind") == "hap" and item.get("sha256") == expected_hap_sha256
                for item in artifacts
            )
            if not matching_hap:
                errors.append(
                    f"{record_label}：HarmonyOS 构建必须记录与顶层绑定一致的 hap 产物"
                )
        if level in RUNTIME_LEVELS:
            if command is None or exit_code != 0:
                errors.append(f"{record_label}：{level}必须记录 argv 与 exitCode=0")
            if not artifacts:
                errors.append(f"{record_label}：{level}必须记录至少一个证据文件")
            if not business_checks:
                errors.append(f"{record_label}：{level}必须记录业务字段或流程检查")
        if level in {"模拟器通过", "真机通过"} and not (
            artifact_kinds & DEVICE_ARTIFACT_KINDS
        ):
            errors.append(f"{record_label}：{level}必须记录 UI 树、截图、视频或日志")
        if level == "线上通过":
            if not artifact_kinds & ONLINE_ARTIFACT_KINDS:
                errors.append(f"{record_label}：线上通过必须记录诊断、日志或门户回执")
            if record_id == "web-validation":
                missing_requests = sorted(WEB_ONLINE_REQUEST_IDS - online_request_ids)
                unexpected_requests = sorted(online_request_ids - WEB_ONLINE_REQUEST_IDS)
                if missing_requests:
                    errors.append(
                        f"{record_label}：Web 线上通过缺少固定请求证据: "
                        + ",".join(missing_requests)
                    )
                if unexpected_requests:
                    errors.append(
                        f"{record_label}：Web 线上通过包含未定义请求证据: "
                        + ",".join(unexpected_requests)
                    )
                if isinstance(raw_online_requests, list) and any(
                    isinstance(request, dict) and request.get("httpStatus") != 200
                    for request in raw_online_requests
                ):
                    errors.append(f"{record_label}：Web 线上四类请求必须全部为 HTTP 200")
                missing_checks = sorted(WEB_ONLINE_CHECK_IDS - business_check_ids)
                unexpected_checks = sorted(business_check_ids - WEB_ONLINE_CHECK_IDS)
                if missing_checks:
                    errors.append(
                        f"{record_label}：Web 线上通过缺少固定业务检查: "
                        + ",".join(missing_checks)
                    )
                if unexpected_checks:
                    errors.append(
                        f"{record_label}：Web 线上通过包含未定义业务检查: "
                        + ",".join(unexpected_checks)
                    )
                deployment_check = business_checks_by_id.get("health.deployment")
                if (
                    deployment_check is not None
                    and deployment_check.get("actual")
                    != environment.get("deploymentVersion")
                ):
                    errors.append(
                        f"{record_label}：health.deployment 必须等于 deploymentVersion"
                    )
        if level == "未验证":
            if notes is None:
                errors.append(f"{record_label}：未验证状态必须说明真实缺口")
            if (
                command is not None
                or exit_code is not None
                or environment
                or artifacts
                or business_checks
            ):
                errors.append(f"{record_label}：未验证状态不得夹带通过证据")

    missing_records = sorted(REQUIRED_RECORD_IDS - seen_ids)
    if missing_records:
        errors.append("发布证据索引缺少发布面: " + ",".join(missing_records))
    unexpected_records = sorted(seen_ids - REQUIRED_RECORD_IDS)
    if unexpected_records:
        errors.append(
            "发布证据索引包含未定义发布面: " + ",".join(unexpected_records)
        )

    metrics = EvidenceIndexMetrics(
        records=len(raw_records),
        verified_records=sum(
            count for level, count in level_counts.items() if level != "未验证"
        ),
        unverified_records=level_counts["未验证"],
    )
    return metrics, errors


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index-path", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--hap-sha256", required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        content = args.index_path.read_bytes()
    except OSError as error:
        print(f"[FAIL] 发布证据索引无法只读打开 ({type(error).__name__})")
        return 1
    metrics, errors = validate_release_evidence(
        content,
        args.source_commit,
        args.hap_sha256,
    )
    if errors:
        print(f"[FAIL] 发布证据索引门禁: {len(errors)} 项")
        for error in errors:
            print(f"  - {error}")
        print("\nSOME CHECKS FAILED")
        return 1
    print(
        "[PASS] 发布证据索引门禁: "
        f"records={metrics.records}; verified={metrics.verified_records}; "
        f"unverified={metrics.unverified_records}"
    )
    print("证据边界: 未验证记录保持未验证，不因索引结构通过而升级证据等级。")
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
