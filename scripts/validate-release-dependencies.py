#!/usr/bin/env python3
"""只读校验竞赛评分、证据、发布包与正式媒体门禁的最小依赖闭包。"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path, PurePosixPath
from typing import NamedTuple


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST_PATH = ROOT / "docs" / "SUBMISSION-SOURCE-MANIFEST.md"
DEFAULT_PLAN_PATH = ROOT / "docs" / "COMPETITION-SCORE-FIRST-PLAN.md"
CONTENT_GATE_PATH = Path(__file__).with_name("validate-competition-content.py")
CONTENT_GATE_SPEC = importlib.util.spec_from_file_location(
    "validate_competition_content_for_release_dependencies",
    CONTENT_GATE_PATH,
)
if CONTENT_GATE_SPEC is None or CONTENT_GATE_SPEC.loader is None:
    raise RuntimeError(f"无法加载内容门禁: {CONTENT_GATE_PATH}")
CONTENT_GATE = importlib.util.module_from_spec(CONTENT_GATE_SPEC)
CONTENT_GATE_SPEC.loader.exec_module(CONTENT_GATE)

RUNTIME_REQUIRED_FILES = frozenset(
    {
        "docs/COMPETITION-NOTICE.md",
        "docs/COMPETITION-SCORE-FIRST-PLAN.md",
        "docs/SUBMISSION-SOURCE-MANIFEST.md",
        "scripts/validate-competition-content.py",
        "scripts/validate-competition-evidence.py",
        "scripts/validate-official-deliverables.py",
        "scripts/validate-release-bundle.py",
        "scripts/validate-release-dependencies.py",
        "scripts/validate-release-evidence.py",
    }
)
TEST_REQUIRED_FILES = frozenset(
    {
        "scripts/test_validate_competition_content.py",
        "scripts/test_validate_competition_evidence.py",
        "scripts/test_validate_official_deliverables.py",
        "scripts/test_validate_release_bundle.py",
        "scripts/test_validate_release_dependencies.py",
        "scripts/test_validate_release_evidence.py",
    }
)
AUDIT_REQUIRED_FILES = frozenset(
    {"docs/workstreams/06-competition-release-result.md"}
)
REQUIRED_DIRECT_INCLUDE_PATHS = frozenset(
    RUNTIME_REQUIRED_FILES | TEST_REQUIRED_FILES | AUDIT_REQUIRED_FILES
)
REQUIRED_APPLICATION_ROOTS = frozenset({"apps/harmonyos", "apps/web"})
DISALLOWED_DIRECT_CONTENT_DEPENDENCIES = frozenset(
    {
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
    }
)
EXPECTED_RUNTIME_EDGES = {
    (
        "scripts/validate-competition-content.py",
        "SUBMISSION_MANIFEST",
    ): "docs/SUBMISSION-SOURCE-MANIFEST.md",
    (
        "scripts/validate-competition-content.py",
        "COMPETITION_NOTICE",
    ): "docs/COMPETITION-NOTICE.md",
    (
        "scripts/validate-competition-evidence.py",
        "DEFAULT_PLAN_PATH",
    ): "docs/COMPETITION-SCORE-FIRST-PLAN.md",
    (
        "scripts/validate-release-bundle.py",
        "CONTENT_GATE_PATH",
    ): "scripts/validate-competition-content.py",
    (
        "scripts/validate-release-bundle.py",
        "EVIDENCE_GATE_PATH",
    ): "scripts/validate-release-evidence.py",
    (
        "scripts/validate-official-deliverables.py",
        "RELEASE_GATE_PATH",
    ): "scripts/validate-release-bundle.py",
}
EXPECTED_TEST_EDGES = {
    (
        "scripts/test_validate_competition_content.py",
        "SCRIPT_PATH",
    ): "scripts/validate-competition-content.py",
    (
        "scripts/test_validate_competition_evidence.py",
        "SCRIPT_PATH",
    ): "scripts/validate-competition-evidence.py",
    (
        "scripts/test_validate_release_evidence.py",
        "SCRIPT_PATH",
    ): "scripts/validate-release-evidence.py",
    (
        "scripts/test_validate_release_bundle.py",
        "SCRIPT_PATH",
    ): "scripts/validate-release-bundle.py",
    (
        "scripts/test_validate_official_deliverables.py",
        "SCRIPT_PATH",
    ): "scripts/validate-official-deliverables.py",
    (
        "scripts/test_validate_release_dependencies.py",
        "SCRIPT_PATH",
    ): "scripts/validate-release-dependencies.py",
}
REQUIRED_PLAN_COMMANDS = frozenset(
    {
        "python -B scripts/validate-competition-content.py",
        "python -B scripts/validate-competition-evidence.py",
        "python -B scripts/validate-official-deliverables.py",
        "python -B scripts/validate-release-bundle.py",
        "python -B scripts/validate-release-dependencies.py",
        "python -B scripts/validate-release-evidence.py",
    }
)
MODULE_NAMES = {
    "scripts/validate-competition-content.py": "release_dependency_content_gate",
    "scripts/validate-competition-evidence.py": "release_dependency_score_gate",
    "scripts/validate-release-bundle.py": "release_dependency_bundle_gate",
    "scripts/validate-official-deliverables.py": "release_dependency_media_gate",
    "scripts/test_validate_competition_content.py": "release_dependency_content_tests",
    "scripts/test_validate_competition_evidence.py": "release_dependency_score_tests",
    "scripts/test_validate_release_evidence.py": "release_dependency_evidence_tests",
    "scripts/test_validate_release_bundle.py": "release_dependency_bundle_tests",
    "scripts/test_validate_official_deliverables.py": "release_dependency_media_tests",
    "scripts/test_validate_release_dependencies.py": "release_dependency_closure_tests",
}


class ReleaseDependencyMetrics(NamedTuple):
    direct_files: int
    test_files: int
    runtime_edges: int
    test_edges: int
    plan_commands: int


def _load_module(relative_path: str) -> tuple[object | None, list[str]]:
    if relative_path == "scripts/validate-competition-content.py":
        return CONTENT_GATE, []
    path = ROOT / Path(*PurePosixPath(relative_path).parts)
    spec = importlib.util.spec_from_file_location(MODULE_NAMES[relative_path], path)
    if spec is None or spec.loader is None:
        return None, [f"最小依赖无法加载模块: {relative_path}"]
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as error:  # noqa: BLE001 - convert import failures to safe gate errors
        return None, [
            f"最小依赖模块导入失败: {relative_path} ({type(error).__name__})"
        ]
    return module, []


def _repository_relative(value: object) -> str | None:
    if isinstance(value, str):
        if CONTENT_GATE.invalid_relative_path_reason(value) is not None:
            return None
        return value
    if not isinstance(value, Path):
        return None
    try:
        return value.resolve().relative_to(ROOT.resolve()).as_posix()
    except (OSError, ValueError):
        return None


def _collect_path_edges(
    expected_edges: dict[tuple[str, str], str],
) -> tuple[dict[tuple[str, str], str], list[str]]:
    modules: dict[str, object] = {}
    errors: list[str] = []
    edges: dict[tuple[str, str], str] = {}
    for source_path, attribute in expected_edges:
        if source_path not in modules:
            module, module_errors = _load_module(source_path)
            errors.extend(module_errors)
            if module is None:
                continue
            modules[source_path] = module
        module = modules[source_path]
        if not hasattr(module, attribute):
            errors.append(f"最小依赖缺少运行时属性: {source_path}.{attribute}")
            continue
        relative_path = _repository_relative(getattr(module, attribute))
        if relative_path is None:
            errors.append(f"最小依赖运行时路径无效: {source_path}.{attribute}")
            continue
        edges[(source_path, attribute)] = relative_path
    return edges, errors


def collect_runtime_edges() -> tuple[dict[tuple[str, str], str], list[str]]:
    return _collect_path_edges(EXPECTED_RUNTIME_EDGES)


def collect_test_edges() -> tuple[dict[tuple[str, str], str], list[str]]:
    return _collect_path_edges(EXPECTED_TEST_EDGES)


def validate_release_dependencies(
    manifest_content: str,
    plan_content: str,
    tracked_names: set[str],
    runtime_edges: dict[tuple[str, str], str],
    test_edges: dict[tuple[str, str], str],
) -> tuple[ReleaseDependencyMetrics, list[str]]:
    include, exclude, errors = CONTENT_GATE.parse_submission_manifest(
        manifest_content
    )
    errors.extend(CONTENT_GATE.check_manifest_policy(include, exclude))
    include_set = set(include)

    missing_direct = sorted(REQUIRED_DIRECT_INCLUDE_PATHS - include_set)
    if missing_direct:
        errors.append("正式交付最小依赖未直接纳入 manifest: " + ",".join(missing_direct))
    missing_roots = sorted(REQUIRED_APPLICATION_ROOTS - include_set)
    if missing_roots:
        errors.append("正式交付最小依赖缺少应用源码根: " + ",".join(missing_roots))
    disallowed_direct = sorted(
        DISALLOWED_DIRECT_CONTENT_DEPENDENCIES & include_set
    )
    if disallowed_direct:
        errors.append(
            "正式交付不得把主线应用根内的内容文件列为独立移植依赖: "
            + ",".join(disallowed_direct)
        )

    untracked = sorted(REQUIRED_DIRECT_INCLUDE_PATHS - tracked_names)
    if untracked:
        errors.append("正式交付最小依赖未被 Git 跟踪: " + ",".join(untracked))

    for edge, expected_target in EXPECTED_RUNTIME_EDGES.items():
        source_path, attribute = edge
        actual_target = runtime_edges.get(edge)
        if actual_target is None:
            errors.append(f"正式交付缺少运行时依赖边: {source_path}.{attribute}")
        elif actual_target != expected_target:
            errors.append(
                f"正式交付运行时依赖边不一致: {source_path}.{attribute}; "
                f"expected={expected_target}; actual={actual_target}"
            )
    unexpected_edges = sorted(set(runtime_edges) - set(EXPECTED_RUNTIME_EDGES))
    if unexpected_edges:
        errors.append(
            "正式交付包含未定义运行时依赖边: "
            + ",".join(f"{source}.{attribute}" for source, attribute in unexpected_edges)
        )

    for edge, expected_target in EXPECTED_TEST_EDGES.items():
        source_path, attribute = edge
        actual_target = test_edges.get(edge)
        if actual_target is None:
            errors.append(f"正式交付缺少测试依赖边: {source_path}.{attribute}")
        elif actual_target != expected_target:
            errors.append(
                f"正式交付测试依赖边不一致: {source_path}.{attribute}; "
                f"expected={expected_target}; actual={actual_target}"
            )
    unexpected_test_edges = sorted(set(test_edges) - set(EXPECTED_TEST_EDGES))
    if unexpected_test_edges:
        errors.append(
            "正式交付包含未定义测试依赖边: "
            + ",".join(
                f"{source}.{attribute}"
                for source, attribute in unexpected_test_edges
            )
        )

    missing_commands = sorted(
        command for command in REQUIRED_PLAN_COMMANDS if command not in plan_content
    )
    if missing_commands:
        errors.append("评分计划缺少正式门禁命令: " + ",".join(missing_commands))

    metrics = ReleaseDependencyMetrics(
        direct_files=len(REQUIRED_DIRECT_INCLUDE_PATHS),
        test_files=len(TEST_REQUIRED_FILES),
        runtime_edges=len(EXPECTED_RUNTIME_EDGES),
        test_edges=len(EXPECTED_TEST_EDGES),
        plan_commands=len(REQUIRED_PLAN_COMMANDS),
    )
    return metrics, errors


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest-path",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help="源码提交 manifest；默认使用仓库当前文件",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        manifest_content = args.manifest_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        print(f"[FAIL] 最小依赖 manifest 无法按 UTF-8 读取 ({type(error).__name__})")
        return 1

    try:
        plan_content = DEFAULT_PLAN_PATH.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        print(f"[FAIL] 评分计划无法按 UTF-8 读取 ({type(error).__name__})")
        return 1

    tracked_names, tracked_errors = CONTENT_GATE.git_tracked_names()
    runtime_edges, runtime_errors = collect_runtime_edges()
    test_edges, test_errors = collect_test_edges()
    metrics, errors = validate_release_dependencies(
        manifest_content,
        plan_content,
        tracked_names,
        runtime_edges,
        test_edges,
    )
    errors = [*tracked_errors, *runtime_errors, *test_errors, *errors]
    if errors:
        print(f"[FAIL] 正式交付最小依赖门禁: {len(errors)} 项")
        for error in errors:
            print(f"  - {error}")
        print("\nSOME CHECKS FAILED")
        return 1

    print(
        "[PASS] 正式交付最小依赖门禁: "
        f"directFiles={metrics.direct_files}; testFiles={metrics.test_files}; "
        f"runtimeEdges={metrics.runtime_edges}; testEdges={metrics.test_edges}; "
        f"planCommands={metrics.plan_commands}"
    )
    print(
        "证据边界: 只证明当前 Git/manifest 依赖闭包，"
        "不证明最终媒体、HAP 安装或运行流程通过。"
    )
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
