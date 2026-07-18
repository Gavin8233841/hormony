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
        "POSIX" in explanation
        and "mq_receive()" in explanation
        and "最高优先级" in explanation
        and ("同优先级" in explanation or "该优先级" in explanation)
        and ("最早" in explanation or "最先入队" in explanation)
    ):
        errors.append(
            "explanation must distinguish POSIX priority and FIFO selection"
        )

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

    def test_system_v_msgtyp_and_posix_priority_choose_different_messages(self):
        messages = [
            {"payload": "type-one", "type": 1, "priority": 1, "sequence": 0},
            {"payload": "priority-nine", "type": 2, "priority": 9, "sequence": 1},
        ]

        self.assertEqual("type-one", receive_system_v(messages, 1)["payload"])
        self.assertEqual("priority-nine", receive_posix(messages)["payload"])

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
                "System V 消息队列的 msgrcv() 用 msgtyp 选择离散消息。"
                "POSIX 消息队列的 mq_receive() 不使用消息类型，而是先选最高优先级，"
                "再取该优先级最早入队的消息。标准没有要求消息队列实现为内核链表。"
            ),
        }
        self.assertEqual([], message_queue_quiz_contract_errors(correct))

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

    def test_q54_is_identical_offline_and_preserves_queue_api_boundaries(self):
        self.assertEqual(self.web_question, quiz_content(self.raw_question))
        self.assertEqual([], message_queue_quiz_contract_errors(self.web_question))


if __name__ == "__main__":
    unittest.main()
