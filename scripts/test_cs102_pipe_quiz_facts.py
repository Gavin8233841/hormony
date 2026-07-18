"""Executable facts for the CS102 anonymous-pipe quiz.

Verified primary references:
- POSIX.1-2024 pipe():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/pipe.html
  pipe() creates two file descriptors backed by open file descriptions. The
  interface does not make process ancestry a condition of using a descriptor.
- POSIX.1-2024 read():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html
  Reading an empty pipe returns zero after every writer is closed; while a
  writer remains, an empty blocking pipe waits and O_NONBLOCK changes the
  result.
- POSIX.1-2024 write():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/write.html
  A blocking pipe write may wait for space; O_NONBLOCK changes the full-pipe
  behavior, and a pipe with no reader follows the specified error boundary.
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
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs102-knowledge.ts"
RAW_KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
ACTIVE_LEARNING_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"
STRING_LITERAL = r'"(?:\\.|[^"\\])*"'
PRIMARY_REFERENCE_URLS = (
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/pipe.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html",
    "https://pubs.opengroup.org/onlinepubs/9799919799/functions/write.html",
    "https://man7.org/linux/man-pages/man7/unix.7.html",
    "https://man7.org/linux/man-pages/man7/pipe.7.html",
    "https://man7.org/linux/man-pages/man2/F_GETPIPE_SZ.2const.html",
)
EXPECTED_Q53 = {
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
        "pipe() 创建读端和写端；普通匿名管道通常在 fork 前创建，子进程继承文件描述符，"
        "所以常见于亲缘进程通信。但这不是接口施加的亲缘限制：任何持有描述符的进程都"
        "可使用相应端点，Linux 还可通过 UNIX 域套接字的 SCM_RIGHTS 把打开文件描述的"
        "引用传给无亲缘关系进程。Linux 管道容量有限但并非固定不变；F_GETPIPE_SZ 可"
        "查询容量，非特权进程可在系统约束内用 F_SETPIPE_SZ 请求调整，内核可能向上"
        "取整并返回实际容量。空管道读取或满管道写入在阻塞模式下可能等待，O_NONBLOCK "
        "会改变这一行为。"
    ),
}
EXPECTED_RAW_Q53 = {
    "id": "cs102_q53",
    "courseId": "cs102",
    "topic": "进程间通信",
    **{key: EXPECTED_Q53[key] for key in ("question", "options", "answer", "explanation")},
    "difficulty": "easy",
    "tags": ["IPC机制", "状态推演", "基础识别"],
}
EXPECTED_K44 = {
    "id": "cs102_k44",
    "text": (
        "普通匿名管道由 pipe() 创建读端和写端，是无消息边界的单向字节流。fork() 继承"
        "描述符是常见用法，但接口不要求进程具有亲缘关系；Linux 可通过 UNIX 域套接字"
        "的 SCM_RIGHTS 向其他进程传递管道描述符引用。Linux 管道容量有限，可用 "
        "F_GETPIPE_SZ 查询，并在权限和系统约束内用 F_SETPIPE_SZ 请求调整；内核可能"
        "向上取整并返回实际容量。阻塞读写取决于缓冲区状态、端点是否仍打开和 "
        "O_NONBLOCK；空管道且所有写端已关闭时 read() 返回 0 表示 EOF。命名管道"
        "（FIFO）通过文件系统路径打开，也提供管道字节流语义。"
    ),
    "source": (
        "POSIX.1-2024 pipe()/read()/write(); Linux pipe(7)/unix(7)/F_GETPIPE_SZ(2const)"
    ),
    "courseId": "cs102",
    "topic": "进程间通信",
}
EXPECTED_SPEC_CLAUSES = (
    "能否使用取决于是否持有描述符，而不是亲缘关系本身",
    "已有数据时本次 `read` 立即返回",
    "缓冲区读空且仍有写端时，后续 `read` 等待",
    "所有写端关闭后，`read` 返回 0（EOF）",
    "Linux 管道容量有限但不是固定 64KB",
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
        cls.web_chunk = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs102_k44",
        )
        raw_chunks = json.loads(RAW_KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_unique(raw_chunks, "cs102_k44")
        cls.active_learning_spec = ACTIVE_LEARNING_SPEC_PATH.read_text(encoding="utf-8")

    def test_primary_reference_urls_are_pinned_in_contract(self):
        module_documentation = __doc__ or ""
        for url in PRIMARY_REFERENCE_URLS:
            self.assertIn(url, module_documentation)

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

    def test_web_extractor_ignores_comments_and_outside_objects(self):
        fixture = '''
const outside = {
  id: "cs102_q53", type: "choice", stem: "fake", options: ["A. fake"],
  answer: "A", explanation: "fake",
};
export const cs102Quizzes: Quiz[] = withQuizMetadata([
  {
    quizId: "quiz_cs102_ipc", courseId: "cs102", topic: "进程间通信",
    questions: [
      /* {
        id: "cs102_q53", type: "choice", stem: "fake", options: ["A. fake"],
        answer: "A", explanation: "fake",
      }, */
      {
        id: "cs102_q53",
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
  id: "cs102_q53", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
export const cs103Quizzes: Quiz[] = withQuizMetadata([
]);
'''
        self.assertEqual(
            {
                "id": "cs102_q53",
                "question": "real question",
                "options": ["A. no", "B. yes"],
                "answer": "B",
                "explanation": "real explanation",
            },
            extract_web_choice(fixture, "cs102_q53"),
        )
        no_exported_question = '''
export const cs102Quizzes: Quiz[] = withQuizMetadata([
]);
const outsideAfterClosingBracket = {
  id: "cs102_q53", type: "choice", stem: "fake after", options: ["A. fake"],
  answer: "A", explanation: "fake after",
};
export const cs103Quizzes: Quiz[] = withQuizMetadata([
]);
'''
        with self.assertRaises(AssertionError):
            extract_web_choice(no_exported_question, "cs102_q53")

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
        self.assertEqual(EXPECTED_Q53, self.web_question)
        self.assertEqual(EXPECTED_RAW_Q53, raw_quiz_content(self.raw_question))
        self.assertEqual([], pipe_quiz_contract_errors(self.web_question))

    def test_k44_is_identical_offline_and_preserves_pipe_boundaries(self):
        self.assertEqual(EXPECTED_K44, self.web_chunk)
        self.assertEqual(EXPECTED_K44, self.raw_chunk)

    def test_active_learning_spec_preserves_read_and_capacity_boundaries(self):
        for clause in EXPECTED_SPEC_CLAUSES:
            self.assertIn(clause, self.active_learning_spec)
        self.assertIn("#include <stdio.h>", self.active_learning_spec)
        self.assertNotIn("普通管道只能用于具有共同祖先", self.active_learning_spec)
        self.assertNotIn("只能用于关系密切的同事（父子进程）", self.active_learning_spec)
        self.assertNotIn("父进程的 read 会一直阻塞", self.active_learning_spec)


if __name__ == "__main__":
    unittest.main()
