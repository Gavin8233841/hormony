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
CS101_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS101.md"
CS102_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"
CS103_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"


def load_json(path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


def find_activity(experiences, course_id, topic, activity_id):
    experience = find_unique(
        experiences,
        f"{course_id}/{topic} experience",
        lambda item: item.get("courseId") == course_id
        and item.get("topic") == topic,
    )
    return find_unique(
        experience["activities"],
        f"{activity_id} activity",
        lambda item: item.get("id") == activity_id,
    )


class LessonContentFactsTest(unittest.TestCase):
    def setUp(self):
        self.experiences = load_json(EXPERIENCES_PATH)
        self.knowledge_items = load_json(KNOWLEDGE_PATH)
        self.activity = find_activity(
            self.experiences,
            "cs101",
            "AVL树与红黑树",
            "cs101-AVL树与红黑树-2",
        )
        self.knowledge = find_unique(
            self.knowledge_items,
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
        spec = CS101_SPEC_PATH.read_text(encoding="utf-8")

        self.assertIn(
            '- F. 循环结束后将根节点重新着色为黑色，完成修复',
            spec,
        )
        self.assertIn("- **正确顺序**：C → B → E → A → D → F", spec)

    def test_journal_recovery_orders_crash_before_replay_and_reclaim(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "文件系统",
            "cs102-文件系统-2",
        )
        knowledge = find_unique(
            self.knowledge_items,
            "cs102_k28 knowledge chunk",
            lambda item: item.get("id") == "cs102_k28",
        )
        ordered_steps = [
            activity["options"][index]
            for index in activity["answerIndexes"]
        ]

        self.assertIn("元数据修改先写入日志区域再应用到实际位置", knowledge["text"])
        self.assertIn("日志已提交、尚未 checkpoint 时系统崩溃", activity["prompt"])
        self.assertEqual("B → D → E → C → A → F", activity["answer"])
        self.assertIn("系统崩溃", ordered_steps[3])
        self.assertIn("重放到磁盘实际位置", ordered_steps[4])
        self.assertIn("允许回收对应日志空间", ordered_steps[5])

        spec = CS102_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn("- **正确顺序**：B → D → E → C → A → F", spec)

    def test_udp_encapsulation_uses_protocol_specific_datagram_names(self):
        activity = find_activity(
            self.experiences,
            "cs103",
            "OSI与TCP/IP模型",
            "cs103-OSI与TCP/IP模型-2",
        )
        knowledge = find_unique(
            self.knowledge_items,
            "cs103_k03 knowledge chunk",
            lambda item: item.get("id") == "cs103_k03",
        )

        self.assertIn("添加TCP/UDP首部", knowledge["text"])
        self.assertIn("添加UDP首部", activity["content"])
        self.assertEqual(
            "Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
            activity["answer"],
        )
        self.assertNotIn("DNS使用UDP而非TCP", activity["feedback"])
        self.assertIn("同时支持UDP与TCP", activity["feedback"])
        self.assertIn("RFC 7766", activity["source"])

        spec = CS103_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn(
            "- **答案**：Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
            spec,
        )


if __name__ == "__main__":
    unittest.main()
