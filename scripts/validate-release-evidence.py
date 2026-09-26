#!/usr/bin/env python3
"""只读校验正式发布证据索引与源码提交、HAP 哈希的绑定。"""

from __future__ import annotations

import argparse
import base64
import binascii
import ipaddress
import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import NamedTuple
from urllib.parse import urlsplit


sys.dont_write_bytecode = True

SCHEMA_VERSION = 3
MAX_EVIDENCE_INDEX_BYTES = 64 * 1024
MAX_LIST_ITEMS = 50
MAX_COMMAND_ARGUMENTS = 32
MAX_SHORT_TEXT_CHARACTERS = 300
MAX_NOTES_CHARACTERS = 2000
MAX_ARTIFACT_PATH_BYTES = 512
MAX_ONLINE_CAPTURE_BYTES = 2 * 1024 * 1024
MAX_ONLINE_CAPTURE_SPAN_SECONDS = 15 * 60
EVIDENCE_ARTIFACT_PREFIX = "evidence/artifacts/"
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
BUSINESS_CHECK_FIELDS = frozenset(
    {"id", "passed", "actual", "artifactPath"}
)
ONLINE_REQUEST_FIELDS = frozenset({"id", "method", "endpoint", "httpStatus"})
HAR_LOG_REQUIRED_FIELDS = frozenset({"version", "creator", "entries"})
HAR_ENTRY_REQUIRED_FIELDS = frozenset(
    {"startedDateTime", "time", "request", "response", "cache", "timings"}
)
HAR_REQUEST_REQUIRED_FIELDS = frozenset(
    {
        "method",
        "url",
        "httpVersion",
        "headers",
        "queryString",
        "cookies",
        "headersSize",
        "bodySize",
    }
)
HAR_RESPONSE_REQUIRED_FIELDS = frozenset(
    {
        "status",
        "statusText",
        "httpVersion",
        "headers",
        "cookies",
        "content",
        "redirectURL",
        "headersSize",
        "bodySize",
    }
)
HAR_CONTENT_REQUIRED_FIELDS = frozenset({"size", "mimeType", "text"})
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
        "capture",
    }
)
DEVICE_ARTIFACT_KINDS = frozenset({"ui-tree", "screenshot", "video", "log"})
ONLINE_ARTIFACT_KINDS = frozenset(
    {"diagnostic", "log", "portal-receipt", "capture"}
)
GOLDEN_DEMO_CHECK_IDS = frozenset(
    {
        "demo.d01.release-identity",
        "demo.d02.manual-reminder",
        "demo.d03.topic-context",
        "demo.d04.live-chat",
        "demo.d05.live-quiz",
        "demo.d06.arkdata-persistence",
        "demo.d07.evidence-close",
    }
)
GOLDEN_DEMO_LEVELS = frozenset({"模拟器通过", "真机通过", "未验证"})
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
CAPTURE_CONTENT_TYPES = {
    "health": "application/json",
    "chat": "text/event-stream",
    "plan": "application/json",
    "quiz": "application/json",
}
RESERVED_ONLINE_HOST_SUFFIXES = (
    ".invalid",
    ".example",
    ".test",
    ".localhost",
    ".local",
)


class DuplicateJsonKeyError(ValueError):
    pass


class EvidenceIndexMetrics(NamedTuple):
    records: int
    verified_records: int
    unverified_records: int


class ArtifactBinding(NamedTuple):
    byte_count: int
    sha256: str
    role: str
    content: bytes | None


class EvidenceRecordBinding(NamedTuple):
    level: str
    artifact_paths: frozenset[str]
    artifact_references: frozenset[tuple[str, str]]


class OnlineCapture(NamedTuple):
    captured_at: str
    deployment_version: str
    requests: tuple[dict[str, object], ...]
    business_checks: dict[str, object]


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


def _online_hostname_error(hostname: str) -> str | None:
    normalized = hostname.casefold().rstrip(".")
    if not normalized or "." not in normalized:
        return "必须使用可核验的公网主机名"
    if normalized in {"example.com", "example.org", "example.net"} or normalized.endswith(
        RESERVED_ONLINE_HOST_SUFFIXES
    ):
        return "不得使用示例、测试或本地主机名"
    try:
        address = ipaddress.ip_address(normalized)
    except ValueError:
        return None
    if not address.is_global:
        return "不得使用非公网 IP 地址"
    return None


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
                        hostname_error = _online_hostname_error(
                            parsed_endpoint.hostname
                        )
                        if hostname_error is not None:
                            errors.append(
                                f"{request_label}.endpoint {hostname_error}"
                            )
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
    available_artifacts: dict[str, ArtifactBinding] | None,
    label: str,
    level: str | None,
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
        binding = available_artifacts.get(path)
        if binding is None:
            errors.append(f"{label}[{index}] 未绑定实际发布包条目")
            continue
        if not isinstance(binding, ArtifactBinding):
            errors.append(f"{label}[{index}] 实际发布包条目元数据类型无效")
            continue
        if artifact.get("bytes") != binding.byte_count:
            errors.append(f"{label}[{index}].bytes 与实际发布包条目不一致")
        if artifact.get("sha256") != binding.sha256:
            errors.append(f"{label}[{index}].sha256 与实际发布包条目不一致")
        kind = artifact.get("kind")
        if binding.role == "git-source" and not (
            level == "源码确认" and kind == "source"
        ):
            errors.append(f"{label}[{index}] 运行证据不得来自 Git 源文件")
        if level in RUNTIME_LEVELS and binding.role != "evidence-artifact":
            errors.append(
                f"{label}[{index}] {level}必须绑定 evidence-artifact 角色"
            )
        if binding.role == "evidence-artifact" and not path.startswith(
            EVIDENCE_ARTIFACT_PREFIX
        ):
            errors.append(
                f"{label}[{index}] evidence-artifact 必须位于 "
                f"{EVIDENCE_ARTIFACT_PREFIX}"
            )
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
        artifact_path, artifact_path_errors = _nonempty_text(
            item.get("artifactPath"),
            f"{item_label}.artifactPath",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(artifact_path_errors)
        if artifact_path is not None:
            path_reason = _artifact_path_reason(artifact_path)
            if path_reason is not None:
                errors.append(f"{item_label}.artifactPath {path_reason}")
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


def _json_response_object(
    body: str,
    label: str,
) -> tuple[dict[str, object] | None, list[str]]:
    try:
        value = json.loads(body, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return None, [f"{label} JSON 包含重复键"]
    except (json.JSONDecodeError, RecursionError, ValueError):
        return None, [f"{label} 不是有效 JSON 对象"]
    if not isinstance(value, dict):
        return None, [f"{label} 顶层必须为对象"]
    return value, []


def _health_business_checks(
    body: str,
    deployment_version: str,
    label: str,
) -> tuple[dict[str, object], list[str]]:
    document, errors = _json_response_object(body, label)
    if document is None:
        return {}, errors
    checks: dict[str, object] = {}
    if document.get("status") != "ready":
        errors.append(f"{label}.status 必须精确为 ready")
    else:
        checks["health.status"] = "ready"
    model = document.get("model")
    if not isinstance(model, dict) or model.get("configured") is not True:
        errors.append(f"{label}.model 必须是 configured=true 的对象")
    else:
        model_name, model_errors = _nonempty_text(
            model.get("name"),
            f"{label}.model.name",
            MAX_SHORT_TEXT_CHARACTERS,
        )
        errors.extend(model_errors)
        if model_name is not None:
            checks["health.model"] = model_name
    version, version_errors = _nonempty_text(
        document.get("version"),
        f"{label}.version",
        MAX_SHORT_TEXT_CHARACTERS,
    )
    errors.extend(version_errors)
    if version is not None:
        if version != deployment_version:
            errors.append(f"{label}.version 必须等于 capture deploymentVersion")
        checks["health.deployment"] = version
    return checks, errors


def _chat_business_checks(
    body: str,
    label: str,
) -> tuple[dict[str, object], list[str]]:
    errors: list[str] = []
    if "\r" in body.replace("\r\n", ""):
        return {}, [f"{label} 包含无效裸 CR"]
    normalized = body.replace("\r\n", "\n")
    blocks = [block for block in normalized.split("\n\n") if block]
    events: list[dict[str, object]] = []
    for index, block in enumerate(blocks):
        event_label = f"{label}.events[{index}]"
        lines = block.split("\n")
        if len(lines) != 1 or not lines[0].startswith("data: "):
            errors.append(f"{event_label} 必须是单行 data SSE 事件")
            continue
        event, event_errors = _json_response_object(
            lines[0][6:],
            event_label,
        )
        errors.extend(event_errors)
        if event is not None:
            events.append(event)

    allowed_types = {"thinking", "delta", "citation", "trace", "action", "error", "done"}
    event_types: list[str] = []
    body_characters = 0
    citations = 0
    done_sessions: list[str] = []
    for index, event in enumerate(events):
        event_label = f"{label}.events[{index}]"
        event_type = event.get("type")
        if not isinstance(event_type, str) or event_type not in allowed_types:
            errors.append(f"{event_label}.type 不是当前 StreamEvent 类型")
            continue
        event_types.append(event_type)
        if event_type == "delta":
            content = event.get("content")
            if not isinstance(content, str):
                errors.append(f"{event_label}.content 必须为字符串")
            else:
                body_characters += len(content)
        elif event_type == "citation":
            if not isinstance(event.get("source"), dict):
                errors.append(f"{event_label}.source 必须为对象")
            else:
                citations += 1
        elif event_type == "action":
            action = event.get("action")
            if not isinstance(action, dict):
                errors.append(f"{event_label}.action 必须为对象")
            else:
                if action.get("kind") not in {"lesson", "practice", "quiz", "review"}:
                    errors.append(f"{event_label}.action.kind 不是受控学习动作")
                if action.get("courseId") not in {"cs101", "cs102", "cs103"}:
                    errors.append(f"{event_label}.action.courseId 不是现有课程")
                for field in ("topic", "title", "reason"):
                    _, field_errors = _nonempty_text(
                        action.get(field),
                        f"{event_label}.action.{field}",
                        MAX_SHORT_TEXT_CHARACTERS,
                    )
                    errors.extend(field_errors)
        elif event_type == "done":
            session_id, session_errors = _nonempty_text(
                event.get("sessionId"),
                f"{event_label}.sessionId",
                MAX_SHORT_TEXT_CHARACTERS,
            )
            errors.extend(session_errors)
            if session_id is not None:
                done_sessions.append(session_id)

    if body_characters <= 0:
        errors.append(f"{label} 必须包含非空 delta 正文")
    if "error" in event_types:
        errors.append(f"{label} 不得包含 error 事件")
    if len(done_sessions) != 1 or done_sessions[0] == "error":
        errors.append(f"{label} 必须包含唯一非 error done sessionId")
    if not event_types or event_types[-1] != "done":
        errors.append(f"{label} done 必须是最后一个事件")
    checks = {
        "chat.body": body_characters,
        "chat.event-order": bool(event_types and event_types[-1] == "done"),
        "chat.no-error-event": "error" not in event_types,
        "chat.done": len(done_sessions) == 1 and done_sessions[0] != "error",
        "chat.citations-as-returned": citations,
    }
    return checks, errors


def _plan_business_checks(
    body: str,
    label: str,
) -> tuple[dict[str, object], list[str]]:
    document, errors = _json_response_object(body, label)
    if document is None:
        return {}, errors
    tasks = document.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        return {}, [*errors, f"{label}.tasks 必须为非空对象数组"]
    allowed_types = {"review", "practice", "reading", "quiz"}
    dates_valid = True
    shapes_valid = True
    for index, task in enumerate(tasks):
        task_label = f"{label}.tasks[{index}]"
        if not isinstance(task, dict):
            errors.append(f"{task_label} 必须为对象")
            dates_valid = False
            shapes_valid = False
            continue
        for field in ("id", "title"):
            _, field_errors = _nonempty_text(
                task.get(field),
                f"{task_label}.{field}",
                MAX_SHORT_TEXT_CHARACTERS,
            )
            if field_errors:
                shapes_valid = False
            errors.extend(field_errors)
        date_value = task.get("date")
        if not isinstance(date_value, str):
            dates_valid = False
            errors.append(f"{task_label}.date 必须为 YYYY-MM-DD")
        else:
            try:
                datetime.strptime(date_value, "%Y-%m-%d")
            except ValueError:
                dates_valid = False
                errors.append(f"{task_label}.date 必须为 YYYY-MM-DD")
        estimated = task.get("estimatedMin")
        if not isinstance(estimated, int) or isinstance(estimated, bool) or estimated <= 0:
            shapes_valid = False
            errors.append(f"{task_label}.estimatedMin 必须为正整数")
        if task.get("type") not in allowed_types:
            shapes_valid = False
            errors.append(f"{task_label}.type 不是当前 PlanTask 类型")
    return {
        "plan.date": dates_valid,
        "plan.task-count": len(tasks),
        "plan.task-shape": shapes_valid,
        "plan.safety": True,
    }, errors


def _quiz_business_checks(
    body: str,
    label: str,
) -> tuple[dict[str, object], list[str]]:
    document, errors = _json_response_object(body, label)
    if document is None:
        return {}, errors
    questions = document.get("questions")
    grading = document.get("grading")
    if not isinstance(questions, list) or not questions:
        errors.append(f"{label}.questions 必须为非空对象数组")
        questions = []
    if not isinstance(grading, list) or not grading:
        errors.append(f"{label}.grading 必须为非空对象数组")
        grading = []
    no_answer_leak = all(
        isinstance(question, dict) and "answer" not in question
        for question in questions
    )
    no_explanation_leak = all(
        isinstance(question, dict) and "explanation" not in question
        for question in questions
    )
    question_ids = [
        question.get("id")
        for question in questions
        if isinstance(question, dict) and isinstance(question.get("id"), str)
    ]
    grading_ids = [
        item.get("questionId")
        for item in grading
        if isinstance(item, dict) and isinstance(item.get("questionId"), str)
    ]
    grading_shape = (
        len(question_ids) == len(questions)
        and len(grading_ids) == len(grading)
        and question_ids == grading_ids
        and len(set(question_ids)) == len(question_ids)
        and all(
            isinstance(item, dict)
            and isinstance(item.get("answer"), str)
            and bool(item.get("answer"))
            and isinstance(item.get("explanation"), str)
            and bool(item.get("explanation"))
            and isinstance(item.get("tags"), list)
            for item in grading
        )
    )
    if not no_answer_leak:
        errors.append(f"{label}.questions 泄露 answer")
    if not no_explanation_leak:
        errors.append(f"{label}.questions 泄露 explanation")
    if len(questions) != len(grading):
        errors.append(f"{label}.questions 与 grading 数量不一致")
    if not grading_shape:
        errors.append(f"{label}.grading 结构或 questionId 对应关系无效")
    return {
        "quiz.no-answer-leak": no_answer_leak,
        "quiz.no-explanation-leak": no_explanation_leak,
        "quiz.grading-separated": isinstance(document.get("grading"), list),
        "quiz.grading-shape": grading_shape,
    }, errors


def _missing_har_fields(
    value: dict[str, object],
    required: frozenset[str],
    label: str,
) -> list[str]:
    missing = sorted(required - set(value))
    return [f"{label} 缺少 HAR 1.2 字段: {','.join(missing)}"] if missing else []


def _har_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def _har_response_text(
    content: dict[str, object],
    label: str,
) -> tuple[str | None, list[str]]:
    errors = _missing_har_fields(content, HAR_CONTENT_REQUIRED_FIELDS, label)
    raw_text = content.get("text")
    if not isinstance(raw_text, str):
        return None, [*errors, f"{label}.text 必须为 HAR 原始响应字符串"]
    encoding = content.get("encoding")
    try:
        raw_bytes = (
            base64.b64decode(raw_text, validate=True)
            if encoding == "base64"
            else raw_text.encode("utf-8")
        )
    except (UnicodeEncodeError, binascii.Error, ValueError):
        return None, [*errors, f"{label}.text 无法按 HAR encoding 解码"]
    if encoding not in {None, "base64"}:
        errors.append(f"{label}.encoding 只接受 base64 或省略")
    size = content.get("size")
    if not isinstance(size, int) or isinstance(size, bool) or size < 0:
        errors.append(f"{label}.size 必须为非负整数")
    elif size != len(raw_bytes):
        errors.append(f"{label}.size 与原始响应字节数不一致")
    try:
        return raw_bytes.decode("utf-8"), errors
    except UnicodeDecodeError:
        return None, [*errors, f"{label}.text 必须解码为 UTF-8 API 响应"]


def parse_online_capture(
    content: bytes,
    label: str,
) -> tuple[OnlineCapture | None, list[str]]:
    if len(content) > MAX_ONLINE_CAPTURE_BYTES:
        return None, [f"{label} 超过内部上限 {MAX_ONLINE_CAPTURE_BYTES} 字节"]
    try:
        document = json.loads(content, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return None, [f"{label} HAR JSON 包含重复键"]
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return None, [f"{label} 必须为 UTF-8 HAR JSON"]
    if not isinstance(document, dict) or set(document) != {"log"}:
        return None, [f"{label} 必须为 HAR 1.2 顶层 log 对象"]
    log = document.get("log")
    if not isinstance(log, dict):
        return None, [f"{label}.log 必须为 HAR 1.2 对象"]

    errors = _missing_har_fields(log, HAR_LOG_REQUIRED_FIELDS, f"{label}.log")
    if log.get("version") != "1.2":
        errors.append(f"{label}.log.version 必须为 HAR 1.2")
    creator = log.get("creator")
    if not isinstance(creator, dict) or not all(
        isinstance(creator.get(field), str) and bool(creator[field].strip())
        for field in ("name", "version")
    ):
        errors.append(f"{label}.log.creator 必须包含非空 name/version")
    raw_entries = log.get("entries")
    if not isinstance(raw_entries, list):
        return None, [*errors, f"{label}.log.entries 必须为 HAR 对象数组"]
    if len(raw_entries) != len(WEB_ONLINE_REQUEST_IDS):
        errors.append(
            f"{label}.log.entries 必须恰好包含四个 API 原始响应"
        )

    summaries: list[dict[str, object]] = []
    bodies: dict[str, str] = {}
    timestamps: list[datetime] = []
    for index, entry in enumerate(raw_entries):
        entry_label = f"{label}.log.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{entry_label} 必须为 HAR 对象")
            continue
        errors.extend(_missing_har_fields(entry, HAR_ENTRY_REQUIRED_FIELDS, entry_label))
        captured = _har_timestamp(entry.get("startedDateTime"))
        if captured is None:
            errors.append(f"{entry_label}.startedDateTime 必须为含时区 RFC 3339 时间")
        else:
            timestamps.append(captured)

        request = entry.get("request")
        response = entry.get("response")
        if not isinstance(request, dict) or not isinstance(response, dict):
            errors.append(f"{entry_label} 必须包含 HAR request/response 对象")
            continue
        errors.extend(
            _missing_har_fields(request, HAR_REQUEST_REQUIRED_FIELDS, f"{entry_label}.request")
        )
        errors.extend(
            _missing_har_fields(response, HAR_RESPONSE_REQUIRED_FIELDS, f"{entry_label}.response")
        )
        method = request.get("method")
        endpoint = request.get("url")
        request_id = None
        if isinstance(method, str) and isinstance(endpoint, str):
            parsed = urlsplit(endpoint)
            request_id = next(
                (
                    item_id
                    for item_id, expected in WEB_REQUEST_METHODS_AND_PATHS.items()
                    if method == expected[0] and parsed.path == expected[1]
                ),
                None,
            )
        if request_id is None:
            errors.append(f"{entry_label}.request method/url 不属于四个固定 API")
            continue
        if request_id in bodies:
            errors.append(f"{label} HAR API 请求重复: {request_id}")

        status = response.get("status")
        if not isinstance(status, int) or isinstance(status, bool):
            errors.append(f"{entry_label}.response.status 必须为整数")
            status = None
        raw_content = response.get("content")
        if not isinstance(raw_content, dict):
            errors.append(f"{entry_label}.response.content 必须为 HAR 对象")
            continue
        content_type = raw_content.get("mimeType")
        expected_content_type = CAPTURE_CONTENT_TYPES[request_id]
        normalized_content_type = (
            content_type.split(";", 1)[0].strip().casefold()
            if isinstance(content_type, str)
            else None
        )
        if normalized_content_type != expected_content_type:
            errors.append(
                f"{entry_label}.response.content.mimeType 必须为 {expected_content_type}"
            )
        header_values = [
            header.get("value")
            for header in response.get("headers", [])
            if isinstance(header, dict)
            and isinstance(header.get("name"), str)
            and header["name"].casefold() == "content-type"
            and isinstance(header.get("value"), str)
        ] if isinstance(response.get("headers"), list) else []
        if len(header_values) != 1 or header_values[0].split(";", 1)[0].strip().casefold() != expected_content_type:
            errors.append(f"{entry_label}.response.headers 缺少唯一匹配的 Content-Type")
        response_body, body_errors = _har_response_text(
            raw_content,
            f"{entry_label}.response.content",
        )
        errors.extend(body_errors)
        if response_body is not None:
            bodies[request_id] = response_body
        summaries.append(
            {
                "id": request_id,
                "method": method,
                "endpoint": endpoint,
                "httpStatus": status,
            }
        )

    request_ids = {
        item.get("id") for item in summaries if isinstance(item.get("id"), str)
    }
    missing_requests = sorted(WEB_ONLINE_REQUEST_IDS - request_ids)
    unexpected_requests = sorted(request_ids - WEB_ONLINE_REQUEST_IDS)
    if missing_requests:
        errors.append(f"{label} 缺少 HAR 原始请求: {','.join(missing_requests)}")
    if unexpected_requests:
        errors.append(f"{label} 包含未定义 HAR 请求: {','.join(unexpected_requests)}")
    if any(item.get("httpStatus") != 200 for item in summaries):
        errors.append(f"{label} capture 四类请求必须全部为 HTTP 200")

    captured_at = ""
    if len(timestamps) == len(raw_entries) and timestamps:
        earliest = min(timestamps)
        latest = max(timestamps)
        if (latest - earliest).total_seconds() > MAX_ONLINE_CAPTURE_SPAN_SECONDS:
            errors.append(f"{label} 四个 HAR 请求时间跨度超过 15 分钟")
        captured_at = earliest.replace(microsecond=0).isoformat()

    deployment_version = ""
    if "health" in bodies:
        health_document, health_errors = _json_response_object(
            bodies["health"],
            f"{label}.health.responseBody",
        )
        errors.extend(health_errors)
        if health_document is not None:
            raw_version = health_document.get("version")
            if isinstance(raw_version, str) and raw_version.strip():
                deployment_version = raw_version
            else:
                errors.append(f"{label}.health.responseBody.version 必须为非空字符串")
    environment, environment_errors = _environment(
        {"deploymentVersion": deployment_version, "requests": summaries},
        f"{label}.environment",
        "线上通过",
    )
    errors.extend(environment_errors)

    checks: dict[str, object] = {}
    if "health" in bodies and deployment_version:
        derived, derived_errors = _health_business_checks(
            bodies["health"], deployment_version, f"{label}.health.responseBody"
        )
        checks.update(derived)
        errors.extend(derived_errors)
    if "chat" in bodies:
        derived, derived_errors = _chat_business_checks(
            bodies["chat"], f"{label}.chat.responseBody"
        )
        checks.update(derived)
        errors.extend(derived_errors)
    if "plan" in bodies:
        derived, derived_errors = _plan_business_checks(
            bodies["plan"], f"{label}.plan.responseBody"
        )
        checks.update(derived)
        errors.extend(derived_errors)
    if "quiz" in bodies:
        derived, derived_errors = _quiz_business_checks(
            bodies["quiz"], f"{label}.quiz.responseBody"
        )
        checks.update(derived)
        errors.extend(derived_errors)
    return OnlineCapture(
        captured_at,
        deployment_version,
        tuple(summaries),
        checks,
    ), errors


def artifact_reference_owners(
    content: bytes,
) -> tuple[dict[str, set[str]], list[str]]:
    if len(content) > MAX_EVIDENCE_INDEX_BYTES:
        return {}, ["发布证据索引过大，无法收集 artifact 引用"]
    try:
        document = json.loads(content, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return {}, ["发布证据索引 JSON 包含重复键，无法收集 artifact 引用"]
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return {}, ["发布证据索引无法解析 artifact 引用"]
    if not isinstance(document, dict) or not isinstance(document.get("records"), list):
        return {}, ["发布证据索引缺少 records，无法收集 artifact 引用"]
    owners: dict[str, set[str]] = {}
    for record in document["records"]:
        if not isinstance(record, dict):
            continue
        record_id = record.get("id")
        artifacts = record.get("artifacts")
        if not isinstance(record_id, str) or not isinstance(artifacts, list):
            continue
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                continue
            path = artifact.get("path")
            if isinstance(path, str):
                owners.setdefault(path, set()).add(record_id)
    return owners, []


def evidence_record_bindings(
    content: bytes,
) -> tuple[dict[str, EvidenceRecordBinding], list[str]]:
    if len(content) > MAX_EVIDENCE_INDEX_BYTES:
        return {}, ["发布证据索引过大，无法收集记录绑定"]
    try:
        document = json.loads(content, object_pairs_hook=_strict_object)
    except DuplicateJsonKeyError:
        return {}, ["发布证据索引 JSON 包含重复键，无法收集记录绑定"]
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return {}, ["发布证据索引无法解析记录绑定"]
    if not isinstance(document, dict) or not isinstance(document.get("records"), list):
        return {}, ["发布证据索引缺少 records，无法收集记录绑定"]

    bindings: dict[str, EvidenceRecordBinding] = {}
    errors: list[str] = []
    for index, record in enumerate(document["records"]):
        if not isinstance(record, dict):
            errors.append(f"发布证据索引 records[{index}] 无法收集记录绑定")
            continue
        record_id = record.get("id")
        level = record.get("level")
        artifacts = record.get("artifacts")
        if (
            not isinstance(record_id, str)
            or not isinstance(level, str)
            or not isinstance(artifacts, list)
        ):
            errors.append(f"发布证据索引 records[{index}] 记录绑定字段无效")
            continue
        if record_id in bindings:
            errors.append(f"发布证据索引记录绑定 ID 重复: {record_id}")
            continue
        artifact_references = frozenset(
            (artifact["path"], artifact["kind"])
            for artifact in artifacts
            if isinstance(artifact, dict)
            and isinstance(artifact.get("path"), str)
            and isinstance(artifact.get("kind"), str)
        )
        bindings[record_id] = EvidenceRecordBinding(
            level,
            frozenset(path for path, _ in artifact_references),
            artifact_references,
        )
    return bindings, errors


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
    available_artifacts: dict[str, ArtifactBinding] | None = None,
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
        record_error_start = len(errors)
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
                level,
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
        artifact_paths = {
            item.get("path")
            for item in artifacts
            if isinstance(item.get("path"), str)
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
        for check in business_checks:
            check_id = check.get("id")
            artifact_path = check.get("artifactPath")
            if isinstance(artifact_path, str) and artifact_path not in artifact_paths:
                errors.append(
                    f"{record_label}：业务检查 {check_id} 的 artifactPath "
                    "未在本记录 artifacts 中声明"
                )
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
        if record_id == "golden-demo" and level not in GOLDEN_DEMO_LEVELS:
            errors.append(
                f"{record_label}：golden-demo 只接受未验证、模拟器通过或真机通过"
            )
        if level in {"模拟器通过", "真机通过"} and not (
            artifact_kinds & DEVICE_ARTIFACT_KINDS
        ):
            errors.append(f"{record_label}：{level}必须记录 UI 树、截图、视频或日志")
        if level in {"模拟器通过", "真机通过"} and record_id == "golden-demo":
            missing_demo_checks = sorted(GOLDEN_DEMO_CHECK_IDS - business_check_ids)
            unexpected_demo_checks = sorted(business_check_ids - GOLDEN_DEMO_CHECK_IDS)
            if missing_demo_checks:
                errors.append(
                    f"{record_label}：黄金演示缺少 D01-D07 固定检查: "
                    + ",".join(missing_demo_checks)
                )
            if unexpected_demo_checks:
                errors.append(
                    f"{record_label}：黄金演示包含未定义检查: "
                    + ",".join(unexpected_demo_checks)
                )
            if "ui-tree" not in artifact_kinds or "video" not in artifact_kinds:
                errors.append(
                    f"{record_label}：黄金演示必须同时绑定 ui-tree 与 video 证据"
                )
        if level == "线上通过":
            if not artifact_kinds & ONLINE_ARTIFACT_KINDS:
                errors.append(f"{record_label}：线上通过必须记录诊断、日志或门户回执")
            if record_id == "web-validation":
                capture_artifacts = [
                    item for item in artifacts if item.get("kind") == "capture"
                ]
                if len(capture_artifacts) != 1:
                    errors.append(
                        f"{record_label}：线上通过必须绑定唯一 capture"
                    )
                else:
                    capture_path = capture_artifacts[0].get("path")
                    if (
                        not isinstance(capture_path, str)
                        or PurePosixPath(capture_path).suffix.casefold() != ".har"
                    ):
                        errors.append(
                            f"{record_label}：capture artifactPath 必须使用 .har 后缀"
                        )
                    capture_binding = (
                        available_artifacts.get(capture_path)
                        if available_artifacts is not None
                        and isinstance(capture_path, str)
                        else None
                    )
                    if (
                        not isinstance(capture_binding, ArtifactBinding)
                        or capture_binding.content is None
                    ):
                        errors.append(
                            f"{record_label}：capture 必须绑定可解析的实际原始响应字节"
                        )
                    else:
                        capture, capture_errors = parse_online_capture(
                            capture_binding.content,
                            f"{record_label}.capture",
                        )
                        errors.extend(capture_errors)
                        if capture is not None:
                            if raw_record.get("recordedAt") != capture.captured_at:
                                errors.append(
                                    f"{record_label}：recordedAt 必须等于 capture capturedAt"
                                )
                            if environment.get("deploymentVersion") != capture.deployment_version:
                                errors.append(
                                    f"{record_label}：deploymentVersion 必须来自 capture"
                                )
                            captured_requests = {
                                item.get("id"): item for item in capture.requests
                            }
                            declared_requests = {
                                item.get("id"): item
                                for item in raw_online_requests
                                if isinstance(item, dict)
                            } if isinstance(raw_online_requests, list) else {}
                            if declared_requests != captured_requests:
                                errors.append(
                                    f"{record_label}：requests 必须与 capture 请求元数据一致"
                                )
                            declared_checks = {
                                check_id: item.get("actual")
                                for check_id, item in business_checks_by_id.items()
                            }
                            if declared_checks != capture.business_checks:
                                errors.append(
                                    f"{record_label}：businessChecks 必须由 capture 原始响应推导"
                                )
                            if any(
                                item.get("artifactPath") != capture_path
                                for item in business_checks
                            ):
                                errors.append(
                                    f"{record_label}：线上业务检查必须逐项引用唯一 capture"
                                )
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
        if level is not None and len(errors) == record_error_start:
            level_counts[level] += 1

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
