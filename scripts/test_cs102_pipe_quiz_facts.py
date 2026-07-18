"""Executable facts for the CS102 anonymous-pipe quiz.

Verified primary references:
- POSIX.1-2024 pipe():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/pipe.html
  pipe() creates two file descriptors backed by open file descriptions. The
  interface does not make process ancestry a condition of using a descriptor.
- Linux unix(7), SCM_RIGHTS:
  https://man7.org/linux/man-pages/man7/unix.7.html
  SCM_RIGHTS sends open file descriptors to another process; more precisely it
  passes references to open file descriptions. This permits a pipe descriptor
  to reach a process that did not inherit it through fork().
- Linux pipe(7), pipe capacity:
  https://man7.org/linux/man-pages/man7/pipe.7.html
  A pipe is a unidirectional byte stream without message boundaries. Since
  Linux 2.6.35, capacity can be queried and set with F_GETPIPE_SZ and
  F_SETPIPE_SZ, so it must not be described as an unconditionally fixed size.
- Linux F_GETPIPE_SZ(2const):
  https://man7.org/linux/man-pages/man2/F_GETPIPE_SZ.2const.html
  F_SETPIPE_SZ requests at least arg bytes. The kernel may round upward and
  returns the actual capacity; an unprivileged request is system-limited.
"""

import errno
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


class PipeDescriptorRegistry:
    def __init__(self):
        self.descriptors = {}

    def create_pipe(self, process):
        self.descriptors[process] = {"read", "write"}

    def fork(self, parent, child):
        inherited = self.descriptors.get(parent)
        if inherited is None:
            raise ValueError("parent has no pipe descriptors")
        self.descriptors[child] = set(inherited)

    def pass_with_scm_rights(self, sender, receiver, descriptor):
        if descriptor not in self.descriptors.get(sender, set()):
            raise ValueError("sender does not hold the descriptor")
        self.descriptors.setdefault(receiver, set()).add(descriptor)

    def holds(self, process, descriptor):
        return descriptor in self.descriptors.get(process, set())


def observe_linux_pipe_resize(
    requested_capacity,
    returned_capacity,
    page_size,
    maximum_unprivileged_request,
    buffered_bytes=0,
):
    """Validate one documented F_SETPIPE_SZ request/result observation."""

    if requested_capacity > maximum_unprivileged_request:
        raise PermissionError("requested pipe capacity exceeds the allowed maximum")
    if requested_capacity < buffered_bytes:
        raise OSError(
            errno.EBUSY,
            "requested capacity is smaller than buffered data",
        )
    minimum_capacity = max(requested_capacity, page_size)
    if returned_capacity < minimum_capacity:
        raise ValueError("returned pipe capacity is smaller than the documented minimum")
    return returned_capacity


def pipe_quiz_contract_errors(question):
    selected = compact(answered_option(question))
    explanation = compact(question.get("explanation", ""))
    errors = []

    if not all(
        term in selected
        for term in ("单向", "字节流", "通常", "fork", "亲缘", "描述符")
    ):
        errors.append(
            "answer should preserve the usual inherited-descriptor pipe workflow"
        )

    if any(
        claim in explanation
        for claim in (
            "普通管道只能用于具有共同祖先",
            "普通管道只能用于亲缘关系",
            "匿名管道只能用于具有共同祖先",
            "匿名管道只能用于亲缘关系",
        )
    ):
        errors.append("pipe use must not be made an absolute ancestry restriction")
    if not all(
        term in explanation
        for term in ("pipe()", "文件描述符", "SCM_RIGHTS", "UNIX域套接字", "无亲缘关系")
    ):
        errors.append(
            "explanation must cover inherited and SCM_RIGHTS-transferred descriptors"
        )
    if re.search(
        r"(?:SCM_RIGHTS[^。；]{0,24}(?:不能|无法)|(?:不能|无法)[^。；]{0,24}SCM_RIGHTS)",
        explanation,
    ):
        errors.append("SCM_RIGHTS transfer must not be negated")

    if "固定大小" in explanation:
        errors.append("Linux pipe capacity must not be described as fixed")
    if not all(
        term in explanation
        for term in (
            "容量有限",
            "F_GETPIPE_SZ",
            "F_SETPIPE_SZ",
            "查询",
            "调整",
            "向上取整",
            "返回实际容量",
        )
    ):
        errors.append("explanation must preserve Linux pipe capacity controls")
    return errors


class Cs102PipeQuizFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_question = extract_web_choice(
            WEB_QUIZZES_PATH.read_text(encoding="utf-8"),
            "cs102_q53",
        )
        raw_questions = json.loads(RAW_QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.raw_question = find_unique(raw_questions, "cs102_q53")

    def test_fork_is_the_usual_pipe_descriptor_handoff(self):
        registry = PipeDescriptorRegistry()
        registry.create_pipe("parent")
        registry.fork("parent", "child")

        self.assertTrue(registry.holds("child", "read"))
        self.assertTrue(registry.holds("child", "write"))

    def test_scm_rights_can_reach_an_unrelated_process(self):
        registry = PipeDescriptorRegistry()
        registry.create_pipe("sender")
        registry.pass_with_scm_rights("sender", "unrelated-receiver", "read")

        self.assertTrue(registry.holds("unrelated-receiver", "read"))
        self.assertFalse(registry.holds("unrelated-receiver", "write"))

    def test_linux_pipe_capacity_is_queryable_and_adjustable(self):
        default_capacity = 65_536
        resized_capacity = observe_linux_pipe_resize(
            requested_capacity=100_000,
            returned_capacity=131_072,
            page_size=4_096,
            maximum_unprivileged_request=1_048_576,
            buffered_bytes=16_384,
        )

        self.assertNotEqual(default_capacity, resized_capacity)
        self.assertEqual(131_072, resized_capacity)
        self.assertGreaterEqual(resized_capacity, 100_000)
        with self.assertRaises(PermissionError):
            observe_linux_pipe_resize(
                requested_capacity=2_097_152,
                returned_capacity=2_097_152,
                page_size=4_096,
                maximum_unprivileged_request=1_048_576,
            )
        self.assertEqual(
            4_096,
            observe_linux_pipe_resize(
                requested_capacity=1_024,
                returned_capacity=4_096,
                page_size=4_096,
                maximum_unprivileged_request=1_048_576,
            ),
        )
        with self.assertRaises(OSError) as busy:
            observe_linux_pipe_resize(
                requested_capacity=32_768,
                returned_capacity=32_768,
                page_size=4_096,
                maximum_unprivileged_request=1_048_576,
                buffered_bytes=49_152,
            )
        self.assertEqual(errno.EBUSY, busy.exception.errno)
        with self.assertRaises(ValueError):
            observe_linux_pipe_resize(
                requested_capacity=100_000,
                returned_capacity=98_304,
                page_size=4_096,
                maximum_unprivileged_request=1_048_576,
            )

    def test_correctly_bounded_fixture_is_green(self):
        correct = {
            "id": "cs102_q53",
            "question": "在 UNIX/Linux 系统中，普通匿名管道（pipe）的数据流与典型使用方式是？",
            "options": [
                "A. 一个管道天然提供全双工通信",
                "B. 提供单向字节流，通常在 fork 后由亲缘进程共享描述符",
                "C. 读写数据不经过内核",
                "D. 管道端点可以直接跨网络连接",
            ],
            "answer": "B",
            "explanation": (
                "普通匿名管道通常在 fork 前由 pipe() 创建，亲缘进程继承文件描述符；"
                "这不是绝对亲缘限制，Linux 还可通过 UNIX 域套接字的 SCM_RIGHTS "
                "把管道文件描述符传给无亲缘关系进程。管道容量有限，可用 "
                "F_GETPIPE_SZ 查询，并在系统约束内用 F_SETPIPE_SZ 请求调整；"
                "内核可能向上取整并返回实际容量。"
            ),
        }
        self.assertEqual([], pipe_quiz_contract_errors(correct))

    def test_ancestry_only_and_fixed_capacity_claims_are_rejected(self):
        legacy = {
            "id": "cs102_q53",
            "question": "在 UNIX/Linux 系统中，管道（Pipe）的特点是？",
            "options": [
                "A. 管道是双向通信的",
                "B. 管道是半双工的，数据单向流动，通常用于具有亲缘关系的进程",
                "C. 管道通信不经过内核",
                "D. 管道可以跨网络通信",
            ],
            "answer": "B",
            "explanation": (
                "普通管道只能用于具有共同祖先的进程间通信。"
                "管道本质上是内核维护的固定大小缓冲区。"
            ),
        }
        errors = pipe_quiz_contract_errors(legacy)
        self.assertIn(
            "pipe use must not be made an absolute ancestry restriction",
            errors,
        )
        self.assertIn(
            "explanation must cover inherited and SCM_RIGHTS-transferred descriptors",
            errors,
        )
        self.assertIn("Linux pipe capacity must not be described as fixed", errors)
        self.assertIn(
            "explanation must preserve Linux pipe capacity controls",
            errors,
        )
        self.assertIn(
            "answer should preserve the usual inherited-descriptor pipe workflow",
            errors,
        )

    def test_negated_scm_rights_claim_cannot_pass_by_keywords(self):
        negated = {
            "id": "cs102_q53",
            "question": "在 UNIX/Linux 系统中，普通匿名管道如何传递？",
            "options": [
                "A. 天然提供全双工通信",
                "B. 提供单向字节流，通常在 fork 后由亲缘进程共享描述符",
                "C. 不经过内核",
                "D. 直接跨网络连接",
            ],
            "answer": "B",
            "explanation": (
                "pipe() 创建文件描述符，但通过 UNIX 域套接字的 SCM_RIGHTS 也不能"
                "把文件描述符交给无亲缘关系进程。Linux 管道容量有限，"
                "F_GETPIPE_SZ 可查询，F_SETPIPE_SZ 可请求调整；内核可能向上取整并"
                "返回实际容量。"
            ),
        }
        self.assertIn(
            "SCM_RIGHTS transfer must not be negated",
            pipe_quiz_contract_errors(negated),
        )

    def test_q53_is_identical_offline_and_preserves_pipe_boundaries(self):
        self.assertEqual(self.web_question, quiz_content(self.raw_question))
        self.assertEqual([], pipe_quiz_contract_errors(self.web_question))


if __name__ == "__main__":
    unittest.main()
