"""Executable facts for the CS102 message-queue quiz.

Verified primary references:
- POSIX.1-2024 msgsnd():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgsnd.html
  A System V message has a positive mtype used for receive-side selection.
- POSIX.1-2024 msgrcv():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgrcv.html
  System V message queues select the first message for msgtyp=0, the first
  message of the requested type for msgtyp>0, or the first message of the
  lowest eligible type for msgtyp<0.
- POSIX.1-2024 mq_receive():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_receive.html
  POSIX message queues receive the oldest message among those with the highest
  priority. They do not expose the System V msgtyp selection contract.
- POSIX.1-2024 mq_send():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_send.html
  Higher-priority messages precede lower-priority messages; a new message is
  placed after older messages with the same priority.
- POSIX.1-2024 Base Definitions 3.206 Message Queue:
  https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap03.html#tag_03_206
  The standard defines the queue object and observable removal order without
  requiring a linked-list representation.
- Linux man-pages pipe(7):
  https://man7.org/linux/man-pages/man7/pipe.7.html
  A pipe is a byte stream and does not preserve message boundaries.
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
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs102-knowledge.ts"
RAW_KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
ACTIVE_LEARNING_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"
STRING_LITERAL = r'"(?:\\.|[^"\\])*"'
PRIMARY_REFERENCE_URLS = (
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgsnd.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgrcv.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_receive.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_send.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap03.html#tag_03_206",
    "https://man7.org/linux/man-pages/man7/pipe.7.html",
)
EXPECTED_Q54 = {
    "id": "cs102_q54",
    "question": "与管道的字节流相比，System V 消息队列的主要特点是？",
    "options": [
        "A. 通信速度一定更快",
        "B. 保留消息边界，并可按消息类型选择性接收",
        "C. 不需要内核支持",
        "D. 只能用于同一进程内的线程通信",
    ],
    "answer": "B",
    "explanation": (
        "System V 消息队列保存带正整数 mtype 的离散消息；msgrcv() 的 msgtyp 为 0 时"
        "取队首，为正时取该类型的首条，为负时取类型不大于 |msgtyp| 的最低类型首条，"
        "因此 B 正确。POSIX 消息队列采用不同接口：mq_receive() 先选最高优先级，再取"
        "该优先级中最早入队的消息，不提供 System V 的 msgtyp 规则。POSIX 规范定义这些"
        "可观察语义，并未要求统一采用‘内核链表’实现。"
    ),
}
EXPECTED_RAW_Q54 = {
    "id": "cs102_q54",
    "courseId": "cs102",
    "topic": "进程间通信",
    **{key: EXPECTED_Q54[key] for key in ("question", "options", "answer", "explanation")},
    "difficulty": "medium",
    "tags": ["IPC机制", "结构操作", "应用推理"],
}
EXPECTED_K45 = {
    "id": "cs102_k45",
    "text": (
        "消息队列以离散消息而非管道式无格式字节流通信，因此保留消息边界。System V 与 "
        "POSIX 消息队列的接收选择规则不同：System V 的 msgrcv() 用 msgtyp 选择消息，"
        "msgtyp 为 0 时取队首，为正时取该类型首条，为负时取类型不大于 |msgtyp| 的最低"
        "类型首条；POSIX 的 mq_receive() 取最高优先级中最早入队的消息，不使用 System V "
        "的 msgtyp。标准规定这些可观察语义，不要求统一采用链表等内部结构。两类队列均受"
        "队列容量和单条消息大小限制。"
    ),
    "source": "POSIX.1-2024 msgsnd()/msgrcv()/mq_send()/mq_receive()",
    "courseId": "cs102",
    "topic": "进程间通信",
}
EXPECTED_SPEC_CASE_CLAUSE = (
    "消息队列像公司邮件系统：每封邮件保留边界，但收取规则取决于机制；System V 可用 "
    "mtype/msgtyp 按类型选择，POSIX 则先取最高 msg_prio、再取同优先级最早的消息。"
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
    declaration = "export const cs102Quizzes: Quiz[] = withQuizMetadata(["
    cs102_export = extract_array_body(source, declaration)
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
    matches = pattern.findall(cs102_export)
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


def extract_web_chunk(source, chunk_id):
    declaration = "export const cs102KnowledgeChunks: KnowledgeChunk[] = ["
    exported_array = extract_array_body(source, declaration)
    pattern = re.compile(
        r'\{\s*id: "'
        + re.escape(chunk_id)
        + r'",\s*text: ('
        + STRING_LITERAL
        + r'),\s*source: ('
        + STRING_LITERAL
        + r'),\s*courseId: ('
        + STRING_LITERAL
        + r'),\s*topic: ('
        + STRING_LITERAL
        + r')\s*,?\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(exported_array)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web knowledge chunk for {chunk_id!r}, got {len(matches)}"
        )
    text_literal, source_literal, course_id_literal, topic_literal = matches[0]
    return {
        "id": chunk_id,
        "text": json.loads(text_literal),
        "source": json.loads(source_literal),
        "courseId": json.loads(course_id_literal),
        "topic": json.loads(topic_literal),
    }


def answered_option(question):
    prefix = f'{question.get("answer", "")}.'
    matches = [
        option for option in question.get("options", []) if option.startswith(prefix)
    ]
    if len(matches) != 1:
        return ""
    return matches[0]


def receive_system_v(messages, msgtyp):
    """Select a message using the POSIX.1-2024 msgrcv() msgtyp rules."""

    if not messages:
        return None
    if msgtyp == 0:
        return messages[0]
    if msgtyp > 0:
        return next((message for message in messages if message["type"] == msgtyp), None)

    eligible_types = {
        message["type"] for message in messages if message["type"] <= abs(msgtyp)
    }
    if not eligible_types:
        return None
    lowest_type = min(eligible_types)
    return next(message for message in messages if message["type"] == lowest_type)


def receive_posix(messages):
    """Select the oldest message at the highest POSIX message priority."""

    if not messages:
        return None
    highest_priority = max(message["priority"] for message in messages)
    return min(
        (
            message
            for message in messages
            if message["priority"] == highest_priority
        ),
        key=lambda message: message["sequence"],
    )


def message_queue_quiz_contract_errors(question):
    stem = compact(question.get("question", ""))
    selected = compact(answered_option(question))
    explanation = compact(question.get("explanation", ""))
    errors = []

    if "SystemV" not in stem:
        errors.append("question must scope the receive semantics to System V")
    if not all(term in selected for term in ("消息边界", "按消息类型")):
        errors.append("selected answer must preserve boundaries and type selection")

    if "按消息类型" in selected or "按消息类型" in explanation:
        if "SystemV" not in stem + selected:
            errors.append(
                "type-selective receive must be scoped to System V message queues"
            )

    if not all(term in explanation for term in ("SystemV", "msgrcv()", "msgtyp")):
        errors.append("explanation must identify the System V msgtyp contract")
    if not (
        "msgtyp为0" in explanation
        and "取队首" in explanation
        and "为正" in explanation
        and "该类型" in explanation
        and "为负" in explanation
        and "不大于|msgtyp|" in explanation
        and "最低类型" in explanation
    ):
        errors.append("explanation must state all three System V msgtyp rules")
    if not (
        "POSIX" in explanation
        and "mq_receive()" in explanation
        and "最高优先级" in explanation
        and ("同优先级" in explanation or "该优先级" in explanation)
        and ("最早" in explanation or "最先入队" in explanation)
    ):
        errors.append(
            "explanation must distinguish POSIX priority and FIFO selection"
        )

    posix_clauses = [
        compact(clause)
        for clause in re.split(r"[。；;！？!?\n]+", question.get("explanation", ""))
        if "POSIX" in compact(clause)
    ]
    for clause in posix_clauses:
        claims_msgtyp = "使用msgtyp" in clause or "按消息类型" in clause
        negates_claim = (
            "不使用msgtyp" in clause
            or "不提供SystemV的msgtyp规则" in clause
            or "不按消息类型" in clause
            or "不使用消息类型" in clause
        )
        if claims_msgtyp and not negates_claim:
            errors.append("POSIX mq_receive must not be given System V msgtyp semantics")
            break

    if "消息队列是内核维护的链表" in explanation:
        errors.append(
            "standards do not define every message queue as a kernel linked list"
        )
    return errors


class Cs102MessageQueueQuizFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_question = extract_web_choice(
            WEB_QUIZZES_PATH.read_text(encoding="utf-8"),
            "cs102_q54",
        )
        raw_questions = json.loads(RAW_QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.raw_question = find_unique(raw_questions, "cs102_q54")
        cls.web_chunk = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs102_k45",
        )
        raw_chunks = json.loads(RAW_KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_unique(raw_chunks, "cs102_k45")
        cls.active_learning_spec = ACTIVE_LEARNING_SPEC_PATH.read_text(encoding="utf-8")

    def test_system_v_msgtyp_and_posix_priority_choose_different_messages(self):
        messages = [
            {"payload": "type-one", "type": 1, "priority": 1, "sequence": 0},
            {"payload": "priority-nine", "type": 2, "priority": 9, "sequence": 1},
        ]

        self.assertEqual("type-one", receive_system_v(messages, 1)["payload"])
        self.assertEqual("priority-nine", receive_posix(messages)["payload"])

    def test_primary_reference_urls_are_pinned_in_contract(self):
        module_documentation = __doc__ or ""
        for url in PRIMARY_REFERENCE_URLS:
            self.assertIn(url, module_documentation)

    def test_system_v_zero_and_negative_msgtyp_follow_distinct_rules(self):
        messages = [
            {"payload": "type-three", "type": 3, "priority": 0, "sequence": 0},
            {"payload": "type-one", "type": 1, "priority": 0, "sequence": 1},
            {"payload": "type-two", "type": 2, "priority": 0, "sequence": 2},
        ]

        self.assertEqual("type-three", receive_system_v(messages, 0)["payload"])
        self.assertEqual("type-one", receive_system_v(messages, -3)["payload"])

    def test_posix_equal_priority_selects_oldest_message(self):
        messages = [
            {"payload": "older", "type": 3, "priority": 7, "sequence": 4},
            {"payload": "newer", "type": 1, "priority": 7, "sequence": 5},
            {"payload": "lower", "type": 2, "priority": 6, "sequence": 0},
        ]

        self.assertEqual("older", receive_posix(messages)["payload"])

    def test_correctly_scoped_fixture_is_green(self):
        correct = {
            "id": "cs102_q54",
            "question": "与管道的字节流相比，System V 消息队列的主要特点是？",
            "options": [
                "A. 通信速度一定更快",
                "B. 保留消息边界，并可按消息类型选择性接收",
                "C. 不需要内核支持",
                "D. 只能用于同一进程内的线程通信",
            ],
            "answer": "B",
            "explanation": (
                "System V 消息队列的 msgrcv() 用 msgtyp 选择离散消息：msgtyp 为 0 时"
                "取队首，为正时取该类型首条，为负时取不大于 |msgtyp| 的最低类型首条。"
                "POSIX 消息队列的 mq_receive() 不使用消息类型，而是先选最高优先级，"
                "再取该优先级最早入队的消息。标准没有要求消息队列实现为内核链表。"
            ),
        }
        self.assertEqual([], message_queue_quiz_contract_errors(correct))

    def test_web_extractor_ignores_comments_and_outside_objects(self):
        fixture = '''
const outside = {
  id: "cs102_q54", type: "choice", stem: "fake", options: ["A. fake"],
  answer: "A", explanation: "fake",
};
export const cs102Quizzes: Quiz[] = withQuizMetadata([
  {
    quizId: "quiz_cs102_ipc", courseId: "cs102", topic: "进程间通信",
    questions: [
      /* {
        id: "cs102_q54", type: "choice", stem: "fake", options: ["A. fake"],
        answer: "A", explanation: "fake",
      }, */
      {
        id: "cs102_q54",
        type: "choice",
        stem: "real question",
        options: ["A. no", "B. yes"],
        answer: "B",
        explanation: "real explanation",
      },
    ],
  },
]);
const outsideAfterClosingBracket = {
  id: "cs102_q54", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
export const cs103Quizzes: Quiz[] = withQuizMetadata([
]);
'''
        self.assertEqual(
            {
                "id": "cs102_q54",
                "question": "real question",
                "options": ["A. no", "B. yes"],
                "answer": "B",
                "explanation": "real explanation",
            },
            extract_web_choice(fixture, "cs102_q54"),
        )
        no_exported_question = '''
export const cs102Quizzes: Quiz[] = withQuizMetadata([
]);
const outsideAfterClosingBracket = {
  id: "cs102_q54", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
export const cs103Quizzes: Quiz[] = withQuizMetadata([
]);
'''
        with self.assertRaises(AssertionError):
            extract_web_choice(no_exported_question, "cs102_q54")

    def test_generic_type_claim_and_linked_list_implementation_are_rejected(self):
        legacy = {
            "id": "cs102_q54",
            "question": "与管道相比，消息队列通信方式的主要优点是？",
            "options": [
                "A. 通信速度更快",
                "B. 消息是有格式的，可以按消息类型选择性接收",
                "C. 不需要内核支持",
                "D. 只能用于同一进程内的线程通信",
            ],
            "answer": "B",
            "explanation": "消息队列是内核维护的链表，可以按消息类型选择性接收。",
        }
        errors = message_queue_quiz_contract_errors(legacy)
        self.assertIn(
            "type-selective receive must be scoped to System V message queues",
            errors,
        )
        self.assertIn(
            "question must scope the receive semantics to System V",
            errors,
        )
        self.assertIn(
            "selected answer must preserve boundaries and type selection",
            errors,
        )
        self.assertIn(
            "explanation must identify the System V msgtyp contract",
            errors,
        )
        self.assertIn(
            "explanation must distinguish POSIX priority and FIFO selection",
            errors,
        )
        self.assertIn(
            "standards do not define every message queue as a kernel linked list",
            errors,
        )

    def test_correct_keywords_cannot_hide_posix_msgtyp_contradiction(self):
        contradictory = {
            "id": "cs102_q54",
            "question": "与管道字节流相比，System V 消息队列的主要特点是？",
            "options": [
                "A. 一定更快",
                "B. 保留消息边界，并可按消息类型选择性接收",
            ],
            "answer": "B",
            "explanation": (
                "System V 的 msgrcv() 中 msgtyp 为 0 时取队首，为正时取该类型首条，"
                "为负时取不大于 |msgtyp| 的最低类型首条。POSIX mq_receive() 先选"
                "最高优先级，再取该优先级最早入队的消息；但 POSIX 也使用 msgtyp"
                "按消息类型选择。"
            ),
        }
        self.assertIn(
            "POSIX mq_receive must not be given System V msgtyp semantics",
            message_queue_quiz_contract_errors(contradictory),
        )

    def test_q54_is_identical_offline_and_preserves_queue_api_boundaries(self):
        self.assertEqual(EXPECTED_Q54, self.web_question)
        self.assertEqual(EXPECTED_RAW_Q54, raw_quiz_content(self.raw_question))
        self.assertEqual([], message_queue_quiz_contract_errors(self.web_question))

    def test_k45_is_identical_offline_and_distinguishes_receive_contracts(self):
        self.assertEqual(EXPECTED_K45, self.web_chunk)
        self.assertEqual(EXPECTED_K45, self.raw_chunk)

    def test_active_learning_spec_does_not_restore_generic_type_selection(self):
        self.assertIn(EXPECTED_SPEC_CASE_CLAUSE, self.active_learning_spec)
        self.assertNotIn("收件人可按类型筛选", self.active_learning_spec)


if __name__ == "__main__":
    unittest.main()
