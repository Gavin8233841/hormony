"""Executable fact contracts for CS102 POSIX link semantics.

Verified primary references:
- POSIX.1-2024 <sys/stat.h>, link(), symlink(), and unlink():
  https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/sys_stat.h.html
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/link.html
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/symlink.html
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/unlink.html
  File identity is the combination of st_dev and st_ino. Hard links share that
  identity and increment its link count. Portable applications cannot rely on
  cross-filesystem hard links: link() fails with EXDEV when the source file and
  destination directory are on different file systems and the implementation
  does not support hard links between file systems.
  Symbolic links store an unvalidated pathname string and may cross filesystem
  boundaries. Directory hard links fail unless the implementation supports
  them and the process has appropriate privileges.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs102-knowledge.ts"
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)

STRING_LITERAL = r'"(?:\\.|[^"\\])*"'


def compact(value):
    return re.sub(r"\s+", "", value)


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


def extract_web_short_question(source, question_id):
    pattern = re.compile(
        r'\{\s*id:\s*"'
        + re.escape(question_id)
        + r'",\s*type:\s*"short",\s*stem:\s*('
        + STRING_LITERAL
        + r'),\s*answer:\s*('
        + STRING_LITERAL
        + r'),\s*explanation:\s*('
        + STRING_LITERAL
        + r'),\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web short question for {question_id!r}, got {len(matches)}"
        )
    stem_literal, answer_literal, explanation_literal = matches[0]
    return {
        "id": question_id,
        "question": json.loads(stem_literal),
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


class PosixLinkNamespace:
    def __init__(self):
        self.entries = {}
        self.link_counts = {}

    def create_file(self, path, identity):
        if path in self.entries:
            raise ValueError(f"path already exists: {path}")
        self.entries[path] = {"kind": "file", "identity": identity}
        self.link_counts[identity] = 1

    def hard_link(
        self,
        source,
        destination,
        destination_device,
        supports_cross_filesystem=False,
    ):
        if destination in self.entries:
            raise ValueError(f"path already exists: {destination}")
        source_entry = self.entries.get(source)
        if source_entry is None or source_entry["kind"] != "file":
            raise ValueError("hard-link source must name an existing file")
        identity = source_entry["identity"]
        if identity[0] != destination_device and not supports_cross_filesystem:
            raise OSError(
                "EXDEV: implementation does not support cross-filesystem hard links"
            )
        self.entries[destination] = {"kind": "file", "identity": identity}
        self.link_counts[identity] += 1

    def symbolic_link(self, target, destination, identity):
        if destination in self.entries:
            raise ValueError(f"path already exists: {destination}")
        self.entries[destination] = {
            "kind": "symlink",
            "identity": identity,
            "target": target,
        }
        self.link_counts[identity] = 1

    def unlink(self, path):
        entry = self.entries.pop(path)
        identity = entry["identity"]
        self.link_counts[identity] -= 1

    def lstat_identity(self, path):
        entry = self.entries.get(path)
        return None if entry is None else entry["identity"]

    def resolve_identity(self, path):
        entry = self.entries.get(path)
        if entry is None:
            return None
        if entry["kind"] == "file":
            return entry["identity"]
        target = self.entries.get(entry["target"])
        return None if target is None else target["identity"]


def directory_hard_link_result(has_privilege, implementation_supports):
    return "allowed" if has_privilege and implementation_supports else "EPERM"


def posix_link_contract_errors(knowledge_text, knowledge_source, answer, explanation):
    knowledge = compact(knowledge_text)
    source = compact(knowledge_source)
    answer_text = compact(answer)
    explanation_text = compact(explanation)
    quiz = answer_text + explanation_text
    errors = []

    if "文件身份由st_dev与st_ino共同确定" not in knowledge:
        errors.append("file identity must be the combination of st_dev and st_ino")
    if "硬链接具有相同文件身份" not in knowledge:
        errors.append("knowledge must say hard links share one file identity")
    if "POSIX.1-2024<sys/stat.h>" not in source:
        errors.append("inode source must cite POSIX.1-2024 <sys/stat.h>")
    if not all(
        term in source
        for term in (
            "POSIX.1-2024link()",
            "symlink()",
            "unlink()",
        )
    ):
        errors.append(
            "link source must cite POSIX.1-2024 link(), symlink(), and unlink()"
        )

    if not (
        "可移植" in quiz
        and (
            "不应依赖跨文件系统硬链接" in quiz
            or "不能依赖跨文件系统硬链接" in quiz
            or "应把它限制在同一文件系统" in quiz
            or "应限于同一文件系统" in quiz
        )
    ):
        errors.append("portable code must not rely on cross-filesystem hard links")
    if not all(term in quiz for term in ("不同文件系统", "实现不支持", "EXDEV")):
        errors.append(
            "cross-filesystem EXDEV must retain the POSIX implementation condition"
        )
    if any(
        term in answer_text
        for term in (
            "限于同一文件系统，不能跨文件系统",
            "硬链接不能跨文件系统",
            "硬链接不可跨文件系统",
        )
    ):
        errors.append(
            "POSIX must not be presented as unconditionally prohibiting "
            "cross-filesystem hard links"
        )
    if not (
        all(term in quiz for term in ("适当权限", "实现支持", "目录"))
        and ("才可成功" in quiz or "可以成功" in quiz or "允许" in quiz)
    ):
        errors.append(
            "directory hard-link rule must preserve the privilege and "
            "implementation exception"
        )
    if any(
        term in quiz
        for term in (
            "不能链接目录",
            "目录硬链接也不能成功",
            "目录硬链接不可以成功",
        )
    ):
        errors.append(
            "directory hard links must not be described as unconditionally impossible"
        )
    if not (
        "目标路径字符串" in quiz and "创建时目标可以不存在" in quiz
    ) or any(term in quiz for term in ("目标不可以不存在", "目标必须存在")):
        errors.append("symbolic-link target is an unvalidated pathname string")
    if not (
        ("符号链接" in quiz or "软链接" in quiz)
        and ("可跨文件系统" in quiz or "可以跨文件系统" in quiz)
    ):
        errors.append("symbolic links must be allowed to cross filesystem boundaries")
    if any(
        term in quiz
        for term in (
            "符号链接不能跨文件系统",
            "符号链接不可以跨文件系统",
            "符号链接不可跨文件系统",
            "软链接不能跨文件系统",
            "软链接不可以跨文件系统",
            "软链接不可跨文件系统",
        )
    ):
        errors.append("symbolic links must not be restricted to one filesystem")
    if not (
        "删除任一硬链接" in quiz
        and ("不影响其他硬链接" in quiz or "其他硬链接仍可" in quiz)
    ) or any(
        term in quiz for term in ("导致其他硬链接不可用", "其他硬链接失效")
    ):
        errors.append("unlinking one hard link must leave the other hard links usable")
    return errors


class Cs102PosixLinkFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_text, cls.web_source = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs102_k26",
        )
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_unique(
            chunks,
            "cs102_k26 raw knowledge chunk",
            lambda item: item.get("id") == "cs102_k26",
        )
        cls.link_question = extract_web_short_question(
            WEB_QUIZZES_PATH.read_text(encoding="utf-8"),
            "cs102_q15",
        )

    def test_hard_and_symbolic_links_follow_distinct_namespace_rules(self):
        namespace = PosixLinkNamespace()
        file_identity = (7, 42)
        symlink_identity = (7, 99)
        namespace.create_file("/fs/original", file_identity)
        namespace.hard_link("/fs/original", "/fs/backup", destination_device=7)
        namespace.symbolic_link(
            "/fs/original",
            "/fs/shortcut",
            symlink_identity,
        )

        self.assertEqual(file_identity, namespace.resolve_identity("/fs/original"))
        self.assertEqual(file_identity, namespace.resolve_identity("/fs/backup"))
        self.assertEqual(file_identity, namespace.resolve_identity("/fs/shortcut"))
        self.assertEqual(symlink_identity, namespace.lstat_identity("/fs/shortcut"))
        self.assertEqual(2, namespace.link_counts[file_identity])

        namespace.unlink("/fs/original")
        self.assertEqual(file_identity, namespace.resolve_identity("/fs/backup"))
        self.assertIsNone(namespace.resolve_identity("/fs/shortcut"))
        self.assertEqual(1, namespace.link_counts[file_identity])

    def test_cross_filesystem_hard_links_follow_implementation_capability(self):
        namespace = PosixLinkNamespace()
        namespace.create_file("/fs/original", (7, 42))

        with self.assertRaisesRegex(OSError, "EXDEV"):
            namespace.hard_link(
                "/fs/original",
                "/other/unsupported",
                destination_device=8,
                supports_cross_filesystem=False,
            )

        namespace.hard_link(
            "/fs/original",
            "/other/supported",
            destination_device=8,
            supports_cross_filesystem=True,
        )
        self.assertEqual((7, 42), namespace.resolve_identity("/other/supported"))
        self.assertEqual(2, namespace.link_counts[(7, 42)])

    def test_file_identity_requires_both_device_and_inode(self):
        namespace = PosixLinkNamespace()
        namespace.create_file("/fs/same-number", (7, 42))
        namespace.create_file("/other/same-number", (8, 42))

        self.assertNotEqual(
            namespace.lstat_identity("/fs/same-number"),
            namespace.lstat_identity("/other/same-number"),
        )
        self.assertEqual(1, namespace.link_counts[(7, 42)])
        self.assertEqual(1, namespace.link_counts[(8, 42)])

    def test_symbolic_links_may_cross_filesystems_and_dangle_at_creation(self):
        namespace = PosixLinkNamespace()
        namespace.create_file("/other/target", (8, 42))
        namespace.symbolic_link("/other/target", "/fs/cross-device", (7, 100))
        namespace.symbolic_link("/missing/target", "/fs/dangling", (7, 101))

        self.assertEqual((8, 42), namespace.resolve_identity("/fs/cross-device"))
        self.assertEqual((7, 100), namespace.lstat_identity("/fs/cross-device"))
        self.assertEqual((7, 101), namespace.lstat_identity("/fs/dangling"))
        self.assertIsNone(namespace.resolve_identity("/fs/dangling"))

        namespace.unlink("/fs/cross-device")
        self.assertIsNone(namespace.lstat_identity("/fs/cross-device"))
        self.assertEqual((8, 42), namespace.resolve_identity("/other/target"))

    def test_directory_link_exception_requires_both_posix_conditions(self):
        self.assertEqual("EPERM", directory_hard_link_result(False, False))
        self.assertEqual("EPERM", directory_hard_link_result(True, False))
        self.assertEqual("EPERM", directory_hard_link_result(False, True))
        self.assertEqual("allowed", directory_hard_link_result(True, True))

    def test_correct_fixture_is_green_and_absolute_directory_claim_is_rejected(self):
        correct_knowledge = (
            "POSIX 文件身份由 st_dev 与 st_ino 共同确定；同一文件的多个硬链接"
            "具有相同文件身份。"
        )
        correct_source = (
            "POSIX.1-2024 <sys/stat.h>；"
            "POSIX.1-2024 link()/symlink()/unlink()"
        )
        correct_answer = (
            "硬链接的可移植用法应限于同一文件系统，不应依赖跨文件系统硬链接；"
            "源文件与目标目录位于不同文件系统且实现不支持时，link() 以 EXDEV "
            "失败。删除任一硬链接不影响其他硬链接。对目录调用 link() 通常失败，"
            "只有进程有适当权限且实现支持目录硬链接时才可成功。"
        )
        correct_explanation = (
            "符号链接保存目标路径字符串，创建时目标可以不存在，也可跨文件系统。"
        )
        self.assertEqual(
            [],
            posix_link_contract_errors(
                correct_knowledge,
                correct_source,
                correct_answer,
                correct_explanation,
            ),
        )

        legacy_answer = correct_answer.replace(
            "对目录调用 link() 通常失败，只有进程有适当权限且实现支持目录硬链接时才可成功。",
            "硬链接不能链接目录。",
        )
        legacy_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            legacy_answer,
            correct_explanation,
        )
        self.assertIn(
            "directory hard-link rule must preserve the privilege and "
            "implementation exception",
            legacy_errors,
        )
        self.assertIn(
            "directory hard links must not be described as unconditionally impossible",
            legacy_errors,
        )

    def test_reversed_identity_and_filesystem_claims_are_rejected(self):
        correct_knowledge = (
            "POSIX 文件身份由 st_dev 与 st_ino 共同确定；同一文件的多个硬链接"
            "具有相同文件身份。"
        )
        correct_source = (
            "POSIX.1-2024 <sys/stat.h>；"
            "POSIX.1-2024 link()/symlink()/unlink()"
        )
        correct_answer = (
            "硬链接的可移植用法应限于同一文件系统，不应依赖跨文件系统硬链接；"
            "源文件与目标目录位于不同文件系统且实现不支持时，link() 以 EXDEV "
            "失败。删除任一硬链接不影响其他硬链接。对目录调用 link() 通常失败，"
            "只有进程有适当权限且实现支持目录硬链接时才可成功。"
        )
        correct_explanation = (
            "符号链接保存目标路径字符串，创建时目标可以不存在，符号链接可跨文件系统。"
        )

        inode_only_errors = posix_link_contract_errors(
            "POSIX 文件身份仅由 st_ino 确定；硬链接具有相同文件身份。",
            correct_source,
            correct_answer,
            correct_explanation,
        )
        self.assertIn(
            "file identity must be the combination of st_dev and st_ino",
            inode_only_errors,
        )

        unconditional_cross_filesystem_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            "硬链接限于同一文件系统，不能跨文件系统；删除任一硬链接不影响"
            "其他硬链接。对目录调用 link() 通常失败，只有进程有适当权限且"
            "实现支持目录硬链接时才可成功。",
            correct_explanation,
        )
        self.assertIn(
            "portable code must not rely on cross-filesystem hard links",
            unconditional_cross_filesystem_errors,
        )
        self.assertIn(
            "cross-filesystem EXDEV must retain the POSIX implementation condition",
            unconditional_cross_filesystem_errors,
        )
        self.assertIn(
            "POSIX must not be presented as unconditionally prohibiting "
            "cross-filesystem hard links",
            unconditional_cross_filesystem_errors,
        )

        same_filesystem_symlink_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            correct_answer,
            correct_explanation.replace(
                "符号链接可跨文件系统",
                "符号链接不能跨文件系统",
            ),
        )
        self.assertIn(
            "symbolic links must be allowed to cross filesystem boundaries",
            same_filesystem_symlink_errors,
        )
        self.assertIn(
            "symbolic links must not be restricted to one filesystem",
            same_filesystem_symlink_errors,
        )

    def test_negated_positive_phrases_do_not_satisfy_the_contract(self):
        correct_knowledge = (
            "POSIX 文件身份由 st_dev 与 st_ino 共同确定；同一文件的多个硬链接"
            "具有相同文件身份。"
        )
        correct_source = (
            "POSIX.1-2024 <sys/stat.h>；"
            "POSIX.1-2024 link()/symlink()/unlink()"
        )
        correct_answer = (
            "硬链接的可移植用法应限于同一文件系统，不应依赖跨文件系统硬链接；"
            "源文件与目标目录位于不同文件系统且实现不支持时，link() 以 EXDEV "
            "失败。删除任一硬链接不影响其他硬链接。对目录调用 link() 通常失败，"
            "只有进程有适当权限且实现支持目录硬链接时才可成功。"
        )
        correct_explanation = (
            "符号链接保存目标路径字符串，创建时目标可以不存在，符号链接可跨文件系统。"
        )

        negated_identity_errors = posix_link_contract_errors(
            "文件身份并非由 st_dev 与 st_ino 共同确定；硬链接不具有相同文件身份。",
            correct_source,
            correct_answer,
            correct_explanation,
        )
        self.assertIn(
            "file identity must be the combination of st_dev and st_ino",
            negated_identity_errors,
        )
        self.assertIn(
            "knowledge must say hard links share one file identity",
            negated_identity_errors,
        )

        missing_symlink_source_errors = posix_link_contract_errors(
            correct_knowledge,
            "POSIX.1-2024 <sys/stat.h>；POSIX.1-2024 link()/unlink()",
            correct_answer,
            correct_explanation,
        )
        self.assertIn(
            "link source must cite POSIX.1-2024 link(), symlink(), and unlink()",
            missing_symlink_source_errors,
        )

        missing_exdev_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            correct_answer.replace("link() 以 EXDEV 失败", "link() 失败"),
            correct_explanation,
        )
        self.assertIn(
            "cross-filesystem EXDEV must retain the POSIX implementation condition",
            missing_exdev_errors,
        )

        negated_directory_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            correct_answer.replace(
                "只有进程有适当权限且实现支持目录硬链接时才可成功",
                "即使进程有适当权限且实现支持，目录硬链接也不能成功",
            ),
            correct_explanation,
        )
        self.assertIn(
            "directory hard-link rule must preserve the privilege and "
            "implementation exception",
            negated_directory_errors,
        )
        self.assertIn(
            "directory hard links must not be described as unconditionally impossible",
            negated_directory_errors,
        )

        negated_symlink_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            correct_answer,
            "符号链接保存目标路径字符串，创建时目标不可以不存在，"
            "符号链接不可以跨文件系统。",
        )
        self.assertIn(
            "symbolic-link target is an unvalidated pathname string",
            negated_symlink_errors,
        )
        self.assertIn(
            "symbolic links must not be restricted to one filesystem",
            negated_symlink_errors,
        )

        broken_unlink_errors = posix_link_contract_errors(
            correct_knowledge,
            correct_source,
            correct_answer.replace(
                "删除任一硬链接不影响其他硬链接",
                "删除任一硬链接会导致其他硬链接不可用",
            ),
            correct_explanation,
        )
        self.assertIn(
            "unlinking one hard link must leave the other hard links usable",
            broken_unlink_errors,
        )

    def test_k26_and_q15_preserve_the_posix_identity_and_link_boundary(self):
        self.assertEqual(self.web_text, self.raw_chunk["text"])
        self.assertEqual(self.web_source, self.raw_chunk["source"])
        self.assertEqual(
            [],
            posix_link_contract_errors(
                self.web_text,
                self.web_source,
                self.link_question["answer"],
                self.link_question["explanation"],
            ),
        )


if __name__ == "__main__":
    unittest.main()
