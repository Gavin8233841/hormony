"""Executable facts for the CS101 quadratic-probing quiz.

Verified open-course reference:
- Virginia Tech OpenDSA, "Improved Collision Resolution", section
  "Quadratic Probing", source lines 216-231 and 252-285:
  https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/_sources/HashCImproved.rst.txt
  The simple probe function is (h(K) + i^2) mod M. Its sequence typically
  does not visit every slot. With prime M it visits at least half the slots;
  a different pairing, power-of-two M with (i^2 + i)/2, visits every slot.
- OpenDSA repository MIT license file:
  https://raw.githubusercontent.com/OpenDSA/OpenDSA/master/MIT-license.txt
  This contract cites the source for fact verification; it does not copy the
  external course text or questions into the product dataset.

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
DIFFICULTY_AUDIT_PATH = ROOT / "docs/QUIZ-DIFFICULTY-AUDIT-CS101.md"
QUESTION_ID = "cs101_q53"
STRING_LITERAL = r'"(?:\\.|[^"\\])*"'
PRIMARY_REFERENCE_URLS = (
    "https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/_sources/HashCImproved.rst.txt",
    "https://raw.githubusercontent.com/OpenDSA/OpenDSA/master/MIT-license.txt",
)
EXPECTED_Q53 = {
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
        "代入 i=0 至 6，位置序列为 0→1→4→2→2→4→1，因此不同槽位正是 "
        "{0, 1, 2, 4}，B 正确，并未访问 3、5、6。本题限定单侧 +i²，不包含 -i²。"
        "表长 M 为质数且偏移为 i² 时，序列至少访问一半槽位，所以表未满一半可"
        "保证找到空槽，但不能保证遍历所有槽位；M=7 虽是 4k+3 型质数也不例外。"
        "要保证全覆盖，需要使用匹配的其他组合，例如表长为 2 的幂且偏移为 "
        "(i²+i)/2。"
    ),
}
EXPECTED_RAW_Q53 = {
    "id": QUESTION_ID,
    "courseId": "cs101",
    "topic": "哈希表",
    **{key: EXPECTED_Q53[key] for key in ("question", "options", "answer", "explanation")},
    "difficulty": "easy",
    "tags": ["散列冲突", "数值计算", "基础识别"],
}
EXPECTED_AUDIT_SUMMARY = (
    "给定单侧二次探测公式、M=7 与 H(key)=0，计算 i=0 至 6 访问的不同槽位。"
)


def compact(value):
    return re.sub(r"\s+", "", value)


def strip_typescript_comments(source):
    output = []
    index = 0
    quote = None
    while index < len(source):
        current = source[index]
        if quote is not None:
            output.append(current)
            if current == "\\" and index + 1 < len(source):
                index += 1
                output.append(source[index])
            elif current == quote:
                quote = None
            index += 1
            continue
        if current in {'"', "'", "`"}:
            quote = current
            output.append(current)
            index += 1
            continue
        if source.startswith("//", index):
            newline = source.find("\n", index + 2)
            if newline == -1:
                break
            output.append("\n")
            index = newline + 1
            continue
        if source.startswith("/*", index):
            closing = source.find("*/", index + 2)
            if closing == -1:
                raise AssertionError("unterminated TypeScript block comment")
            index = closing + 2
            continue
        output.append(current)
        index += 1
    if quote is not None:
        raise AssertionError("unterminated TypeScript string literal")
    return "".join(output)


def extract_array_body(source, declaration):
    stripped = strip_typescript_comments(source)
    if stripped.count(declaration) != 1:
        raise AssertionError(f"expected exactly one array declaration: {declaration}")
    body_start = stripped.index(declaration) + len(declaration)
    depth = 1
    quote = None
    index = body_start
    while index < len(stripped):
        current = stripped[index]
        if quote is not None:
            if current == "\\" and index + 1 < len(stripped):
                index += 2
                continue
            if current == quote:
                quote = None
            index += 1
            continue
        if current in {'"', "'", "`"}:
            quote = current
        elif current == "[":
            depth += 1
        elif current == "]":
            depth -= 1
            if depth == 0:
                return stripped[body_start:index]
        index += 1
    raise AssertionError(f"array declaration has no matching closing bracket: {declaration}")


def find_unique(items, item_id):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(f"expected one item for {item_id!r}, got {len(matches)}")
    return matches[0]


def raw_quiz_content(question):
    return {
        key: question[key]
        for key in (
            "id",
            "courseId",
            "topic",
            "question",
            "options",
            "answer",
            "explanation",
            "difficulty",
            "tags",
        )
    }


def extract_web_choice(source, question_id):
    declaration = "export const cs101Quizzes: Quiz[] = withQuizMetadata(["
    cs101_export = extract_array_body(source, declaration)
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
    matches = pattern.findall(cs101_export)
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


def triangular_quadratic_probe(home, table_size, attempts):
    if table_size <= 0:
        raise ValueError("table_size must be positive")
    return [
        (home + (attempt * attempt + attempt) // 2) % table_size
        for attempt in range(attempts)
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
    for clause in re.split(r"[。；;！？!?\n]+", explanation):
        mentions_one_sided = "单侧" in clause or "+i²" in clause
        claims_coverage = "全覆盖" in clause or re.search(
            r"(?:所有|全部)(?:表位置|槽位|位置)", clause
        )
        claims_guarantee = any(term in clause for term in ("保证", "能够", "可以"))
        negates_guarantee = any(
            term in clause for term in ("不能保证", "不保证", "无法保证", "不能全覆盖")
        )
        if (
            mentions_one_sided
            and claims_coverage
            and claims_guarantee
            and not negates_guarantee
        ):
            errors.append("one-sided +i^2 must not be described as full coverage")
            break
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
        cls.difficulty_audit = DIFFICULTY_AUDIT_PATH.read_text(encoding="utf-8")

    def test_primary_reference_urls_are_pinned_in_contract(self):
        module_documentation = __doc__ or ""
        for url in PRIMARY_REFERENCE_URLS:
            self.assertIn(url, module_documentation)

    def test_four_k_plus_three_prime_does_not_cover_the_table(self):
        visited = one_sided_quadratic_probe(home=0, table_size=7, attempts=7)
        self.assertEqual([0, 1, 4, 2, 2, 4, 1], visited)
        self.assertEqual({0, 1, 2, 4}, set(visited))
        self.assertEqual({3, 5, 6}, set(range(7)) - set(visited))

    def test_triangular_offsets_cover_a_power_of_two_table(self):
        visited = triangular_quadratic_probe(home=0, table_size=8, attempts=8)
        self.assertEqual([0, 1, 3, 6, 2, 7, 5, 4], visited)
        self.assertEqual(set(range(8)), set(visited))

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

    def test_correct_keywords_cannot_hide_full_coverage_contradiction(self):
        contradictory = dict(CORRECT_FIXTURE)
        contradictory["explanation"] = (
            CORRECT_FIXTURE["explanation"]
            + "但上述单侧 +i² 也保证全覆盖所有槽位。"
        )
        self.assertIn(
            "one-sided +i^2 must not be described as full coverage",
            quadratic_probe_contract_errors(contradictory),
        )

    def test_web_extractor_ignores_comments_and_outside_objects(self):
        fixture = '''
const outsideBefore = {
  id: "cs101_q53", type: "choice", stem: "fake before", options: ["A. fake"],
  answer: "A", explanation: "fake before",
};
export const cs101Quizzes: Quiz[] = withQuizMetadata([
  {
    quizId: "quiz_cs101_hash", courseId: "cs101", topic: "哈希表",
    questions: [
      /* {
        id: "cs101_q53", type: "choice", stem: "fake comment", options: ["A. fake"],
        answer: "A", explanation: "fake comment",
      }, */
      {
        id: "cs101_q53",
        type: "choice",
        stem: "real question",
        options: ["A. no", "B. yes"],
        answer: "B",
        explanation: "real explanation",
      },
    ],
  },
]);
const outsideAfter = {
  id: "cs101_q53", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
'''
        self.assertEqual(
            {
                "id": QUESTION_ID,
                "question": "real question",
                "options": ["A. no", "B. yes"],
                "answer": "B",
                "explanation": "real explanation",
            },
            extract_web_choice(fixture, QUESTION_ID),
        )
        no_exported_question = '''
export const cs101Quizzes: Quiz[] = withQuizMetadata([
]);
const outsideAfter = {
  id: "cs101_q53", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
'''
        with self.assertRaises(AssertionError):
            extract_web_choice(no_exported_question, QUESTION_ID)

    def test_q53_is_identical_between_web_and_offline_json(self):
        self.assertEqual(EXPECTED_Q53, self.web_question)
        self.assertEqual(EXPECTED_RAW_Q53, raw_quiz_content(self.raw_question))

    def test_difficulty_audit_matches_the_executable_question(self):
        self.assertIn(f"#### {QUESTION_ID}", self.difficulty_audit)
        self.assertIn(EXPECTED_AUDIT_SUMMARY, self.difficulty_audit)
        self.assertNotIn(
            "直接记忆性题目，二次探测法的探测序列",
            self.difficulty_audit,
        )

    def test_live_q53_preserves_the_quadratic_probe_boundary(self):
        self.assertEqual([], quadratic_probe_contract_errors(self.web_question))


if __name__ == "__main__":
    unittest.main()
