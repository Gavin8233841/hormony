#!/usr/bin/env python3
"""只读校验正式发布证据索引与源码提交、HAP 哈希的绑定。"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import NamedTuple


sys.dont_write_bytecode = True

SCHEMA_VERSION = 1
MAX_EVIDENCE_INDEX_BYTES = 64 * 1024
MAX_LIST_ITEMS = 50
MAX_SHORT_TEXT_CHARACTERS = 300
MAX_NOTES_CHARACTERS = 2000
FULL_COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
RECORD_ID_PATTERN = re.compile(r"[a-z][a-z0-9-]{2,63}")
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

        command, text_errors = _nonempty_text(
            raw_record.get("command"),
            f"{record_label}.command",
            MAX_SHORT_TEXT_CHARACTERS,
            nullable=True,
        )
        errors.extend(text_errors)
        environment, text_errors = _nonempty_text(
            raw_record.get("environment"),
            f"{record_label}.environment",
            MAX_SHORT_TEXT_CHARACTERS,
            nullable=True,
        )
        errors.extend(text_errors)

        exit_code = raw_record.get("exitCode")
        if exit_code is not None and (
            not isinstance(exit_code, int) or isinstance(exit_code, bool)
        ):
            errors.append(f"{record_label}.exitCode 必须为整数或 null")
            exit_code = None
        if (command is None) != (exit_code is None):
            errors.append(f"{record_label}.command 与 exitCode 必须同时存在或同时为 null")

        artifacts, item_errors = _string_list(
            raw_record.get("artifacts"),
            f"{record_label}.artifacts",
        )
        errors.extend(item_errors)
        business_checks, item_errors = _string_list(
            raw_record.get("businessChecks"),
            f"{record_label}.businessChecks",
        )
        errors.extend(item_errors)

        if level in COMMAND_LEVELS and (command is None or exit_code != 0):
            errors.append(f"{record_label}：{level}必须记录命令与 exitCode=0")
        if level == "构建通过" and not artifacts:
            errors.append(f"{record_label}：构建通过必须记录至少一个产物证据")
        if level in RUNTIME_LEVELS:
            if command is None or exit_code != 0:
                errors.append(f"{record_label}：{level}必须记录命令与 exitCode=0")
            if environment is None:
                errors.append(f"{record_label}：{level}必须记录明确环境")
            if not artifacts:
                errors.append(f"{record_label}：{level}必须记录至少一个证据文件")
            if not business_checks:
                errors.append(f"{record_label}：{level}必须记录业务字段或流程检查")
        if level == "未验证":
            if notes is None:
                errors.append(f"{record_label}：未验证状态必须说明真实缺口")
            if (
                command is not None
                or exit_code is not None
                or environment is not None
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
