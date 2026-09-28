#!/usr/bin/env python3
"""只读校验竞赛评分证据矩阵、初赛内容与五分钟演示时间轴。"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PLAN_PATH = ROOT / "docs" / "COMPETITION-SCORE-FIRST-PLAN.md"
PDF_SCAN_CHUNK_BYTES = 1024 * 1024
PDF_SCAN_OVERLAP_BYTES = 64
PDF_PAGE_PATTERN = re.compile(rb"/Type\s*/Page\b")
FIGURE_STATE_PATTERN = re.compile(
    r"^- 证据状态：`level=(未验证|模拟器通过|真机通过); "
    r"evidenceId=([a-z][a-z0-9-]{2,63}); "
    r"artifact=([^;`]+); gap=([^;`]+)`。$"
)
FIGURE_ARTIFACT_PREFIX = "evidence/artifacts/"
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
DISALLOWED_REMINDER_CLAIMS = (
    "系统定时主动触达",
    "系统自动定时触达",
)
DISALLOWED_REMINDER_PATTERNS = (
    re.compile(r"无需用户(?:操作)?.{0,24}(?:提醒|通知|任务|计划)"),
    re.compile(r"(?:系统|后台).{0,16}(?:自动|自主).{0,24}(?:提醒|通知|任务|计划)"),
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
TIMELINE_HEADER = ("镜头 ID", "时间", "画面与操作", "讲解重点", "通过证据")
SCORE_LABEL_PATTERN = re.compile(
    r"^(创新性|完备度|前景评估|规范性|实际应用价值) ([0-9]+)$"
)
TIME_RANGE_PATTERN = re.compile(r"^([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})$")
TIMELINE_CONTEXT_ANCHORS = (
    "同一提交",
    "同一 HAP",
    "同一测试账号状态",
    "真实线上调用",
)
DEMO_SEGMENTS = (
    (
        "D01-release-identity",
        "00:00-00:15",
        ("Git 短哈希", "HAP SHA-256", "设备", "采集时间"),
        ("一句话创新点", "未经验证"),
        ("证据登记表",),
    ),
    (
        "D02-proactive-service",
        "00:15-00:45",
        ("用户点首页铃铛即时创建系统学习提醒", "点击直达错题本", "桌面服务卡片单独取证"),
        ("用户主动触发的即时通知", "没有时间选择或定时投递", "本地计划"),
        ("最终 HAP", "同版独立证据", "权限流程"),
    ),
    (
        "D03-topic-context",
        "00:45-01:20",
        ("对应课程", "Topic"),
        ("下一步任务", "明确上下文"),
        ("UI 树", "课程 ID", "Topic 一致"),
    ),
    (
        "D04-live-chat",
        "01:20-02:25",
        ("真实等待态", "正文", "当次引用"),
        ("Profile + Evaluator + Safety", "检索课程资料", "实际出现的引用"),
        ("POST /api/chat", "SSE", "done", "实际返回校验"),
    ),
    (
        "D05-live-quiz",
        "02:25-03:35",
        ("AI 测验", "作答并提交"),
        ("Quiz Agent", "选定课程主题", "不泄露答案", "提交后再评分", "另一个主题"),
        ("Topic 一致", "评分结构", "没有静态题替换"),
    ),
    (
        "D06-arkdata-persistence",
        "03:35-04:20",
        ("本地回写", "退出并重新进入"),
        ("ArkData", "持久化", "真实结果变化"),
        ("重进后保持", "UI 和日志"),
    ),
    (
        "D07-evidence-close",
        "04:20-04:45",
        ("图 1", "端云边界", "适用人群"),
        ("真实学习闭环", "无状态云端", "端侧隐私"),
        ("逐项", "视频前段"),
    ),
)
D02_EXACT_COLUMNS = (
    "用户点首页铃铛即时创建系统学习提醒；打开系统通知栏核对通知，再点击直达错题本；桌面服务卡片单独取证",
    "当前实现是用户主动触发的即时通知，没有时间选择或定时投递；本地计划只按明确操作同步",
    "通知、点击回流来自最终 HAP；卡片只有取得同版独立证据才展示；保留权限流程与失败状态",
)


class EvidenceMetrics(NamedTuple):
    score_rows: int
    timeline_segments: int
    timeline_seconds: int
    introduction_characters: int


class OfficialPdfSource(NamedTuple):
    path: str
    sha256: str
    pages: int
    clause_anchors: tuple[str, ...]


class PdfFingerprint(NamedTuple):
    path: str
    sha256: str
    pages: int


class FigureEvidenceRequirement(NamedTuple):
    figure_id: str
    level: str
    evidence_id: str
    artifact: str | None
    gap: str | None


OFFICIAL_PDF_SOURCES = (
    OfficialPdfSource(
        '2026“中国高校计算机大赛―人工智能创意赛”鸿蒙高校创新赛竞赛规程.pdf',
        "e5093c61bed5a10c249e165095127ac1f03fd3ce5b8b993d3a8d6ae878bec1a9",
        11,
        (
            "不超过800字",
            "视频 5 分钟内完整展示核心功能",
            "创新性 50、完备度 20、前景评估 20、规范性 10；实际应用价值附加 20",
        ),
    ),
    OfficialPdfSource(
        '2026“中国高校计算机大赛―人工智能创意赛”鸿蒙赛道报名手册.pdf',
        "6034aca8f908d76debd0ea1dc606c3f594df8fe29310866f1e5ef91d170bd26e",
        12,
        (
            "作品说明 PDF、演示视频 MP4、演示 Demo/源代码 ZIP 三类材料",
            "整个上传更新流程的次数限制为10次",
        ),
    ),
)


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


def _pdf_fingerprint(source: OfficialPdfSource) -> tuple[PdfFingerprint | None, list[str]]:
    path = ROOT / source.path
    digest = hashlib.sha256()
    pages = 0
    overlap = b""
    try:
        with path.open("rb") as handle:
            while True:
                chunk = handle.read(PDF_SCAN_CHUNK_BYTES)
                if not chunk:
                    break
                digest.update(chunk)
                window = overlap + chunk
                pages += sum(
                    match.end() > len(overlap)
                    for match in PDF_PAGE_PATTERN.finditer(window)
                )
                overlap = window[-PDF_SCAN_OVERLAP_BYTES:]
    except OSError as error:
        return None, [f"官方 PDF 无法只读打开: {source.path} ({type(error).__name__})"]
    return PdfFingerprint(source.path, digest.hexdigest(), pages), []


def _tracked_official_paths() -> tuple[set[str], list[str]]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z", "--", *(source.path for source in OFFICIAL_PDF_SOURCES)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            shell=False,
        )
    except (OSError, ValueError) as error:
        return set(), [f"官方 PDF Git 跟踪状态无法读取 ({type(error).__name__})"]
    if result.returncode != 0:
        return set(), [f"官方 PDF Git 跟踪状态读取失败，exit={result.returncode}"]
    try:
        paths = {
            item.decode("utf-8") for item in result.stdout.split(b"\0") if item
        }
    except UnicodeDecodeError:
        return set(), ["官方 PDF Git 路径不是 UTF-8"]
    return paths, []


def validate_official_sources(
    content: str,
) -> tuple[list[PdfFingerprint], list[str]]:
    errors: list[str] = []
    fingerprints: list[PdfFingerprint] = []
    tracked, tracked_errors = _tracked_official_paths()
    errors.extend(tracked_errors)
    for source in OFFICIAL_PDF_SOURCES:
        fingerprint, fingerprint_errors = _pdf_fingerprint(source)
        errors.extend(fingerprint_errors)
        if source.path not in tracked:
            errors.append(f"官方 PDF 未被 Git 跟踪: {source.path}")
        if fingerprint is not None:
            fingerprints.append(fingerprint)
            if fingerprint.sha256 != source.sha256:
                errors.append(f"官方 PDF SHA-256 与固定来源不一致: {source.path}")
            if fingerprint.pages != source.pages:
                errors.append(f"官方 PDF 页数与固定来源不一致: {source.path}")
        if source.path not in content:
            errors.append(f"竞赛计划缺少官方 PDF 路径: {source.path}")
        if f"共 {source.pages} 页" not in content:
            errors.append(f"竞赛计划文档缺少精确页数: {source.path}")
        if f"SHA-256 `{source.sha256.upper()}`" not in content:
            errors.append(f"竞赛计划文档缺少精确 SHA-256: {source.path}")
        source_line = next(
            (line for line in content.splitlines() if source.path in line),
            "",
        )
        if "**源码确认**" not in source_line:
            errors.append(f"官方 PDF 来源必须标记源码确认: {source.path}")
        for anchor in source.clause_anchors:
            if anchor not in content:
                errors.append(
                    f"竞赛计划缺少可复核条款摘录: {source.path} / {anchor}"
                )
    return fingerprints, errors


def figure_evidence_requirements(
    content: str,
) -> tuple[list[FigureEvidenceRequirement], list[str]]:
    lines = content.splitlines()
    try:
        start = lines.index(FIGURE_SECTION)
        end = lines.index(TIMELINE_SECTION, start + 1)
    except ValueError:
        return [], ["无法读取两张图证据状态章节"]
    section = lines[start + 1 : end]
    headings = [
        (index, line)
        for index, line in enumerate(section)
        if line.startswith("### 图 ")
    ]
    errors: list[str] = []
    requirements: list[FigureEvidenceRequirement] = []
    if any(line.strip() == "- 当前状态：**未验证**。" for line in section):
        errors.append("两张图包含过期未验证文本，必须使用结构化证据状态")
    for heading_index, (offset, heading) in enumerate(headings):
        next_offset = (
            headings[heading_index + 1][0]
            if heading_index + 1 < len(headings)
            else len(section)
        )
        state_lines = [
            line for line in section[offset + 1 : next_offset]
            if line.startswith("- 证据状态：")
        ]
        figure_id = f"figure-{heading_index + 1}"
        if len(state_lines) != 1:
            errors.append(f"{figure_id} 必须且只能包含一个结构化证据状态")
            continue
        match = FIGURE_STATE_PATTERN.fullmatch(state_lines[0])
        if match is None:
            errors.append(f"{figure_id} 证据状态格式无效")
            continue
        level, evidence_id, artifact_value, gap_value = match.groups()
        if evidence_id != "golden-demo":
            errors.append(f"{figure_id} evidenceId 必须为 golden-demo")
        artifact = None if artifact_value == "none" else artifact_value
        gap = None if gap_value == "none" else gap_value
        if level == "未验证":
            if artifact is not None or gap is None:
                errors.append(f"{figure_id} 未验证状态必须列出缺口且不得绑定 artifact")
        else:
            if (
                artifact is None
                or not artifact.startswith(FIGURE_ARTIFACT_PREFIX)
                or Path(artifact).suffix.casefold() not in {".jpeg", ".jpg", ".png"}
                or gap is not None
            ):
                errors.append(
                    f"{figure_id} 通过状态必须绑定 evidence/artifacts 图片且 gap=none"
                )
        requirements.append(
            FigureEvidenceRequirement(
                figure_id,
                level,
                evidence_id,
                artifact,
                gap,
            )
        )
    return requirements, errors


def validate_plan(content: str) -> tuple[EvidenceMetrics, list[str]]:
    lines = content.splitlines()
    errors: list[str] = []
    _, official_source_errors = validate_official_sources(content)
    errors.extend(official_source_errors)

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
    figure_requirements, figure_requirement_errors = figure_evidence_requirements(
        content
    )
    errors.extend(figure_requirement_errors)
    if len(figure_requirements) != 2:
        errors.append(
            f"两张图必须各有可迁移证据状态，实际 {len(figure_requirements)}"
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

    timeline_text = "\n".join(timeline_section)
    missing_context_anchors = [
        anchor for anchor in TIMELINE_CONTEXT_ANCHORS if anchor not in timeline_text
    ]
    if missing_context_anchors:
        errors.append(
            "黄金演示缺少同版全链路合同: " + ",".join(missing_context_anchors)
        )

    if len(timeline_rows) != len(DEMO_SEGMENTS):
        errors.append(
            "黄金演示镜头数量必须恰好为 "
            f"{len(DEMO_SEGMENTS)}，实际 {len(timeline_rows)}"
        )

    previous_end = 0
    seen_shot_ids: set[str] = set()
    for row_index, row in enumerate(timeline_rows):
        shot_id, raw_range, operation, narration, evidence = row
        if shot_id in seen_shot_ids:
            errors.append(f"黄金演示镜头 ID 重复: {shot_id}")
        seen_shot_ids.add(shot_id)

        if row_index < len(DEMO_SEGMENTS):
            (
                expected_id,
                expected_range,
                operation_anchors,
                narration_anchors,
                evidence_anchors,
            ) = DEMO_SEGMENTS[row_index]
            if shot_id != expected_id:
                errors.append(
                    f"黄金演示第 {row_index + 1} 段镜头 ID 必须为 "
                    f"{expected_id}，实际 {shot_id}"
                )
            if raw_range != expected_range:
                errors.append(
                    f"黄金演示镜头 {expected_id} 时间必须为 "
                    f"{expected_range}，实际 {raw_range}"
                )
            for column_label, column_value, required_anchors in (
                ("画面与操作", operation, operation_anchors),
                ("讲解重点", narration, narration_anchors),
                ("通过证据", evidence, evidence_anchors),
            ):
                missing_anchors = [
                    anchor for anchor in required_anchors if anchor not in column_value
                ]
                if missing_anchors:
                    errors.append(
                        f"黄金演示镜头 {expected_id} {column_label}缺少业务证据锚点: "
                        + ",".join(missing_anchors)
                    )
            if expected_id == "D02-proactive-service" and (
                operation,
                narration,
                evidence,
            ) != D02_EXACT_COLUMNS:
                errors.append("黄金演示镜头 D02 必须使用精确手动提醒口径")

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

    expected_shot_ids = {segment[0] for segment in DEMO_SEGMENTS}
    missing_shot_ids = sorted(expected_shot_ids - seen_shot_ids)
    unexpected_shot_ids = sorted(seen_shot_ids - expected_shot_ids)
    if missing_shot_ids:
        errors.append("黄金演示缺少镜头 ID: " + ",".join(missing_shot_ids))
    if unexpected_shot_ids:
        errors.append("黄金演示包含未定义镜头 ID: " + ",".join(unexpected_shot_ids))
    if previous_end != 285:
        errors.append(f"黄金演示必须精确收束于 04:45，实际 {previous_end} 秒")

    formal_sections = "\n".join(
        [*narrative_section, *figure_section, *timeline_section]
    )
    reminder_scan_lines = [*narrative_section, *figure_section]
    for line in timeline_section:
        cells = _table_cells(line)
        if (
            cells is not None
            and len(cells) == len(TIMELINE_HEADER)
            and cells[0] == "D02-proactive-service"
            and cells[2:] == D02_EXACT_COLUMNS
        ):
            continue
        reminder_scan_lines.append(line)
    reminder_scan_sections = "\n".join(reminder_scan_lines)
    for claim in DISALLOWED_FORMAL_CLAIMS:
        if claim in formal_sections:
            errors.append(f"正式叙事仍含失实旧口径: {claim}")
    for claim in DISALLOWED_REMINDER_CLAIMS:
        if claim in formal_sections:
            errors.append(f"正式叙事仍含失实主动提醒口径: {claim}")
    if any(
        pattern.search(reminder_scan_sections)
        for pattern in DISALLOWED_REMINDER_PATTERNS
    ):
        errors.append("正式叙事仍含无需用户操作的自动提醒/任务口径")

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
