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


class CompetitionEvidenceGateTests(unittest.TestCase):
    def test_current_plan_has_exact_scores_initial_content_and_timeline(self) -> None:
        metrics, errors = MODULE.validate_plan(current_plan())

        self.assertEqual([], errors)
        self.assertEqual(13, metrics.score_rows)
        self.assertEqual(7, metrics.timeline_segments)
        self.assertEqual(285, metrics.timeline_seconds)
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
            "| 00:45-01:20 |",
            "| 00:46-01:20 |",
        )
        _, discontinuity_errors = MODULE.validate_plan(discontinuous)
        overlong = current_plan().replace(
            "| 04:20-04:45 |",
            "| 04:20-05:01 |",
        )
        _, duration_errors = MODULE.validate_plan(overlong)

        self.assertTrue(any("不连续" in error for error in discontinuity_errors))
        self.assertTrue(any("超过 300 秒" in error for error in duration_errors))
        self.assertTrue(any("精确收束于 04:45" in error for error in duration_errors))

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
