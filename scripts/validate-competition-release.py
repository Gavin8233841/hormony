#!/usr/bin/env python3
"""只读串联竞赛源码、评分证据与正式三文件发布预检。"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
DEPENDENCY_GATE_PATH = Path(__file__).with_name("validate-release-dependencies.py")
EVIDENCE_GATE_PATH = Path(__file__).with_name("validate-competition-evidence.py")
CONTENT_GATE_PATH = Path(__file__).with_name("validate-competition-content.py")
OFFICIAL_GATE_PATH = Path(__file__).with_name("validate-official-deliverables.py")
DEFAULT_STAGE_TIMEOUT_SECONDS = 180.0
DEFAULT_TOOL_TIMEOUT_SECONDS = 20.0
DEFAULT_REPOSITORY_TIMEOUT_SECONDS = 20.0
MAX_REPOSITORY_OUTPUT_BYTES = 1024 * 1024
MAX_STAGE_SUMMARY_BYTES = 4096
GIT_COMMAND = "git"
FULL_HEAD_PATTERN = re.compile(r"^[0-9a-f]{40}$")
OFFICIAL_REASON_CODES = frozenset(
    {
        "identity.invalid",
        "pdf.input-invalid",
        "pdf.hash-failed",
        "pdf.media-invalid",
        "pdfinfo.nonzero",
        "pdfinfo.output-invalid",
        "pdfinfo.timeout",
        "pdfinfo.unavailable",
        "mp4.input-invalid",
        "mp4.hash-failed",
        "mp4.media-invalid",
        "ffprobe.nonzero",
        "ffprobe.output-invalid",
        "ffprobe.timeout",
        "ffprobe.unavailable",
        "zip.input-invalid",
        "zip.hash-failed",
        "zip.bundle-invalid",
        "internal.validation-error",
    }
)


class StageSpec(NamedTuple):
    name: str
    command: tuple[str, ...]
    invalid_inputs: tuple[str, ...]
    capture_summary: bool


class StageResult(NamedTuple):
    name: str
    status: str
    exit_code: int | None
    invalid_inputs: tuple[str, ...]
    reason_codes: tuple[str, ...]
    error_type: str | None


class RepositorySnapshot(NamedTuple):
    head: str
    dirty: bool


class RepositoryProbe(NamedTuple):
    snapshot: RepositorySnapshot | None
    status: str
    error_type: str | None


class OfficialSummary(NamedTuple):
    status: str
    reason_codes: tuple[str, ...]


def _positive_timeout(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("必须是数值") from error
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("必须是大于 0 的有限数值")
    return parsed


def _timeout_argument(value: float) -> str:
    return format(value, "g")


def _regular_file(path: Path, *, absolute: bool) -> bool:
    try:
        if absolute and not path.is_absolute():
            return False
        return not path.is_symlink() and path.is_file()
    except OSError:
        return False


def official_input_issues(args: argparse.Namespace) -> tuple[str, ...]:
    issues: list[str] = []
    for label, path in (
        ("PDF", args.pdf_path),
        ("MP4", args.video_path),
        ("ZIP", args.bundle_path),
    ):
        if not _regular_file(path, absolute=False):
            issues.append(label)
    for label, path in (
        ("pdfinfo", args.pdfinfo_path),
        ("ffprobe", args.ffprobe_path),
    ):
        if not _regular_file(path, absolute=True):
            issues.append(label)
    return tuple(issues)


def build_stage_specs(args: argparse.Namespace) -> tuple[StageSpec, ...]:
    python = sys.executable
    official_command = (
        python,
        "-B",
        str(OFFICIAL_GATE_PATH),
        "--pdf-path",
        str(args.pdf_path),
        "--video-path",
        str(args.video_path),
        "--bundle-path",
        str(args.bundle_path),
        "--team-name",
        args.team_name,
        "--work-name",
        args.work_name,
        "--pdfinfo-path",
        str(args.pdfinfo_path),
        "--ffprobe-path",
        str(args.ffprobe_path),
        "--tool-timeout-seconds",
        _timeout_argument(args.tool_timeout_seconds),
        "--summary-json",
    )
    return (
        StageSpec(
            "release-dependencies",
            (python, "-B", str(DEPENDENCY_GATE_PATH)),
            (),
            False,
        ),
        StageSpec(
            "competition-evidence",
            (python, "-B", str(EVIDENCE_GATE_PATH)),
            (),
            False,
        ),
        StageSpec(
            "competition-content",
            (
                python,
                "-B",
                str(CONTENT_GATE_PATH),
                "--require-notice-ready",
            ),
            (),
            False,
        ),
        StageSpec(
            "official-deliverables",
            official_command,
            official_input_issues(args),
            True,
        ),
    )


def _child_environment() -> dict[str, str]:
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    environment["PYTHONUTF8"] = "1"
    return environment


def read_repository_state(timeout_seconds: float) -> RepositoryProbe:
    commands = (
        [GIT_COMMAND, "rev-parse", "--verify", "HEAD"],
        [
            GIT_COMMAND,
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all",
        ],
    )
    results: list[subprocess.CompletedProcess[bytes]] = []
    try:
        for command in commands:
            results.append(
                subprocess.run(
                    command,
                    cwd=ROOT,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    timeout=timeout_seconds,
                    check=False,
                    shell=False,
                    env=_child_environment(),
                )
            )
    except subprocess.TimeoutExpired:
        return RepositoryProbe(None, "timeout", None)
    except Exception as error:  # noqa: BLE001 - never render command payloads
        return RepositoryProbe(None, "launch-error", type(error).__name__)

    if any(result.returncode != 0 for result in results):
        return RepositoryProbe(None, "failed", None)
    if any(
        not isinstance(result.stdout, bytes)
        or len(result.stdout) > MAX_REPOSITORY_OUTPUT_BYTES
        for result in results
    ):
        return RepositoryProbe(None, "invalid-output", None)
    try:
        head = results[0].stdout.decode("ascii").strip()
    except UnicodeDecodeError:
        return RepositoryProbe(None, "invalid-output", None)
    if FULL_HEAD_PATTERN.fullmatch(head) is None:
        return RepositoryProbe(None, "invalid-output", None)
    return RepositoryProbe(
        RepositorySnapshot(head, bool(results[1].stdout)),
        "ready",
        None,
    )


def _unique_json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    document: dict[str, object] = {}
    for key, value in pairs:
        if key in document:
            raise ValueError("duplicate key")
        document[key] = value
    return document


def parse_official_summary(output: object) -> OfficialSummary | None:
    if not isinstance(output, bytes) or len(output) > MAX_STAGE_SUMMARY_BYTES:
        return None
    try:
        document = json.loads(output, object_pairs_hook=_unique_json_object)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError):
        return None
    if not isinstance(document, dict) or set(document) != {"status", "reasonCodes"}:
        return None
    status = document["status"]
    reason_codes = document["reasonCodes"]
    if status not in {"passed", "failed"} or not isinstance(reason_codes, list):
        return None
    if (
        len(reason_codes) > len(OFFICIAL_REASON_CODES)
        or any(not isinstance(code, str) for code in reason_codes)
        or len(set(reason_codes)) != len(reason_codes)
        or any(code not in OFFICIAL_REASON_CODES for code in reason_codes)
        or reason_codes != sorted(reason_codes)
    ):
        return None
    normalized_codes = tuple(sorted(reason_codes))
    if (status == "passed" and normalized_codes) or (
        status == "failed" and not normalized_codes
    ):
        return None
    return OfficialSummary(status, normalized_codes)


def run_stage(stage: StageSpec, timeout_seconds: float) -> StageResult:
    if stage.invalid_inputs:
        return StageResult(stage.name, "failed", None, stage.invalid_inputs, (), None)
    try:
        completed = subprocess.run(
            list(stage.command),
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE if stage.capture_summary else subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout_seconds,
            check=False,
            shell=False,
            env=_child_environment(),
        )
    except subprocess.TimeoutExpired:
        return StageResult(stage.name, "timeout", None, (), (), None)
    except Exception as error:  # noqa: BLE001 - report launch failures without payloads
        return StageResult(
            stage.name,
            "launch-error",
            None,
            (),
            (),
            type(error).__name__,
        )
    if stage.capture_summary:
        summary = parse_official_summary(completed.stdout)
        if summary is None or (completed.returncode == 0) != (
            summary.status == "passed"
        ):
            return StageResult(
                stage.name,
                "failed",
                completed.returncode,
                (),
                ("official.report-invalid",),
                None,
            )
        return StageResult(
            stage.name,
            summary.status,
            completed.returncode,
            (),
            summary.reason_codes,
            None,
        )
    status = "passed" if completed.returncode == 0 else "failed"
    return StageResult(stage.name, status, completed.returncode, (), (), None)


def _print_stage_result(result: StageResult) -> None:
    marker = "PASS" if result.status == "passed" else "FAIL"
    details = [f"stage={result.name}", f"status={result.status}"]
    if result.exit_code is not None:
        details.append(f"exit={result.exit_code}")
    if result.invalid_inputs:
        details.append("invalidInputs=" + ",".join(result.invalid_inputs))
    if result.reason_codes:
        details.append("reasonCodes=" + ",".join(result.reason_codes))
    if result.error_type is not None:
        details.append(f"errorType={result.error_type}")
    print(f"[{marker}] " + "; ".join(details))


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
        "--stage-timeout-seconds",
        type=_positive_timeout,
        default=DEFAULT_STAGE_TIMEOUT_SECONDS,
    )
    parser.add_argument(
        "--tool-timeout-seconds",
        type=_positive_timeout,
        default=DEFAULT_TOOL_TIMEOUT_SECONDS,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repository_timeout = min(
        args.stage_timeout_seconds,
        DEFAULT_REPOSITORY_TIMEOUT_SECONDS,
    )
    before = read_repository_state(repository_timeout)
    if before.status != "ready" or before.snapshot is None:
        details = f"[FAIL] repository-state; status={before.status}"
        if before.error_type is not None:
            details += f"; errorType={before.error_type}"
        print(details)
        print("\nSOME CHECKS FAILED")
        return 1
    if before.snapshot.dirty:
        print("[FAIL] repository-state; status=dirty")
        print("\nSOME CHECKS FAILED")
        return 1
    print("[PASS] repository-state; status=clean")

    results = tuple(
        run_stage(stage, args.stage_timeout_seconds)
        for stage in build_stage_specs(args)
    )
    for result in results:
        _print_stage_result(result)

    after = read_repository_state(repository_timeout)
    repository_stable = False
    if after.status != "ready" or after.snapshot is None:
        details = f"[FAIL] repository-stability; status={after.status}"
        if after.error_type is not None:
            details += f"; errorType={after.error_type}"
        print(details)
    elif after.snapshot.dirty:
        print("[FAIL] repository-stability; status=dirty")
    elif after.snapshot.head != before.snapshot.head:
        print("[FAIL] repository-stability; status=head-changed")
    else:
        repository_stable = True
        print("[PASS] repository-stability; status=stable")

    counts = {
        status: sum(result.status == status for result in results)
        for status in ("passed", "failed", "timeout", "launch-error")
    }
    all_passed = counts["passed"] == len(results) and repository_stable
    marker = "PASS" if all_passed else "FAIL"
    print(
        f"[{marker}] 竞赛正式发布预检: "
        f"passed={counts['passed']}; failed={counts['failed']}; "
        f"timeout={counts['timeout']}; launch-error={counts['launch-error']}; "
        f"repository={'passed' if repository_stable else 'failed'}"
    )
    print(
        "证据边界: 总入口只汇总现有只读门禁；正式媒体或工具缺失即失败，"
        "静态通过不证明 HAP 安装、设备流程、完整播放或门户上传通过。"
    )
    print("\nALL CHECKS PASSED" if all_passed else "\nSOME CHECKS FAILED")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
