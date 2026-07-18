import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("validate-competition-evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "validate_competition_evidence",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def current_plan() -> str:
    return MODULE.DEFAULT_PLAN_PATH.read_text(encoding="utf-8")


def replace_blockquote(content: str, heading: str, replacement: str) -> str:
    lines = content.splitlines()
    heading_index = lines.index(heading)
    quote_index = next(
        index
        for index in range(heading_index + 1, len(lines))
        if lines[index].startswith("> ")
    )
    lines[quote_index] = f"> {replacement}"
    return "\n".join(lines)


def replace_timeline_row(
    content: str,
    shot_id: str,
    replacement_cells: tuple[str, str, str, str, str],
) -> str:
    lines = content.splitlines()
    prefix = f"| {shot_id} |"
    row_index = next(
        index for index, line in enumerate(lines) if line.startswith(prefix)
    )
    lines[row_index] = "| " + " | ".join(replacement_cells) + " |"
    return "\n".join(lines)


def remove_timeline_anchor(content: str, shot_id: str, anchor: str) -> str:
    lines = content.splitlines()
    prefix = f"| {shot_id} |"
    row_index = next(
        index for index, line in enumerate(lines) if line.startswith(prefix)
    )
    if anchor not in lines[row_index]:
        raise AssertionError(f"timeline anchor is absent: {shot_id}/{anchor}")
    lines[row_index] = lines[row_index].replace(anchor, "占位")
    return "\n".join(lines)


class CompetitionEvidenceGateTests(unittest.TestCase):
    def test_current_plan_has_exact_scores_initial_content_and_timeline(self) -> None:
        metrics, errors = MODULE.validate_plan(current_plan())

        self.assertEqual([], errors)
        self.assertEqual(13, metrics.score_rows)
        self.assertEqual(7, metrics.timeline_segments)
        self.assertEqual(285, metrics.timeline_seconds)
        self.assertEqual(7, len(MODULE.DEMO_SEGMENTS))
        self.assertGreater(metrics.introduction_characters, 0)
        self.assertLessEqual(metrics.introduction_characters, 800)
        self.assertEqual(120, sum(MODULE.OFFICIAL_SCORE_WEIGHTS.values()))

    def test_score_dimensions_weights_and_evidence_levels_are_exact(self) -> None:
        wrong_weight = current_plan().replace("| 创新性 50 |", "| 创新性 49 |")
        _, weight_errors = MODULE.validate_plan(wrong_weight)
        wrong_level = current_plan().replace(
            "| **源码确认** |",
            "| **已通过** |",
            1,
        )
        _, level_errors = MODULE.validate_plan(wrong_level)

        self.assertTrue(any("创新性 分值必须为 50" in error for error in weight_errors))
        self.assertTrue(any("证据等级无效" in error for error in level_errors))

    def test_timeline_must_be_contiguous_and_end_at_four_forty_five(self) -> None:
        discontinuous = current_plan().replace(
            "| D03-topic-context | 00:45-01:20 |",
            "| D03-topic-context | 00:46-01:20 |",
        )
        _, discontinuity_errors = MODULE.validate_plan(discontinuous)
        overlong = current_plan().replace(
            "| D07-evidence-close | 04:20-04:45 |",
            "| D07-evidence-close | 04:20-05:01 |",
        )
        _, duration_errors = MODULE.validate_plan(overlong)

        self.assertTrue(any("不连续" in error for error in discontinuity_errors))
        self.assertTrue(any("超过 300 秒" in error for error in duration_errors))
        self.assertTrue(any("精确收束于 04:45" in error for error in duration_errors))

    def test_timeline_requires_stable_ids_and_business_evidence_anchors(self) -> None:
        generic_chat = replace_timeline_row(
            current_plan(),
            "D04-live-chat",
            (
                "D04-live-chat",
                "01:20-02:25",
                "占位操作",
                "占位讲解",
                "占位证据",
            ),
        )
        _, generic_errors = MODULE.validate_plan(generic_chat)
        duplicate_id = current_plan().replace(
            "| D04-live-chat |",
            "| D03-topic-context |",
            1,
        )
        _, id_errors = MODULE.validate_plan(duplicate_id)

        self.assertTrue(
            any("D04-live-chat 画面与操作缺少业务证据锚点" in error for error in generic_errors)
        )
        self.assertTrue(any("镜头 ID 重复" in error for error in id_errors))
        self.assertTrue(any("缺少镜头 ID: D04-live-chat" in error for error in id_errors))

        for segment in MODULE.DEMO_SEGMENTS:
            shot_id = segment[0]
            for required_anchors in segment[2:]:
                for anchor in required_anchors:
                    with self.subTest(shot_id=shot_id, anchor=anchor):
                        without_anchor = remove_timeline_anchor(
                            current_plan(),
                            shot_id,
                            anchor,
                        )
                        _, anchor_errors = MODULE.validate_plan(without_anchor)
                        self.assertTrue(
                            any(
                                shot_id in error
                                and "缺少业务证据锚点" in error
                                and anchor in error
                                for error in anchor_errors
                            )
                        )

        misplaced_anchors = replace_timeline_row(
            current_plan(),
            "D04-live-chat",
            (
                "D04-live-chat",
                "01:20-02:25",
                "占位操作",
                "真实等待态 SSE 正文 当次引用 "
                "Profile + Retrieval + Tutor + Safety 实际出现的引用 "
                "POST /api/chat SSE done 实际返回校验",
                "占位证据",
            ),
        )
        _, misplaced_errors = MODULE.validate_plan(misplaced_anchors)
        self.assertTrue(
            any("画面与操作缺少业务证据锚点" in error for error in misplaced_errors)
        )
        self.assertTrue(
            any("通过证据缺少业务证据锚点" in error for error in misplaced_errors)
        )

    def test_timeline_requires_one_commit_hap_account_and_live_calls(self) -> None:
        inconsistent = current_plan().replace(
            "所有步骤使用同一提交、同一 HAP 和同一测试账号状态；模型输出来自真实线上调用。",
            "各步骤使用不同提交、不同 HAP 和不同账号；模型输出来自历史缓存。",
        )

        _, errors = MODULE.validate_plan(inconsistent)
        output = "\n".join(errors)

        self.assertIn("黄金演示缺少同版全链路合同", output)
        for anchor in MODULE.TIMELINE_CONTEXT_ANCHORS:
            self.assertIn(anchor, output)

    def test_introduction_is_limited_to_800_unicode_characters(self) -> None:
        overlong = replace_blockquote(
            current_plan(),
            "### 2. 800 字以内项目介绍草案",
            "学" * 801,
        )

        metrics, errors = MODULE.validate_plan(overlong)

        self.assertEqual(801, metrics.introduction_characters)
        self.assertTrue(any("超过 800 个 Unicode 字符" in error for error in errors))

    def test_two_figure_sections_and_unverified_states_are_required(self) -> None:
        missing_figure = current_plan().replace("### 图 2：", "### 第二幅图：", 1)
        _, errors = MODULE.validate_plan(missing_figure)

        self.assertTrue(any("必须包含 2 张图" in error for error in errors))
        self.assertTrue(any("缺少图 2" in error for error in errors))

    def test_figure_state_can_migrate_only_with_bound_evidence(self) -> None:
        unverified = (
            "- 证据状态：`level=未验证; evidenceId=golden-demo; "
            "artifact=none; gap=需在最终 HAP 和固定设备环境采集`。"
        )
        passed = (
            "- 证据状态：`level=模拟器通过; evidenceId=golden-demo; "
            "artifact=evidence/artifacts/figure-1.png; gap=none`。"
        )
        self.assertIn(unverified, current_plan())

        transitioned = current_plan().replace(unverified, passed, 1)
        _, transitioned_errors = MODULE.validate_plan(transitioned)
        self.assertEqual([], transitioned_errors)

        missing_artifact = transitioned.replace(
            "artifact=evidence/artifacts/figure-1.png",
            "artifact=none",
            1,
        )
        _, artifact_errors = MODULE.validate_plan(missing_artifact)
        self.assertTrue(any("通过状态必须绑定" in error for error in artifact_errors))

        stale = transitioned.replace(
            passed,
            passed + "\n- 当前状态：**未验证**。",
            1,
        )
        _, stale_errors = MODULE.validate_plan(stale)
        self.assertTrue(any("过期未验证文本" in error for error in stale_errors))

        missing_gap = current_plan().replace(
            "gap=需在最终 HAP 和固定设备环境采集",
            "gap=none",
            1,
        )
        _, gap_errors = MODULE.validate_plan(missing_gap)
        self.assertTrue(any("未验证状态必须列出缺口" in error for error in gap_errors))

    def test_d02_requires_user_created_reminder_and_card_sync(self) -> None:
        plan = current_plan()
        d02_line = next(
            line for line in plan.splitlines() if line.startswith("| D02-proactive-service |")
        )
        self.assertIn("用户手动创建系统学习提醒", d02_line)
        self.assertIn("同步服务卡片", d02_line)

        false_claim = plan.replace(
            d02_line,
            d02_line.replace(
                "用户手动创建系统学习提醒",
                "系统定时主动触达",
                1,
            ),
            1,
        )
        _, errors = MODULE.validate_plan(false_claim)
        self.assertTrue(any("D02" in error and "业务证据锚点" in error for error in errors))
        self.assertTrue(any("失实主动提醒口径" in error for error in errors))

        semantic_bypass = plan.replace(
            "本地计划只按明确操作同步，不扩写为后台自主服务",
            "本地计划只按明确操作同步，不扩写为后台自主服务；"
            "系统无需用户操作自主安排新的学习任务",
            1,
        )
        _, bypass_errors = MODULE.validate_plan(semantic_bypass)
        self.assertTrue(
            any("D02" in error and "精确手动提醒口径" in error for error in bypass_errors)
        )

        moved_bypass = replace_blockquote(
            plan,
            "### 1. 一句话创新点",
            "鸿学伴串联真实学习闭环，系统无需用户操作自主安排新的学习任务。",
        )
        _, moved_errors = MODULE.validate_plan(moved_bypass)
        self.assertTrue(any("无需用户操作" in error for error in moved_errors))

    def test_official_pdf_fingerprints_pages_and_clause_sources_are_bound(self) -> None:
        sources, errors = MODULE.validate_official_sources(current_plan())
        self.assertEqual([], errors)
        self.assertEqual(2, len(sources))
        self.assertEqual({11, 12}, {source.pages for source in sources})

        first = MODULE.OFFICIAL_PDF_SOURCES[0]
        wrong_hash = current_plan().replace(first.sha256.upper(), "0" * 64, 1)
        _, hash_errors = MODULE.validate_plan(wrong_hash)
        self.assertTrue(any("文档缺少精确 SHA-256" in error for error in hash_errors))

        wrong_pages = current_plan().replace("共 11 页", "共 10 页", 1)
        _, page_errors = MODULE.validate_plan(wrong_pages)
        self.assertTrue(any("文档缺少精确页数" in error for error in page_errors))

        missing_clause = current_plan().replace(
            "视频 5 分钟内完整展示核心功能",
            "视频需展示核心功能",
            1,
        )
        _, clause_errors = MODULE.validate_plan(missing_clause)
        self.assertTrue(any("缺少可复核条款摘录" in error for error in clause_errors))

    def test_disallowed_old_claims_fail_only_when_used_in_formal_narrative(self) -> None:
        plan = current_plan()
        _, baseline_errors = MODULE.validate_plan(plan)
        injected = replace_blockquote(
            plan,
            "### 1. 一句话创新点",
            "所有 AI 输出都有引用",
        )
        _, injected_errors = MODULE.validate_plan(injected)

        self.assertEqual([], baseline_errors)
        self.assertTrue(any("失实旧口径" in error for error in injected_errors))


if __name__ == "__main__":
    unittest.main()
