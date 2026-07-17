"""Executable fact contracts for CS101 sorting and dynamic-programming lessons.

The DP table used by the LCS lesson is one-based in its prefix dimensions while
the C++ strings are zero-based. Therefore state ``dp[i][j]`` must compare
``X[i-1]`` with ``Y[j-1]``. The single-character fixture below makes the
off-by-one error executable: comparing ``X[i]`` and ``Y[j]`` reads past both
strings at the first non-empty state.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS101.md"
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs101-knowledge.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)

TOPIC_PATTERN = re.compile(r"^## Topic \d+: (.+)$", re.MULTILINE)
ACTIVITY_PATTERN = re.compile(
    r"^### 主动练习 (\d+)（[^）]+）\s*$",
    re.MULTILINE,
)
FIELD_PATTERN = re.compile(r"^- \*\*([^*]+)\*\*：\s*(.*)$")


def parse_fields(section):
    fields = {}
    current = None
    for line in section.splitlines():
        match = FIELD_PATTERN.match(line)
        if match:
            current = match.group(1)
            fields[current] = [match.group(2)]
        elif current is not None:
            fields[current].append(line)
    return {key: "\n".join(value).strip() for key, value in fields.items()}


def extract_activity(source, topic, number):
    topics = list(TOPIC_PATTERN.finditer(source))
    indexes = [
        index
        for index, match in enumerate(topics)
        if match.group(1).strip() == topic
    ]
    if len(indexes) != 1:
        raise AssertionError(f"expected exactly one {topic} topic, got {len(indexes)}")

    topic_index = indexes[0]
    topic_start = topics[topic_index].start()
    topic_end = (
        topics[topic_index + 1].start()
        if topic_index + 1 < len(topics)
        else len(source)
    )
    topic_section = source[topic_start:topic_end]
    activities = list(ACTIVITY_PATTERN.finditer(topic_section))
    activity_indexes = [
        index
        for index, match in enumerate(activities)
        if int(match.group(1)) == number
    ]
    if len(activity_indexes) != 1:
        raise AssertionError(
            f"expected exactly one {topic} activity {number}, "
            f"got {len(activity_indexes)}"
        )

    activity_index = activity_indexes[0]
    activity_start = activities[activity_index].end()
    activity_end = (
        activities[activity_index + 1].start()
        if activity_index + 1 < len(activities)
        else len(topic_section)
    )
    return parse_fields(topic_section[activity_start:activity_end])


def find_json_item(items, item_id):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(f"expected one item for {item_id!r}, got {len(matches)}")
    return matches[0]


def extract_web_chunk(source, chunk_id):
    pattern = re.compile(
        r'\{\s*id: "'
        + re.escape(chunk_id)
        + r'",\s*text: ("(?:\\.|[^"\\])*")'
        + r',\s*source: ("(?:\\.|[^"\\])*")',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web knowledge chunk for {chunk_id!r}, got {len(matches)}"
        )
    text_literal, source_literal = matches[0]
    return json.loads(text_literal), json.loads(source_literal)


def prefix_index_contract_errors(text, require_prefix_definition=True):
    compact = re.sub(r"\s+", "", text)
    errors = []
    if require_prefix_definition and (
        "前i个字符" not in compact or "前j个字符" not in compact
    ):
        errors.append("state must define dp[i][j] over prefixes of lengths i and j")
    if not any(
        comparison in compact
        for comparison in ("X[i-1]==Y[j-1]", "X[i-1]=Y[j-1]")
    ):
        errors.append("a prefix state must compare zero-based X[i-1] and Y[j-1]")
    if any(
        comparison in compact
        for comparison in ("X[i]==Y[j]", "X[i]=Y[j]")
    ):
        errors.append("X[i] and Y[j] are outside one-character prefixes")
    return errors


def lcs_length_with_comparison(x, y, comparison):
    dp = [[0] * (len(y) + 1) for _ in range(len(x) + 1)]
    for i in range(1, len(x) + 1):
        for j in range(1, len(y) + 1):
            if comparison(x, y, i, j):
                dp[i][j] = dp[i - 1][j - 1] + 1
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
    return dp[-1][-1]


def compare_prefix_tail(x, y, i, j):
    return x[i - 1] == y[j - 1]


def compare_prefix_count_as_index(x, y, i, j):
    return x[i] == y[j]


class Cs101AlgorithmLessonFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = SPEC_PATH.read_text(encoding="utf-8")
        cls.dp_activity = extract_activity(spec, "动态规划", 1)

        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_json_item(chunks, "cs101_k38")
        cls.web_chunk_text, cls.web_chunk_source = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs101_k38",
        )

        quizzes = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.quiz = find_json_item(quizzes, "cs101_q48")

    def test_prefix_length_and_zero_based_index_fixtures(self):
        correct = (
            "dp[i][j] 表示 X 前 i 个字符与 Y 前 j 个字符的结果；"
            "若 X[i-1]==Y[j-1] 则沿对角线转移"
        )
        wrong = correct.replace("X[i-1]==Y[j-1]", "X[i]==Y[j]")

        self.assertEqual([], prefix_index_contract_errors(correct))
        self.assertIn(
            "X[i] and Y[j] are outside one-character prefixes",
            prefix_index_contract_errors(wrong),
        )
        self.assertEqual(
            1,
            lcs_length_with_comparison("A", "A", compare_prefix_tail),
        )
        with self.assertRaises(IndexError):
            lcs_length_with_comparison("A", "A", compare_prefix_count_as_index)

    def test_lcs_spec_knowledge_and_quiz_use_the_same_index_contract(self):
        surfaces = {
            "CS101 spec activity": (
                "\n".join(
                    (
                        self.dp_activity["题目"],
                        self.dp_activity["反馈"],
                    )
                ),
                False,
            ),
            "Web knowledge cs101_k38": (self.web_chunk_text, True),
            "raw knowledge cs101_k38": (self.raw_chunk["text"], True),
            "quiz cs101_q48": (
                "\n".join(
                    (
                        self.quiz["question"],
                        self.quiz["explanation"],
                    )
                ),
                True,
            ),
        }

        for label, (text, require_prefix_definition) in surfaces.items():
            with self.subTest(surface=label):
                self.assertEqual(
                    [],
                    prefix_index_contract_errors(text, require_prefix_definition),
                )

    def test_web_and_raw_lcs_knowledge_are_identical(self):
        self.assertEqual(self.web_chunk_text, self.raw_chunk["text"])
        self.assertEqual(self.web_chunk_source, self.raw_chunk["source"])


if __name__ == "__main__":
    unittest.main()
