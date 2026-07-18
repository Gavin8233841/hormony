"""Executable facts for the CS101 quadratic-probing quiz.

Verified open-course reference:
- Virginia Tech OpenDSA, "Improved Collision Resolution", section
  "Quadratic Probing", source lines 216-231 and 252-285:
  https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/_sources/HashCImproved.rst.txt
  The simple probe function is (h(K) + i^2) mod M. Its sequence typically
  does not visit every slot. With prime M it visits at least half the slots;
  a different pairing, power-of-two M with (i^2 + i)/2, visits every slot.

For M=7, which is a 4k+3 prime, the one-sided i^2 sequence visits only
offsets {0, 1, 2, 4}. It therefore disproves the legacy explanation that a
4k+3 prime makes this specific probe sequence visit every table position.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
RAW_QUIZZES_PATH = (
    ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)
QUESTION_ID = "cs101_q53"
STRING_LITERAL = r'"(?:\\.|[^"\\])*"'


def compact(value):
    return re.sub(r"\s+", "", value)


def find_unique(items, item_id):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(f"expected one item for {item_id!r}, got {len(matches)}")
    return matches[0]


def quiz_content(question):
    return {
        key: question[key]
        for key in ("id", "question", "options", "answer", "explanation")
    }


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
            json.loads(option) for option in re.findall(STRING_LITERAL, options_source)
        ],
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def answered_option(question):
    prefix = f'{question.get("answer", "")}.'
    matches = [
        option for option in question.get("options", []) if option.startswith(prefix)
    ]
    if len(matches) != 1:
        return ""
    return matches[0]


def one_sided_quadratic_probe(home, table_size, attempts):
    if table_size <= 0:
        raise ValueError("table_size must be positive")
    return [
        (home + attempt * attempt) % table_size for attempt in range(attempts)
    ]


def quadratic_probe_contract_errors(question):
    stem = compact(question.get("question", ""))
    selected = compact(answered_option(question))
    explanation = compact(question.get("explanation", ""))
    errors = []

    if not all(
        term in stem
        for term in ("单侧二次探测", "H_i=(H(key)+i²)modM", "M=7", "H(key)=0", "i=0至6")
    ):
        errors.append("question must define the fixed one-sided M=7 probe input")
    if "{0,1,2,4}" not in selected:
        errors.append("selected option must contain the four reachable M=7 slots")
    if "0→1→4→2→2→4→1" not in explanation:
        errors.append("explanation must execute all seven probe attempts")

    prime_half_clause = re.search(
        r"(?:表长|M)[^，。；]*质数[^。；]*至少[^。；]*(?:一半|半数)",
        explanation,
    )
    if prime_half_clause is None:
        errors.append("prime table guarantee must be limited to at least half the slots")

    one_sided_not_all = re.search(
        r"(?:单侧|上述|i²)[^。；]*(?:不能保证|不保证)[^。；]*(?:所有|全部)"
        r"(?:表位置|槽位|位置)",
        explanation,
    )
    if one_sided_not_all is None:
        errors.append("one-sided +i^2 must not claim full-table coverage")

    if not all(term in explanation for term in ("2的幂", "(i²+i)/2", "全覆盖")):
        errors.append("full coverage must be scoped to a different proven pairing")

    if re.search(
        r"4k\+3型?质数[^。；]*(?:保证|遍历)[^。；]*(?:所有|全部)"
        r"(?:表位置|槽位|位置)",
        explanation,
    ):
        errors.append("a 4k+3 prime does not make one-sided +i^2 visit every slot")
    return errors


CORRECT_FIXTURE = {
    "id": QUESTION_ID,
    "question": (
        "采用单侧二次探测 H_i=(H(key)+i²) mod M。若 M=7、H(key)=0，"
        "i=0 至 6 会访问哪些不同槽位？"
    ),
    "options": [
        "A. {0, 1, 2, 3, 4, 5, 6}",
        "B. {0, 1, 2, 4}",
        "C. {0, 1, 3, 6}",
        "D. {0, 1, 4}",
    ],
    "answer": "B",
    "explanation": (
        "位置序列为 0→1→4→2→2→4→1，所以不同槽位是 {0,1,2,4}。"
        "本题采用单侧 +i²；表长 M 为质数时，该序列至少访问一半槽位，"
        "但上述单侧 i² 序列不能保证遍历所有槽位。要保证全覆盖，可使用"
        "表长为 2 的幂且偏移为 (i²+i)/2 的另一组合。"
    ),
}

LEGACY_FIXTURE = {
    "id": QUESTION_ID,
    "question": "开放地址法中，二次探测法的探测序列为？",
    "options": [
        "A. H(key), H(key)+1, H(key)+2, ...",
        "B. H(key), H(key)+1², H(key)+2², ...",
        "C. H(key), H(key)-1, H(key)-2, ...",
        "D. H(key), H(key)×2, H(key)×3, ...",
    ],
    "answer": "B",
    "explanation": (
        "二次探测不能保证遍历所有表位置，当表长为 4k+3 型质数时"
        "才能保证探测到所有位置。"
    ),
}


class Cs101QuadraticProbingQuizFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_question = extract_web_choice(
            WEB_QUIZZES_PATH.read_text(encoding="utf-8"),
            QUESTION_ID,
        )
        raw_questions = json.loads(RAW_QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.raw_question = find_unique(raw_questions, QUESTION_ID)

    def test_four_k_plus_three_prime_does_not_cover_the_table(self):
        visited = one_sided_quadratic_probe(home=0, table_size=7, attempts=7)
        self.assertEqual([0, 1, 4, 2, 2, 4, 1], visited)
        self.assertEqual({0, 1, 2, 4}, set(visited))
        self.assertEqual({3, 5, 6}, set(range(7)) - set(visited))

    def test_correct_boundary_is_green_and_legacy_claim_is_rejected(self):
        self.assertEqual([], quadratic_probe_contract_errors(CORRECT_FIXTURE))
        legacy_errors = quadratic_probe_contract_errors(LEGACY_FIXTURE)
        self.assertIn(
            "question must define the fixed one-sided M=7 probe input",
            legacy_errors,
        )
        self.assertIn(
            "selected option must contain the four reachable M=7 slots",
            legacy_errors,
        )
        self.assertIn(
            "explanation must execute all seven probe attempts",
            legacy_errors,
        )
        self.assertIn(
            "prime table guarantee must be limited to at least half the slots",
            legacy_errors,
        )
        self.assertIn(
            "one-sided +i^2 must not claim full-table coverage",
            legacy_errors,
        )
        self.assertIn(
            "a 4k+3 prime does not make one-sided +i^2 visit every slot",
            legacy_errors,
        )
        self.assertIn(
            "full coverage must be scoped to a different proven pairing",
            legacy_errors,
        )

    def test_q53_is_identical_between_web_and_offline_json(self):
        self.assertEqual(self.web_question, quiz_content(self.raw_question))

    def test_live_q53_preserves_the_quadratic_probe_boundary(self):
        self.assertEqual([], quadratic_probe_contract_errors(self.web_question))


if __name__ == "__main__":
    unittest.main()
