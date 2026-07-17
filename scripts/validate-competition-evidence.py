#!/usr/bin/env python3
"""只读校验竞赛评分证据矩阵、初赛内容与五分钟演示时间轴。"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NamedTuple


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PLAN_PATH = ROOT / "docs" / "COMPETITION-SCORE-FIRST-PLAN.md"
OFFICIAL_SCORE_WEIGHTS = {
    "创新性": 50,
    "完备度": 20,
    "前景评估": 20,
    "规范性": 10,
    "实际应用价值": 20,
}
EVIDENCE_LEVELS = frozenset(
    {
        "**源码确认**",
        "**静态诊断通过**",
        "**构建通过**",
        "**模拟器通过**",
        "**真机通过**",
        "**线上通过**",
        "**未验证**",
    }
)
DISALLOWED_FORMAL_CLAIMS = (
    "总题库 60 题",
    "78/78",
    "答案 100% 正确",
    "所有 AI 输出都有引用",
)
SCORE_SECTION = "## 四、50/20/20/10 + 应用价值 20 证据矩阵"
NARRATIVE_SECTION = "## 五、产品叙事"
FIGURE_SECTION = "## 六、两张真实效果图/流程图"
TIMELINE_SECTION = "## 七、黄金 5 分钟演示路径"
PDF_SECTION = "## 八、20 页内作品说明 PDF"
SCORE_HEADER = (
    "官方评分项",
    "鸿学伴提交主张",
    "当前证据",
    "证据等级",
    "发布验收",
)
TIMELINE_HEADER = ("时间", "画面与操作", "讲解重点", "通过证据")
SCORE_LABEL_PATTERN = re.compile(
    r"^(创新性|完备度|前景评估|规范性|实际应用价值) ([0-9]+)$"
)
TIME_RANGE_PATTERN = re.compile(r"^([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})$")


class EvidenceMetrics(NamedTuple):
    score_rows: int
    timeline_segments: int
    timeline_seconds: int
    introduction_characters: int


def _section(lines: list[str], start: str, end: str) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    try:
        start_index = lines.index(start)
    except ValueError:
        return [], [f"缺少精确章节标题: {start}"]
    try:
        end_index = lines.index(end, start_index + 1)
    except ValueError:
        return [], [f"缺少精确章节标题: {end}"]
    if end_index <= start_index + 1:
        errors.append(f"章节为空: {start}")
    return lines[start_index + 1 : end_index], errors


def _table_cells(line: str) -> tuple[str, ...] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None
    return tuple(cell.strip() for cell in stripped[1:-1].split("|"))


def _table_rows(
    section: list[str],
    expected_header: tuple[str, ...],
    label: str,
) -> tuple[list[tuple[str, ...]], list[str]]:
    errors: list[str] = []
    header_index: int | None = None
    for index, line in enumerate(section):
        if _table_cells(line) == expected_header:
            header_index = index
            break
    if header_index is None:
        return [], [f"{label}缺少精确表头"]
    if header_index + 1 >= len(section):
        return [], [f"{label}缺少 Markdown 分隔行"]

    separator = _table_cells(section[header_index + 1])
    if separator is None or len(separator) != len(expected_header) or any(
        re.fullmatch(r":?-{3,}:?", cell) is None for cell in separator
    ):
        errors.append(f"{label} Markdown 分隔行无效")

    rows: list[tuple[str, ...]] = []
    for line in section[header_index + 2 :]:
        cells = _table_cells(line)
        if cells is None:
            if rows:
                break
            continue
        if len(cells) != len(expected_header):
            errors.append(f"{label}数据行列数必须为 {len(expected_header)}")
            continue
        rows.append(cells)
    if not rows:
        errors.append(f"{label}不得为空")
    return rows, errors


def _blockquote(section: list[str], label: str) -> tuple[str, list[str]]:
    quotes = [line[2:].strip() for line in section if line.startswith("> ")]
    if len(quotes) != 1 or not quotes[0]:
        return "", [f"{label}必须且只能包含一段非空 Markdown 引用正文"]
    return quotes[0], []


def _seconds(minutes: str, seconds: str) -> int | None:
    parsed_seconds = int(seconds)
    if parsed_seconds >= 60:
        return None
    return int(minutes) * 60 + parsed_seconds


def validate_plan(content: str) -> tuple[EvidenceMetrics, list[str]]:
    lines = content.splitlines()
    errors: list[str] = []

    score_section, section_errors = _section(
        lines,
        SCORE_SECTION,
        NARRATIVE_SECTION,
    )
    errors.extend(section_errors)
    score_rows, table_errors = _table_rows(
        score_section,
        SCORE_HEADER,
        "评分证据矩阵",
    )
    errors.extend(table_errors)

    seen_dimensions: set[str] = set()
    seen_claims: set[tuple[str, str]] = set()
    for row_index, row in enumerate(score_rows):
        score_label, claim, current_evidence, evidence_level, release_check = row
        match = SCORE_LABEL_PATTERN.fullmatch(score_label)
        if match is None:
            errors.append(f"评分证据矩阵第 {row_index + 1} 行评分项格式无效")
        else:
            dimension = match.group(1)
            weight = int(match.group(2))
            expected_weight = OFFICIAL_SCORE_WEIGHTS[dimension]
            if weight != expected_weight:
                errors.append(
                    f"评分项 {dimension} 分值必须为 {expected_weight}，实际 {weight}"
                )
            seen_dimensions.add(dimension)
            claim_key = (dimension, claim)
            if claim_key in seen_claims:
                errors.append(f"评分项 {dimension} 包含重复提交主张")
            seen_claims.add(claim_key)
        if not claim or not current_evidence or not release_check:
            errors.append(f"评分证据矩阵第 {row_index + 1} 行存在空字段")
        if evidence_level not in EVIDENCE_LEVELS:
            errors.append(
                f"评分证据矩阵第 {row_index + 1} 行证据等级无效: {evidence_level}"
            )

    missing_dimensions = sorted(set(OFFICIAL_SCORE_WEIGHTS) - seen_dimensions)
    if missing_dimensions:
        errors.append("评分证据矩阵缺少官方维度: " + ",".join(missing_dimensions))
    if sum(OFFICIAL_SCORE_WEIGHTS.values()) != 120:
        errors.append("内部评分权重常量总和必须为基础 100 + 附加 20")

    narrative_section, section_errors = _section(
        lines,
        NARRATIVE_SECTION,
        FIGURE_SECTION,
    )
    errors.extend(section_errors)
    one_line_section, one_line_errors = _section(
        narrative_section,
        "### 1. 一句话创新点",
        "### 2. 800 字以内项目介绍草案",
    )
    errors.extend(one_line_errors)
    introduction_section = []
    try:
        intro_start = narrative_section.index("### 2. 800 字以内项目介绍草案")
        introduction_section = narrative_section[intro_start + 1 :]
    except ValueError:
        errors.append("缺少 800 字以内项目介绍草案章节")

    one_line, quote_errors = _blockquote(one_line_section, "一句话创新点")
    errors.extend(quote_errors)
    introduction, quote_errors = _blockquote(
        introduction_section,
        "800 字以内项目介绍",
    )
    errors.extend(quote_errors)
    if len(introduction) > 800:
        errors.append(f"项目介绍超过 800 个 Unicode 字符，实际 {len(introduction)}")

    figure_section, section_errors = _section(
        lines,
        FIGURE_SECTION,
        TIMELINE_SECTION,
    )
    errors.extend(section_errors)
    figure_headings = [line for line in figure_section if line.startswith("### 图 ")]
    if len(figure_headings) != 2:
        errors.append(f"严格交付口径必须包含 2 张图，实际 {len(figure_headings)}")
    if not any(line.startswith("### 图 1：") for line in figure_headings):
        errors.append("缺少图 1 的精确小节")
    if not any(line.startswith("### 图 2：") for line in figure_headings):
        errors.append("缺少图 2 的精确小节")
    unverified_figure_states = sum(
        line.strip() == "- 当前状态：**未验证**。" for line in figure_section
    )
    if unverified_figure_states != 2:
        errors.append(
            "两张图在真实证据采集前必须分别标记未验证，"
            f"实际 {unverified_figure_states}"
        )

    timeline_section, section_errors = _section(
        lines,
        TIMELINE_SECTION,
        PDF_SECTION,
    )
    errors.extend(section_errors)
    timeline_rows, table_errors = _table_rows(
        timeline_section,
        TIMELINE_HEADER,
        "黄金演示时间轴",
    )
    errors.extend(table_errors)

    previous_end = 0
    for row_index, row in enumerate(timeline_rows):
        raw_range, operation, narration, evidence = row
        match = TIME_RANGE_PATTERN.fullmatch(raw_range)
        if match is None:
            errors.append(f"黄金演示第 {row_index + 1} 段时间格式无效")
            continue
        start = _seconds(match.group(1), match.group(2))
        end = _seconds(match.group(3), match.group(4))
        if start is None or end is None or end <= start:
            errors.append(f"黄金演示第 {row_index + 1} 段时间范围无效")
            continue
        if start != previous_end:
            errors.append(
                f"黄金演示第 {row_index + 1} 段不连续: "
                f"expected={previous_end}, actual={start}"
            )
        if end > 300:
            errors.append(f"黄金演示第 {row_index + 1} 段超过 300 秒硬上限")
        previous_end = end
        if not operation or not narration or not evidence:
            errors.append(f"黄金演示第 {row_index + 1} 段存在空字段")
    if previous_end != 285:
        errors.append(f"黄金演示必须精确收束于 04:45，实际 {previous_end} 秒")

    formal_sections = "\n".join(
        [*narrative_section, *figure_section, *timeline_section]
    )
    for claim in DISALLOWED_FORMAL_CLAIMS:
        if claim in formal_sections:
            errors.append(f"正式叙事仍含失实旧口径: {claim}")

    return (
        EvidenceMetrics(
            score_rows=len(score_rows),
            timeline_segments=len(timeline_rows),
            timeline_seconds=previous_end,
            introduction_characters=len(introduction),
        ),
        errors,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--plan-path",
        type=Path,
        default=DEFAULT_PLAN_PATH,
        help="评分与正式交付 Markdown；默认使用仓库当前计划",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        content = args.plan_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        print(f"[FAIL] 评分证据计划无法按 UTF-8 读取 ({type(error).__name__})")
        return 1

    metrics, errors = validate_plan(content)
    if errors:
        print(f"[FAIL] 竞赛评分与演示门禁: {len(errors)} 项")
        for error in errors:
            print(f"  - {error}")
        print("\nSOME CHECKS FAILED")
        return 1

    print(
        "[PASS] 竞赛评分与演示门禁: "
        f"scoreRows={metrics.score_rows}; "
        f"timelineSegments={metrics.timeline_segments}; "
        f"timelineSeconds={metrics.timeline_seconds}; "
        f"introductionCharacters={metrics.introduction_characters}"
    )
    print("证据边界: 只证明文档结构与口径一致，不证明未采集的运行证据已通过。")
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
