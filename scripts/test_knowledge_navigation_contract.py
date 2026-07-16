import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
KNOWLEDGE_PAGE = (
    ROOT / "apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets"
)


def extract_method(source: str, name: str) -> str:
    """Extract an ArkTS method with balanced braces for source-contract checks."""
    signature = re.compile(
        rf"\b(?:private\s+)?(?:async\s+)?{re.escape(name)}\s*"
        rf"\([^)]*\)\s*(?::\s*[^{{]+)?\s*\{{"
    )
    match = signature.search(source)
    if match is None:
        raise AssertionError(f"ArkTS method not found: {name}")

    opening = match.end() - 1
    depth = 0
    quote = ""
    escaped = False
    line_comment = False
    block_comment = False

    for index in range(opening, len(source)):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            continue
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char == "/" and next_char == "/":
            line_comment = True
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            continue
        if char in ("'", '"', "`"):
            quote = char
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1:index]

    raise AssertionError(f"Unbalanced ArkTS method: {name}")


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


class KnowledgeNavigationContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = KNOWLEDGE_PAGE.read_text(encoding="utf-8")

    def test_search_text_cannot_become_a_lesson_or_quiz_topic(self):
        open_lesson = compact(extract_method(self.source, "openLesson"))

        self.assertNotIn("'selectedQuizTopic'", self.source)
        self.assertNotIn("pages/Quiz", self.source)
        self.assertIn("const topic = this.exactTopic(item);", open_lesson)
        self.assertNotIn("this.query", open_lesson)
        self.assertRegex(
            open_lesson,
            re.compile(
                r"AppStorage\.setOrCreate<string>\(\s*"
                r"'selectedContentTopic'\s*,\s*topic\s*\)"
            ),
        )

        content_topic_writes = re.findall(
            r"AppStorage\.setOrCreate<string>\(\s*"
            r"'selectedContentTopic'\s*,\s*([^\)]+)\)",
            self.source,
        )
        self.assertEqual(["topic"], [value.strip() for value in content_topic_writes])

    def test_only_an_exact_topic_from_the_current_course_can_open_lesson(self):
        exact_topic = compact(extract_method(self.source, "exactTopic"))
        open_lesson = compact(extract_method(self.source, "openLesson"))

        self.assertIn("typeof item.topic !== 'string'", exact_topic)
        self.assertRegex(
            exact_topic,
            re.compile(
                r"LearningContentRepository\.getTopics\(this\.courseId\)"
                r"\.includes\((?P<topic>item\.topic|topic)\) "
                r"\? (?P=topic) : ''"
            ),
        )

        guard = open_lesson.find("if (topic.length === 0)")
        write = open_lesson.find("'selectedContentTopic', topic")
        route = open_lesson.find("url: 'pages/Lesson'")
        self.assertGreaterEqual(guard, 0)
        self.assertGreater(write, guard)
        self.assertGreater(route, write)
        self.assertIn("return;", open_lesson[guard:write])

    def test_result_without_an_exact_topic_can_ask_with_source_material(self):
        ask_tutor = compact(extract_method(self.source, "askTutor"))
        result_card = compact(extract_method(self.source, "ResultCard"))

        self.assertIn("const topic = this.exactTopic(item);", ask_tutor)
        self.assertNotIn("return;", ask_tutor)
        self.assertIn("'pendingChatQuestion'", ask_tutor)
        self.assertIn("item.source", ask_tutor)
        self.assertIn("this.firstSentence(item.text)", ask_tutor)
        self.assertIn("url: 'pages/Chat'", ask_tutor)

        self.assertRegex(
            result_card,
            re.compile(
                r"if \(this\.exactTopic\(item\)\.length > 0\) "
                r"\{.*this\.openLesson\(item\);.*\} else "
                r"\{.*this\.askTutor\(item\);",
            ),
        )

    def test_cloud_results_filter_empty_fields_and_other_courses(self):
        validator = compact(extract_method(self.source, "validCourseResult"))
        search = compact(extract_method(self.source, "search"))

        self.assertIn("typeof item.text !== 'string'", validator)
        self.assertIn("typeof item.source !== 'string'", validator)
        self.assertIn("item.text.trim().length === 0", validator)
        self.assertIn("item.source.trim().length === 0", validator)
        self.assertIn("typeof item.courseId === 'string'", validator)
        self.assertRegex(
            validator,
            re.compile(r"return .*item\.courseId === this\.courseId;"),
        )
        self.assertRegex(
            search,
            re.compile(
                r"response\.chunks\.filter\(\(item: KnowledgeChunk\): boolean "
                r"=> this\.validCourseResult\(item\)\)\.slice\(0, 5\)"
            ),
        )


if __name__ == "__main__":
    unittest.main()
