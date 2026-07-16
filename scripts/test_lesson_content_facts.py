import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS101.md"


def load_json(path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


class LessonContentFactsTest(unittest.TestCase):
    def setUp(self):
        experiences = load_json(EXPERIENCES_PATH)
        experience = find_unique(
            experiences,
            "cs101/AVL树与红黑树 experience",
            lambda item: item.get("courseId") == "cs101"
            and item.get("topic") == "AVL树与红黑树",
        )
        self.activity = find_unique(
            experience["activities"],
            "cs101-AVL树与红黑树-2 activity",
            lambda item: item.get("id") == "cs101-AVL树与红黑树-2",
        )
        self.knowledge = find_unique(
            load_json(KNOWLEDGE_PATH),
            "cs101_k20 knowledge chunk",
            lambda item: item.get("id") == "cs101_k20",
        )

    def test_red_black_repair_restores_black_root_after_upward_fix(self):
        root_recolor = "循环结束后将根节点重新着色为黑色，完成修复"
        ordered_steps = [
            self.activity["options"][index]
            for index in self.activity["answerIndexes"]
        ]

        self.assertIn("根为黑", self.knowledge["text"])
        self.assertEqual(root_recolor, ordered_steps[-1])
        self.assertEqual("C → B → E → A → D → F", self.activity["answer"])
        self.assertIn("违反知识切片 cs101_k20 的\"根为黑\"性质", self.activity["feedback"])

    def test_red_black_root_step_is_kept_in_the_source_spec(self):
        spec = SPEC_PATH.read_text(encoding="utf-8")

        self.assertIn(
            '- F. 循环结束后将根节点重新着色为黑色，完成修复',
            spec,
        )
        self.assertIn("- **正确顺序**：C → B → E → A → D → F", spec)


if __name__ == "__main__":
    unittest.main()
