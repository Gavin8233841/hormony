"""Executable RFC contracts for the CS103 HTTP lesson.

Verified primary references:
- RFC 9110 Sections 9.2.1 and 9.2.2:
  https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.1
  https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2
  Safety means that the client does not request a state change. It does not
  prohibit logging, charging, or other implementation side effects. Idempotency
  compares the intended effect of repeated identical requests with one request.
- RFC 9112 Section 9.3:
  https://www.rfc-editor.org/rfc/rfc9112.html#section-9.3
  HTTP/1.1 persists by default unless the ``close`` connection option is sent;
  the HTTP/1.0 ``keep-alive`` option is not required for HTTP/1.1 persistence.
- RFC 9113 Sections 1 and 2:
  https://www.rfc-editor.org/rfc/rfc9113.html#section-1
  https://www.rfc-editor.org/rfc/rfc9113.html#section-2
  HTTP/2 multiplexing removes HTTP/1.1 application-layer head-of-line blocking,
  but it does not address TCP head-of-line blocking.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)

TOPIC_PATTERN = re.compile(r"^## Topic \d+: (.+)$", re.MULTILINE)
ACTIVITY_PATTERN = re.compile(
    r"^### 主动练习 (\d+)（[^）]+）\s*$",
    re.MULTILINE,
)
FIELD_PATTERN = re.compile(r"^- \*\*([^*]+)\*\*：\s*(.*)$")


KNOWLEDGE_CONTRACTS = {
    "cs103_k28": {
        "source_required": (
            "RFC 9110",
            "RFC 9112",
            "RFC 9113",
            "RFC 9114",
        ),
        "required": (
            "HTTP/1.1和HTTP/2通常运行在TCP之上",
            "HTTP/3运行在QUIC之上",
        ),
        "forbidden": (
            "HTTP（超文本传输协议）是基于请求-响应模型的应用层协议，运行在TCP之上",
        ),
    },
    "cs103_k29": {
        "source_required": (
            "RFC 9110第9.2.1节、第9.2.2节",
            "RFC 5789第2节",
        ),
        "required": (
            "安全方法的定义只表示客户端没有请求、也不期望目标资源状态改变",
            "不排除服务器记录日志、计费等附带副作用",
            "幂等只比较多个相同请求与单个请求的预期效果",
            "响应内容仍可不同",
        ),
        "forbidden": (
            "应为幂等且无副作用",
            "安全方法指不修改服务器状态的方法",
        ),
    },
    "cs103_k31": {
        "source_required": (
            "RFC 9112第9.3节",
            "RFC 9113第1节、第5节",
        ),
        "required": (
            "HTTP/2解决HTTP/1.1的应用层队头阻塞",
            "位于TCP字节缺口之后的HTTP/2帧无论属于哪条流都要等待缺口重传",
        ),
        "forbidden": (
            "彻底解决了队头阻塞问题",
        ),
    },
}

QUIZ_CONTRACTS = {
    "cs103_q09": {
        "required": (
            "DELETE是幂等但不安全",
            "多个相同DELETE请求与一次请求的预期效果相同",
            "安全不等于没有日志、计费等附带副作用",
        ),
        "forbidden": (
            "幂等指多次执行结果相同",
        ),
    },
    "cs103_q40": {
        "required": (
            "HTTP/1.1默认使用持久连接",
            "无需发送Connection:keep-alive",
            "Connection:close",
        ),
        "forbidden": (
            "默认开启持久连接（Connection:keep-alive）",
        ),
    },
}

WEB_SHORT_QUIZ_CONTRACTS = {
    "cs103_q11": {
        "required": (
            "解决HTTP/1.1的应用层队头阻塞",
            "未解决TCP队头阻塞",
            "丢失造成的字节缺口会暂时阻塞缺口后的所有HTTP/2流数据",
        ),
        "forbidden": (
            "解决队头阻塞",
            "消除队头阻塞",
            "每个请求需独立连接",
        ),
    },
}


def compact(value):
    return re.sub(r"\s+", "", value)


def clean_markdown(value):
    value = re.sub(r"^```[^\n]*\n?", "", value, flags=re.MULTILINE)
    value = re.sub(r"^```$", "", value, flags=re.MULTILINE)
    value = re.sub(r"`([^`]+)`", r"\1", value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"\1", value)
    value = re.sub(r"^\s*-\s+", "", value, flags=re.MULTILINE)
    value = re.sub(r"^---\s*$", "", value, flags=re.MULTILINE)
    return value.strip()


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
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


def extract_web_question(source, question_id):
    pattern = re.compile(
        r'id: "'
        + re.escape(question_id)
        + r'",\s*type: "(?:choice|short)",[\s\S]*?'
        + r'answer:\s*("(?:\\.|[^"\\])*")\s*,\s*'
        + r'explanation:\s*("(?:\\.|[^"\\])*")',
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web quiz question for {question_id!r}, got {len(matches)}"
        )
    answer_literal, explanation_literal = matches[0]
    return json.loads(answer_literal), json.loads(explanation_literal)


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
    return {
        key: clean_markdown("\n".join(value))
        for key, value in fields.items()
    }


def extract_topic_activities(source, topic):
    topics = list(TOPIC_PATTERN.finditer(source))
    topic_indexes = [
        index
        for index, match in enumerate(topics)
        if match.group(1).strip() == topic
    ]
    if len(topic_indexes) != 1:
        raise AssertionError(
            f"expected exactly one {topic} topic, got {len(topic_indexes)}"
        )

    topic_index = topic_indexes[0]
    topic_start = topics[topic_index].start()
    topic_end = (
        topics[topic_index + 1].start()
        if topic_index + 1 < len(topics)
        else len(source)
    )
    topic_section = source[topic_start:topic_end]
    matches = list(ACTIVITY_PATTERN.finditer(topic_section))
    activities = []
    for index, match in enumerate(matches):
        section_end = (
            matches[index + 1].start()
            if index + 1 < len(matches)
            else len(topic_section)
        )
        activities.append(parse_fields(topic_section[match.end():section_end]))
    return activities


def semantic_contract_errors(value, contract):
    normalized = compact(value)
    errors = []
    for required in contract["required"]:
        if compact(required) not in normalized:
            errors.append(f"missing required fact: {required}")
    for forbidden in contract["forbidden"]:
        if compact(forbidden) in normalized:
            errors.append(f"contains rejected fact: {forbidden}")
    return errors


def tcp_contiguous_delivery_trace(arrivals, initial_sequence=1):
    """Deliver equal-sized TCP byte ranges only when sequence order is contiguous."""
    next_sequence = initial_sequence
    buffered = {}
    trace = []

    for sequence, stream_id, payload in arrivals:
        if sequence < next_sequence or sequence in buffered:
            raise ValueError(f"duplicate or stale sequence {sequence}")
        buffered[sequence] = (stream_id, payload)
        delivered = []
        while next_sequence in buffered:
            stream, data = buffered.pop(next_sequence)
            delivered.append((next_sequence, stream, data))
            next_sequence += 1
        trace.append(
            {
                "arrival": sequence,
                "delivered": delivered,
                "next_sequence": next_sequence,
            }
        )

    return trace


def http2_hol_contract_errors(activity):
    errors = []
    if activity.get("type") != "state_trace":
        errors.append("HTTP/2 TCP HOL activity must be a state_trace")

    combined = compact(
        "\n".join(
            str(activity.get(field, ""))
            for field in ("prompt", "content", "answer", "feedback")
        )
    )
    required = (
        "同一条TCP连接",
        "序号2",
        "序号3",
        "序号3不能越过缺口交给HTTP/2",
        "序号2重传到达后",
        "按序交付序号2和3",
        "同一连接中位于缺口之后的其他HTTP/2流数据也会等待",
    )
    for fact in required:
        if compact(fact) not in combined:
            errors.append(f"HTTP/2 TCP HOL activity is missing: {fact}")

    rejected = "只有丢失帧所在stream阻塞"
    if rejected.lower() in combined.lower():
        errors.append("activity incorrectly limits TCP HOL blocking to one stream")
    if "RFC9113第1节" not in compact(str(activity.get("source", ""))):
        errors.append("activity source must cite RFC 9113 Section 1")
    return errors


def fixed_http2_hol_fixture():
    return {
        "type": "state_trace",
        "prompt": "同一条 TCP 连接承载两个 HTTP/2 流，请推演连续字节交付。",
        "content": "序号 2 丢失，携带另一条流数据的序号 3 先到达。",
        "answer": (
            "序号 3 不能越过缺口交给 HTTP/2；序号 2 重传到达后，"
            "TCP 才按序交付序号 2 和 3。"
        ),
        "feedback": (
            "同一连接中位于缺口之后的其他 HTTP/2 流数据也会等待。"
        ),
        "source": "RFC 9113第1节",
    }


class Cs103HttpFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.knowledge = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.quizzes = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))

    def test_web_and_raw_http_knowledge_are_exactly_synced_and_rfc_bounded(self):
        web_source = WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8")

        for chunk_id, contract in KNOWLEDGE_CONTRACTS.items():
            with self.subTest(chunk_id=chunk_id):
                chunk = find_unique(
                    self.knowledge,
                    chunk_id,
                    lambda item, expected=chunk_id: item.get("id") == expected,
                )
                web_text, web_chunk_source = extract_web_chunk(web_source, chunk_id)
                self.assertEqual(web_text, chunk["text"])
                self.assertEqual(web_chunk_source, chunk["source"])
                for source in contract["source_required"]:
                    self.assertIn(source, chunk["source"])
                self.assertEqual([], semantic_contract_errors(chunk["text"], contract))

    def test_http_quizzes_preserve_safe_idempotent_and_persistence_boundaries(self):
        web_source = WEB_QUIZZES_PATH.read_text(encoding="utf-8")
        for question_id, contract in QUIZ_CONTRACTS.items():
            with self.subTest(question_id=question_id):
                question = find_unique(
                    self.quizzes,
                    question_id,
                    lambda item, expected=question_id: item.get("id") == expected,
                )
                _, web_explanation = extract_web_question(web_source, question_id)
                self.assertEqual(web_explanation, question["explanation"])
                self.assertEqual(
                    [],
                    semantic_contract_errors(question["explanation"], contract),
                )

    def test_web_short_quiz_preserves_http2_tcp_hol_boundary(self):
        web_source = WEB_QUIZZES_PATH.read_text(encoding="utf-8")
        for question_id, contract in WEB_SHORT_QUIZ_CONTRACTS.items():
            with self.subTest(question_id=question_id):
                answer, explanation = extract_web_question(web_source, question_id)
                self.assertEqual(
                    [],
                    semantic_contract_errors(
                        f"{answer}\n{explanation}",
                        contract,
                    ),
                )

    def test_web_short_quiz_contract_rejects_all_hol_solved_fixture(self):
        legacy = (
            "HTTP/2在单一TCP连接上并行传输多个请求响应，解决队头阻塞。\n"
            "HTTP/1.1每个请求需独立连接；HTTP/2多路复用消除队头阻塞。"
        )
        errors = semantic_contract_errors(
            legacy,
            WEB_SHORT_QUIZ_CONTRACTS["cs103_q11"],
        )

        self.assertIn("contains rejected fact: 解决队头阻塞", errors)
        self.assertIn("contains rejected fact: 消除队头阻塞", errors)
        self.assertIn("contains rejected fact: 每个请求需独立连接", errors)

    def test_http_topic_is_generated_from_one_spec_with_two_activities(self):
        spec_activities = extract_topic_activities(
            SPEC_PATH.read_text(encoding="utf-8"),
            "HTTP协议",
        )
        experience = find_unique(
            self.experiences,
            "cs103/HTTP协议 experience",
            lambda item: item.get("courseId") == "cs103"
            and item.get("topic") == "HTTP协议",
        )
        generated = experience.get("activities", [])

        self.assertEqual(2, len(spec_activities))
        self.assertEqual(2, len(generated))
        self.assertEqual(
            ["cs103-HTTP协议-1", "cs103-HTTP协议-2"],
            [activity.get("id") for activity in generated],
        )
        for index, (spec, activity) in enumerate(
            zip(spec_activities, generated),
            start=1,
        ):
            with self.subTest(activity=index):
                self.assertEqual(spec["类型"], activity["type"])
                self.assertEqual(spec["题目"], activity["prompt"])
                self.assertEqual(spec["答案"], activity["answer"])
                self.assertEqual(spec["反馈"], activity["feedback"])
                self.assertEqual(spec["来源"], activity["source"])

    def test_tcp_reassembly_blocks_later_http2_stream_bytes_at_a_gap(self):
        arrivals = [
            (1, "stream-1", b"headers-1"),
            (3, "stream-3", b"data-3"),
            (2, "stream-1", b"data-1"),
        ]

        trace = tcp_contiguous_delivery_trace(arrivals)

        self.assertEqual([(1, "stream-1", b"headers-1")], trace[0]["delivered"])
        self.assertEqual([], trace[1]["delivered"])
        self.assertEqual(2, trace[1]["next_sequence"])
        self.assertEqual(
            [
                (2, "stream-1", b"data-1"),
                (3, "stream-3", b"data-3"),
            ],
            trace[2]["delivered"],
        )

    def test_http2_hol_contract_accepts_fixed_fixture(self):
        self.assertEqual([], http2_hol_contract_errors(fixed_http2_hol_fixture()))

    def test_http2_hol_contract_rejects_one_stream_only_fixture(self):
        wrong = fixed_http2_hol_fixture()
        wrong["answer"] = "序号 3 属于另一条流，可以立即交付给 HTTP/2。"
        wrong["feedback"] = "只有丢失帧所在 stream 阻塞。"

        errors = http2_hol_contract_errors(wrong)

        self.assertIn(
            "HTTP/2 TCP HOL activity is missing: 序号3不能越过缺口交给HTTP/2",
            errors,
        )
        self.assertIn(
            "activity incorrectly limits TCP HOL blocking to one stream",
            errors,
        )

    def test_generated_http2_activity_preserves_tcp_hol_boundary(self):
        experience = find_unique(
            self.experiences,
            "cs103/HTTP协议 experience",
            lambda item: item.get("courseId") == "cs103"
            and item.get("topic") == "HTTP协议",
        )
        activity = find_unique(
            experience.get("activities", []),
            "cs103-HTTP协议-2 activity",
            lambda item: item.get("id") == "cs103-HTTP协议-2",
        )

        self.assertEqual([], http2_hol_contract_errors(activity))


if __name__ == "__main__":
    unittest.main()
