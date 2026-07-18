import unittest
from pathlib import Path

from scripts.test_knowledge_navigation_contract import compact, extract_method


ROOT = Path(__file__).resolve().parents[1]
LEARNING_MAP_PAGE = (
    ROOT / "apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets"
)


class LearningMapNavigationContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = LEARNING_MAP_PAGE.read_text(encoding="utf-8")

    def test_target_state_selects_lesson_or_practice(self):
        uses_practice = compact(
            extract_method(self.source, "nextActionUsesPractice")
        )

        self.assertIn("const target = this.nextActionTarget(node)", uses_practice)
        self.assertIn(
            "return target !== null && (target.lessonCompleted || target.mastery !== null)",
            uses_practice,
        )
        self.assertNotIn("target.id !== node.id", uses_practice)

        truth_table = (
            (False, False, False),
            (True, False, True),
            (False, True, True),
        )
        for lesson_completed, has_mastery, expected in truth_table:
            with self.subTest(
                lesson_completed=lesson_completed, has_mastery=has_mastery
            ):
                self.assertEqual(lesson_completed or has_mastery, expected)

    def test_cross_node_copy_matches_the_target_route(self):
        label = compact(extract_method(self.source, "nextActionLabel"))
        description = compact(
            extract_method(self.source, "nextActionDescription")
        )
        run = compact(extract_method(self.source, "runNextAction"))

        self.assertIn(
            "const relation = this.isReachableSuccessor(node, target) ? '后继主题' : '前置主题'",
            label,
        )
        self.assertIn(
            "(this.nextActionUsesPractice(node) ? '练习' : '学习') + relation",
            label,
        )
        self.assertIn(
            "const action = this.nextActionUsesPractice(node) ? '练习' : '学习'",
            description,
        )
        self.assertIn("action + '后继", description)
        self.assertIn("action + '前置", description)
        self.assertIn("const target = this.nextActionTarget(node)", run)
        practice = run.find("this.openPractice(target.topic)")
        lesson = run.find("this.openLesson(target.topic)")
        self.assertGreaterEqual(practice, 0)
        self.assertGreater(lesson, practice)


if __name__ == "__main__":
    unittest.main()
