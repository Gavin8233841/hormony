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
        self.assertIn("const evidence = this.evidenceFor(item);", ask_tutor)
        self.assertNotIn("return;", ask_tutor)
        self.assertIn("'pendingChatQuestion'", ask_tutor)
        self.assertIn("item.source", ask_tutor)
        self.assertIn("this.resultQuery", ask_tutor)
        self.assertNotIn("this.query.trim()", ask_tutor)
        self.assertIn("evidence.label", ask_tutor)
        self.assertIn("evidence.text", ask_tutor)
        self.assertNotIn("this.firstSentence(item.text)", ask_tutor)
        self.assertIn("url: 'pages/Chat'", ask_tutor)

        self.assertIn("Text(this.evidenceFor(item).label)", result_card)
        self.assertIn("Text(this.evidenceFor(item).text)", result_card)

        self.assertRegex(
            result_card,
            re.compile(
                r"if \(this\.exactTopic\(item\)\.length > 0\) "
                r"\{.*this\.openLesson\(item\);.*\} else "
                r"\{.*this\.askTutor\(item\);",
            ),
        )

    def test_evidence_prefers_query_then_topic_then_course_summary(self):
        interface = compact(self.source)
        evidence = compact(extract_method(self.source, "evidenceFor"))
        search = compact(extract_method(self.source, "search"))

        self.assertRegex(
            interface,
            re.compile(
                r"interface KnowledgeEvidence \{ label: string; text: string; \}"
            ),
        )
        self.assertIn("const query = this.resultQuery.trim()", evidence)
        self.assertNotIn("const query = this.query.trim()", evidence)
        self.assertIn("const submittedQuery = this.query.trim()", search)
        self.assertIn("this.resultQuery = submittedQuery", search)
        direct_query = evidence.find(
            "let evidence = this.matchedEvidence(segments, query)"
        )
        query_terms = evidence.find(
            "const queryTerms = query.split(/\\s+/).filter((term: string): "
            "boolean => term.length >= 2)"
        )
        token_match = evidence.find(
            "evidence = this.matchedEvidence(segments, term)", query_terms
        )
        query_label = evidence.find("label: '检索词命中'", token_match)
        topic_match = evidence.find(
            "evidence = this.matchedEvidence(segments, this.exactTopic(item))",
            query_label,
        )
        topic_label = evidence.find("label: 'Topic 关联'", topic_match)
        summary_label = evidence.find("label: '课程资料摘要'", topic_label)

        self.assertGreaterEqual(direct_query, 0)
        self.assertGreater(query_terms, direct_query)
        self.assertGreater(token_match, query_terms)
        self.assertGreater(query_label, token_match)
        self.assertGreater(topic_match, query_label)
        self.assertGreater(topic_label, topic_match)
        self.assertGreater(summary_label, topic_label)
        self.assertRegex(
            evidence,
            re.compile(
                r"return \{ label: '课程资料摘要', "
                r"text: this\.firstSentence\(item\.text\) \};"
            ),
        )

    def test_evidence_matching_uses_the_first_normalized_sentence_match(self):
        segments = compact(extract_method(self.source, "evidenceSegments"))
        matched = compact(extract_method(self.source, "matchedEvidence"))

        self.assertIn(".replace(/\\r\\n/g, '\\n')", segments)
        self.assertIn(".split(/[。；？！\\n]/)", segments)
        self.assertIn("segment.trim()", segments)
        self.assertIn("segment.length > 0", segments)

        self.assertIn(
            "const normalizedNeedle = needle.trim().toLowerCase();",
            matched,
        )
        self.assertIn("if (normalizedNeedle.length < 2) return '';", matched)
        loop = matched.find("for (const segment of segments)")
        normalize = matched.find(
            "segment.toLowerCase().indexOf(normalizedNeedle)", loop
        )
        return_match = matched.find(
            "if (matchIndex >= 0) return this.clipMatchedEvidence(segment, matchIndex)",
            normalize,
        )
        no_match = matched.find("return '';", return_match)
        self.assertGreaterEqual(loop, 0)
        self.assertGreater(normalize, loop)
        self.assertGreater(return_match, normalize)
        self.assertGreater(no_match, return_match)
        self.assertNotIn("Math.random", matched)

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

    def test_only_the_latest_search_request_can_publish_results(self):
        search = compact(extract_method(self.source, "search"))

        self.assertIn("private searchRequestVersion: number = 0", self.source)
        version = search.find(
            "const requestVersion = ++this.searchRequestVersion"
        )
        request = search.find("await HttpClient.post<KnowledgeSearchResponse>", version)
        success_guard = search.find(
            "if (requestVersion !== this.searchRequestVersion) return", request
        )
        publish = search.find("this.results = response.chunks.filter", success_guard)
        failure = search.find("catch (e)", publish)
        failure_guard = search.find(
            "if (requestVersion !== this.searchRequestVersion) return", failure
        )
        fallback = search.find("this.results = this.searchLocal(q)", failure_guard)
        loading_guard = search.find(
            "if (requestVersion === this.searchRequestVersion) this.loading = false"
        )

        self.assertGreaterEqual(version, 0)
        self.assertGreater(request, version)
        self.assertGreater(success_guard, request)
        self.assertGreater(publish, success_guard)
        self.assertGreater(failure, publish)
        self.assertGreater(failure_guard, failure)
        self.assertGreater(fallback, failure_guard)
        self.assertGreater(loading_guard, fallback)


if __name__ == "__main__":
    unittest.main()
