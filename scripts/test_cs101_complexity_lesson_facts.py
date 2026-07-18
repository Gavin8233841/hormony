"""Executable operation-count contract for the CS101 AVL lesson.

Verified open-course reference:
- Virginia Tech OpenDSA, "The AVL Tree", source lines 125-130, 162-170,
  and 180-184:
  https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/_sources/AVL.rst.txt
  https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/AVL.html#avldouble
  An insertion into the right subtree of an unbalanced node's left child is
  Case 2 and is repaired by a double rotation; the symmetric right-left
  insertion is handled the same way. Counting each primitive left or right
  rotation once, LR and RL repairs therefore perform two rotations.

The insertion fixture ``30, 10, 20`` makes that boundary executable: repairing
the LR imbalance rotates left at 10 and then right at 30. Its symmetric fixture
``10, 30, 20`` rotates right at 30 and then left at 10. Calling either repair
"one primitive rotation" conflates one repair case with two local operations.
"""

import json
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS101.md"
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)
QUESTION_ID = "cs101_q41"
STRING_LITERAL = r'"(?:\\.|[^"\\])*"'


@dataclass
class AvlNode:
    key: int
    left: "AvlNode | None" = None
    right: "AvlNode | None" = None
    height: int = 1


def height(node):
    return node.height if node is not None else 0


def update_height(node):
    node.height = 1 + max(height(node.left), height(node.right))


def rotate_left(node, counter):
    child = node.right
    if child is None:
        raise AssertionError("left rotation requires a right child")
    node.right = child.left
    child.left = node
    update_height(node)
    update_height(child)
    counter[0] += 1
    return child


def rotate_right(node, counter):
    child = node.left
    if child is None:
        raise AssertionError("right rotation requires a left child")
    node.left = child.right
    child.right = node
    update_height(node)
    update_height(child)
    counter[0] += 1
    return child


def insert_avl(node, key, counter):
    if node is None:
        return AvlNode(key)
    if key < node.key:
        node.left = insert_avl(node.left, key, counter)
    elif key > node.key:
        node.right = insert_avl(node.right, key, counter)
    else:
        return node

    update_height(node)
    balance = height(node.left) - height(node.right)
    if balance > 1:
        if node.left is None:
            raise AssertionError("left-heavy node must have a left child")
        if key > node.left.key:
            node.left = rotate_left(node.left, counter)
        return rotate_right(node, counter)
    if balance < -1:
        if node.right is None:
            raise AssertionError("right-heavy node must have a right child")
        if key < node.right.key:
            node.right = rotate_right(node.right, counter)
        return rotate_left(node, counter)
    return node


def rotation_count_for_insertions(keys):
    root = None
    counter = [0]
    for key in keys:
        root = insert_avl(root, key, counter)
    return counter[0]


def extract_web_choice(source, question_id):
    pattern = re.compile(
        r'\{\s*id:\s*"'
        + re.escape(question_id)
        + r'",\s*type:\s*"choice",\s*stem:\s*('
        + STRING_LITERAL
        + r'),\s*options:\s*\[(.*?)\],\s*answer:\s*('
        + STRING_LITERAL
        + r'),\s*explanation:\s*('
        + STRING_LITERAL
        + r'),\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web choice question for {question_id!r}, got {len(matches)}"
        )
    stem_literal, options_source, answer_literal, explanation_literal = matches[0]
    return {
        "id": question_id,
        "question": json.loads(stem_literal),
        "options": [
            json.loads(value) for value in re.findall(STRING_LITERAL, options_source)
        ],
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def find_unique_by_id(items, item_id, label):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(
            f"expected one {label} for {item_id!r}, got {len(matches)}"
        )
    return matches[0]


def compact(value):
    return re.sub(r"\s+", "", value)


def selected_option(question):
    prefix = f'{question["answer"]}.'
    matches = [option for option in question["options"] if option.startswith(prefix)]
    if len(matches) != 1:
        raise AssertionError(
            f"expected one option for answer {question['answer']!r}, got {len(matches)}"
        )
    return matches[0]


def rotation_count_contract_errors(question, expected_maximum):
    prompt = compact(question["question"])
    explanation = compact(question["explanation"])
    option = compact(selected_option(question))
    errors = []

    if not (
        "基本旋转" in prompt
        and ("一次左旋或右旋计1次" in prompt or "单次左旋或右旋计1次" in prompt)
    ):
        errors.append("question must define one primitive left or right rotation as one")
    if f"{expected_maximum}次" not in option:
        errors.append(
            f"selected option must report at most {expected_maximum} primitive rotations"
        )
    affirmative_double_rotation = re.search(
        r"(?:LR/RL|LR型和RL型|LR或RL)[^，。；]*"
        r"(?:依次执行|执行|需要|包含)[^，。；]*两次基本旋转",
        explanation,
    )
    if affirmative_double_rotation is None:
        errors.append("explanation must identify LR/RL as two primitive rotations")
    if re.search(
        r"(?:LR/RL|LR型和RL型|LR或RL)[^，。；]*"
        r"(?:最多|只需|仅需)[^，。；]*一次基本旋转",
        explanation,
    ):
        errors.append("LR/RL must not be described as at most one primitive rotation")
    if "只需一次旋转（单旋或双旋）" in explanation:
        errors.append("repair-case count must not be presented as primitive rotation count")
    return errors


CORRECT_FIXTURE = {
    "question": (
        "在 AVL 树中插入一个节点导致失衡后，恢复平衡最多需要进行几次基本旋转"
        "（一次左旋或右旋计 1 次）？"
    ),
    "options": ["A. 1 次", "B. 2 次", "C. 3 次", "D. log n 次"],
    "answer": "B",
    "explanation": (
        "LL/RR 型执行一次基本旋转；LR/RL 型依次执行两个方向的两次基本旋转，"
        "所以一次 AVL 插入恢复平衡最多执行两次基本旋转。"
    ),
}

LEGACY_FIXTURE = {
    "question": "在 AVL 树中插入一个节点导致失衡后，恢复平衡最多需要进行几次旋转？",
    "options": ["A. 1 次", "B. 2 次", "C. 3 次", "D. log n 次"],
    "answer": "A",
    "explanation": (
        "AVL 树插入导致的失衡只需一次旋转（单旋或双旋）即可恢复平衡。"
        "LR 型和 RL 型失衡需一次双旋（两次旋转）。"
    ),
}

WRONG_ONE_PRIMITIVE_ROTATION_FIXTURE = {
    "question": CORRECT_FIXTURE["question"],
    "options": CORRECT_FIXTURE["options"],
    "answer": "A",
    "explanation": (
        "LL/RR 型执行一次基本旋转；LR/RL 型也最多执行一次基本旋转，"
        "所以一次 AVL 插入最多执行一次基本旋转。"
    ),
}

NEGATED_DOUBLE_ROTATION_FIXTURE = {
    "question": CORRECT_FIXTURE["question"],
    "options": CORRECT_FIXTURE["options"],
    "answer": "B",
    "explanation": (
        "LR/RL 不是两次基本旋转；错误地说每种情形都执行两次基本旋转。"
    ),
}


class Cs101ComplexityLessonFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec_source = SPEC_PATH.read_text(encoding="utf-8")
        cls.web_question = extract_web_choice(
            WEB_QUIZZES_PATH.read_text(encoding="utf-8"),
            QUESTION_ID,
        )
        cls.raw_question = find_unique_by_id(
            json.loads(QUIZZES_PATH.read_text(encoding="utf-8")),
            QUESTION_ID,
            "raw quiz question",
        )
        experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))
        matching_experiences = [
            item
            for item in experiences
            if item.get("courseId") == "cs101"
            and item.get("topic") == "AVL树与红黑树"
        ]
        if len(matching_experiences) != 1:
            raise AssertionError(
                "expected one cs101/AVL树与红黑树 lesson experience, "
                f"got {len(matching_experiences)}"
            )
        cls.avl_activity = find_unique_by_id(
            matching_experiences[0].get("activities", []),
            "cs101-AVL树与红黑树-1",
            "generated lesson activity",
        )

    def test_three_key_fixtures_count_all_avl_insertion_cases(self):
        expected_counts = {
            (10, 20, 30): 1,
            (10, 30, 20): 2,
            (20, 10, 30): 0,
            (20, 30, 10): 0,
            (30, 10, 20): 2,
            (30, 20, 10): 1,
        }
        for keys, expected in expected_counts.items():
            with self.subTest(keys=keys):
                self.assertEqual(expected, rotation_count_for_insertions(keys))

        self.assertEqual(
            [],
            rotation_count_contract_errors(CORRECT_FIXTURE, expected_maximum=2),
        )

        wrong_errors = rotation_count_contract_errors(
            WRONG_ONE_PRIMITIVE_ROTATION_FIXTURE,
            expected_maximum=2,
        )
        self.assertIn(
            "selected option must report at most 2 primitive rotations",
            wrong_errors,
        )
        self.assertIn(
            "explanation must identify LR/RL as two primitive rotations",
            wrong_errors,
        )
        self.assertIn(
            "LR/RL must not be described as at most one primitive rotation",
            wrong_errors,
        )

        legacy_errors = rotation_count_contract_errors(
            LEGACY_FIXTURE,
            expected_maximum=2,
        )
        self.assertIn(
            "repair-case count must not be presented as primitive rotation count",
            legacy_errors,
        )

        negated_errors = rotation_count_contract_errors(
            NEGATED_DOUBLE_ROTATION_FIXTURE,
            expected_maximum=2,
        )
        self.assertIn(
            "explanation must identify LR/RL as two primitive rotations",
            negated_errors,
        )

    def test_web_source_and_generated_question_are_identical(self):
        raw_projection = {
            "id": self.raw_question["id"],
            "question": self.raw_question["question"],
            "options": self.raw_question["options"],
            "answer": self.raw_question["answer"],
            "explanation": self.raw_question["explanation"],
        }
        self.assertEqual(self.web_question, raw_projection)

    def test_spec_and_generated_lesson_already_execute_two_rotations(self):
        spec = compact(self.spec_source)
        generated = compact(
            f'{self.avl_activity["answer"]}\n{self.avl_activity["feedback"]}'
        )
        for surface in (spec, generated):
            with self.subTest(surface="spec" if surface == spec else "generated"):
                self.assertIn("对60右旋", surface)
                self.assertIn("对50左旋", surface)

    def test_live_question_counts_primitive_rotations(self):
        self.assertEqual(
            [],
            rotation_count_contract_errors(
                self.web_question,
                expected_maximum=rotation_count_for_insertions([30, 10, 20]),
            ),
        )


if __name__ == "__main__":
    unittest.main()
