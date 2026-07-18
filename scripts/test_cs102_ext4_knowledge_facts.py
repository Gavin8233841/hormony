"""Executable fact contracts for the CS102 ext4 knowledge chunk.

Verified primary references:
- Linux kernel ext4 Journal (JBD2) documentation:
  https://docs.kernel.org/filesystems/ext4/journal.html
  The default data=ordered mode journals metadata, so file data blocks are not
  guaranteed to be consistent after a crash. data=journal writes data and
  metadata through the journal, while data=writeback does not flush dirty data
  before metadata is written through the journal. A transaction without a
  valid commit record is discarded during replay; the commit block only marks
  the transaction as completely written to the journal.
- Linux kernel ext4 administration guide:
  https://docs.kernel.org/admin-guide/ext4.html
  data=journal commits all data to the journal before the main filesystem;
  default data=ordered forces data to the main filesystem before committing its
  metadata to the journal; data=writeback permits data to reach the main
  filesystem after its metadata has been committed.
- Btrfs documentation Introduction:
  https://btrfs.readthedocs.io/en/latest/Introduction.html
  Btrfs is a copy-on-write filesystem and must not be presented as an ext4 data
  journaling mode.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs102-knowledge.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
PRIMARY_REFERENCE_URLS = (
    "https://docs.kernel.org/filesystems/ext4/journal.html",
    "https://docs.kernel.org/admin-guide/ext4.html",
    "https://btrfs.readthedocs.io/en/latest/Introduction.html",
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


def extract_web_chunk(source, chunk_id):
    declaration = "export const cs102KnowledgeChunks: KnowledgeChunk[] = ["
    if source.count(declaration) != 1:
        raise AssertionError("expected exactly one exported CS102 knowledge array")
    array_start = source.index(declaration) + len(declaration)
    array_end = source.find("\n];", array_start)
    if array_end == -1:
        raise AssertionError("CS102 knowledge array has no closing bracket")
    exported_array = strip_typescript_comments(source[array_start:array_end])
    pattern = re.compile(
        r'\{\s*id: "'
        + re.escape(chunk_id)
        + r'",\s*text: ("(?:\\.|[^"\\])*")'
        + r',\s*source: ("(?:\\.|[^"\\])*")'
        + r',\s*courseId: ("(?:\\.|[^"\\])*")'
        + r',\s*topic: ("(?:\\.|[^"\\])*")\s*,?\s*\}',
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


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


def recover_ext4_after_crash(mode, events):
    """Execute the ordering guarantees documented for the three ext4 modes."""

    if mode not in {"journal", "ordered", "writeback"}:
        raise ValueError(f"unknown ext4 data mode: {mode}")

    associated_data_forced = False
    journal_data = False
    journal_metadata = False
    committed = False
    crashed = False

    for event in events:
        if crashed:
            raise ValueError("events cannot execute after crash")
        if event == "associated_data_forced":
            associated_data_forced = True
        elif event == "journal_data":
            if mode != "journal":
                raise ValueError("only data=journal writes file data through the journal")
            journal_data = True
        elif event == "journal_metadata":
            journal_metadata = True
        elif event == "commit":
            if not journal_metadata:
                raise ValueError("metadata must reach the journal before commit")
            if mode == "journal" and not journal_data:
                raise ValueError("data=journal must journal file data before commit")
            if mode == "ordered" and not associated_data_forced:
                raise ValueError(
                    "data=ordered must force associated file data before metadata commit"
                )
            committed = True
        elif event == "crash":
            crashed = True
        else:
            raise ValueError(f"unknown ext4 event: {event}")

    if not crashed:
        raise ValueError("fixture must end in a crash")
    if not committed:
        return {
            "metadata": "old",
            "data_recovery": (
                "associated_data_forced_without_metadata_commit"
                if associated_data_forced
                else "no_committed_data_update"
            ),
        }
    if journal_data:
        data_recovery = "journaled_data_replayable"
    elif associated_data_forced:
        data_recovery = "associated_data_forced_before_commit"
    else:
        data_recovery = "old_or_stale_data_possible"
    return {
        "metadata": "replayed",
        "data_recovery": data_recovery,
    }


def clauses_for_mode(text, mode):
    clauses = [compact(clause) for clause in re.split(r"[。；;！？!?\n]+", text)]
    return "；".join(clause for clause in clauses if mode in clause)


def ext4_knowledge_contract_errors(text, source):
    normalized = compact(text)
    normalized_source = compact(source)
    journal_details = clauses_for_mode(text, "data=journal")
    ordered_details = clauses_for_mode(text, "data=ordered")
    writeback_details = clauses_for_mode(text, "data=writeback")
    errors = []

    if not all(term in normalized for term in ("ext4", "崩溃", "元数据", "一致性")):
        errors.append(
            "ext4 journal guarantee must be scoped to crash-time metadata consistency"
        )

    if not (
        "数据和元数据" in journal_details
        and ("先写入日志" in journal_details or "通过日志" in journal_details)
    ):
        errors.append("data=journal must put file data and metadata through the journal")
    if (
        re.search(r"data=journal.{0,64}(?:只|仅)记录元数据", journal_details)
        or re.search(r"data=journal.{0,64}不记录文件数据", journal_details)
    ):
        errors.append("data=journal must not be described as metadata-only")

    if not (
        "默认" in ordered_details
        and ("只记录元数据" in ordered_details or "仅记录元数据" in ordered_details)
        and "文件数据" in ordered_details
        and (
            "先写入主文件系统" in ordered_details
            or "先强制写入主文件系统" in ordered_details
        )
        and "元数据" in ordered_details
        and "提交" in ordered_details
    ):
        errors.append(
            "default data=ordered must write file data before committing metadata"
        )

    if not (
        "文件数据" in writeback_details
        and (
            "可在元数据提交后写入" in writeback_details
            or "可能在元数据提交后写入" in writeback_details
        )
        and ("旧数据" in writeback_details or "陈旧数据" in writeback_details)
    ):
        errors.append(
            "data=writeback must allow file data after metadata commit and warn of stale data"
        )

    if not (
        "日志提交" in normalized
        and "应用数据" in normalized
        and ("不等于" in normalized or "不能推出" in normalized)
    ):
        errors.append(
            "journal commit must not imply application-data durability across modes"
        )
    if any(
        claim in normalized
        for claim in (
            "日志提交等于应用数据已持久化",
            "日志提交意味着应用数据已持久化",
            "日志提交保证应用数据已持久化",
        )
    ):
        errors.append("journal commit must not be stated as universal data durability")

    if "Btrfs" in text:
        if "写时复制" not in normalized:
            errors.append("Btrfs must be identified as copy-on-write")
        if not (
            "Btrfs不属于ext4日志模式" in normalized
            or "Btrfs不是ext4日志模式" in normalized
            or "不能把Btrfs归入ext4日志模式" in normalized
        ):
            errors.append("Btrfs must be separated from ext4 journaling modes")
    if any(
        phrase in normalized
        for phrase in (
            "ext4日志模式包括Btrfs",
            "ext4风格日志模式包括Btrfs",
            "Btrfs是ext4日志模式",
        )
    ):
        errors.append("Btrfs must not be called an ext4-style journaling mode")

    if "ZFS" in text and not (
        "ZFS不属于ext4日志模式" in normalized
        or "ZFS不是ext4日志模式" in normalized
        or "不能把ZFS归入ext4日志模式" in normalized
    ):
        errors.append("ZFS must not be grouped into ext4 journaling modes")

    for citation in (
        "Linuxkernelext4Journal(JBD2)",
        "Linuxkernelext4administrationguide",
    ):
        if citation not in normalized_source:
            errors.append(f"knowledge source must cite {citation}")
    if "Btrfs" in text and "BtrfsdocumentationIntroduction" not in normalized_source:
        errors.append("knowledge source must cite Btrfs documentation Introduction")
    return errors


class Cs102Ext4KnowledgeFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_chunk = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs102_k28",
        )
        cls.web_text = cls.web_chunk["text"]
        cls.web_source = cls.web_chunk["source"]
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_unique(
            chunks,
            "cs102_k28 raw knowledge chunk",
            lambda item: item.get("id") == "cs102_k28",
        )

    def test_primary_reference_urls_are_pinned_in_contract(self):
        module_documentation = __doc__ or ""
        for url in PRIMARY_REFERENCE_URLS:
            self.assertIn(url, module_documentation)

    def test_ext4_modes_produce_scoped_crash_guarantees(self):
        self.assertEqual(
            {
                "metadata": "replayed",
                "data_recovery": "journaled_data_replayable",
            },
            recover_ext4_after_crash(
                "journal",
                ["journal_data", "journal_metadata", "commit", "crash"],
            ),
        )
        self.assertEqual(
            {
                "metadata": "replayed",
                "data_recovery": "associated_data_forced_before_commit",
            },
            recover_ext4_after_crash(
                "ordered",
                ["associated_data_forced", "journal_metadata", "commit", "crash"],
            ),
        )
        self.assertEqual(
            {
                "metadata": "replayed",
                "data_recovery": "old_or_stale_data_possible",
            },
            recover_ext4_after_crash(
                "writeback",
                ["journal_metadata", "commit", "crash"],
            ),
        )

    def test_commit_alone_does_not_prove_application_data_is_durable(self):
        writeback = recover_ext4_after_crash(
            "writeback",
            ["journal_metadata", "commit", "crash"],
        )
        self.assertEqual("replayed", writeback["metadata"])
        self.assertEqual("old_or_stale_data_possible", writeback["data_recovery"])

        with self.assertRaisesRegex(
            ValueError,
            "data=ordered must force associated file data before metadata commit",
        ):
            recover_ext4_after_crash(
                "ordered",
                ["journal_metadata", "commit", "crash"],
            )

    def test_uncommitted_transaction_is_discarded_during_replay(self):
        self.assertEqual(
            {
                "metadata": "old",
                "data_recovery": "no_committed_data_update",
            },
            recover_ext4_after_crash(
                "writeback",
                ["journal_metadata", "crash"],
            ),
        )

    def test_correct_fixture_is_green(self):
        correct_text = (
            "ext4 使用 JBD2 日志维护崩溃后的元数据一致性。data=journal 将文件"
            "数据和元数据先写入日志；默认 data=ordered 只记录元数据，并在元数据"
            "提交前把文件数据先写入主文件系统；data=writeback 允许文件数据可在"
            "元数据提交后写入，崩溃时可能暴露旧数据。日志提交不等于所有模式下"
            "应用数据已经持久化，必须结合数据模式判断。Btrfs 是写时复制文件系统，"
            "Btrfs 不属于 ext4 日志模式。"
        )
        correct_source = (
            "Linux kernel ext4 Journal (JBD2)；"
            "Linux kernel ext4 administration guide；"
            "Btrfs documentation Introduction"
        )
        self.assertEqual(
            [],
            ext4_knowledge_contract_errors(correct_text, correct_source),
        )

    def test_collapsed_modes_and_universal_commit_claim_are_rejected(self):
        legacy_text = (
            "ext4 日志保证崩溃后元数据一致性。data=journal、data=ordered 和 "
            "data=writeback 都表示先写日志；日志提交意味着应用数据已持久化。"
        )
        errors = ext4_knowledge_contract_errors(
            legacy_text,
            "Linux kernel ext4 Journal (JBD2)",
        )
        self.assertIn(
            "data=journal must put file data and metadata through the journal",
            errors,
        )
        self.assertIn(
            "default data=ordered must write file data before committing metadata",
            errors,
        )
        self.assertIn(
            "data=writeback must allow file data after metadata commit and warn of stale data",
            errors,
        )
        self.assertIn(
            "journal commit must not imply application-data durability across modes",
            errors,
        )
        self.assertIn(
            "journal commit must not be stated as universal data durability",
            errors,
        )

    def test_positive_keywords_cannot_hide_a_contradictory_journal_claim(self):
        contradictory_text = (
            "ext4 使用 JBD2 日志维护崩溃后的元数据一致性。"
            "data=journal 将文件数据和元数据先写入日志；"
            "但 data=journal 实际只记录元数据；"
            "默认 data=ordered 只记录元数据，并在元数据提交前把文件数据"
            "先写入主文件系统；data=writeback 允许文件数据可在元数据提交后写入，"
            "崩溃时可能暴露旧数据。日志提交不等于应用数据已经持久化。"
        )
        errors = ext4_knowledge_contract_errors(
            contradictory_text,
            "Linux kernel ext4 Journal (JBD2)；"
            "Linux kernel ext4 administration guide",
        )
        self.assertIn("data=journal must not be described as metadata-only", errors)

    def test_btrfs_and_zfs_are_not_ext4_journaling_modes(self):
        wrong_text = (
            "ext4 在崩溃后保持元数据一致性。data=journal 把数据和元数据通过日志；"
            "默认 data=ordered 只记录元数据，文件数据先写入主文件系统再提交元数据；"
            "data=writeback 的文件数据可能在元数据提交后写入并暴露旧数据。日志提交"
            "不等于应用数据持久化。ext4 日志模式包括 Btrfs 和 ZFS。"
        )
        errors = ext4_knowledge_contract_errors(
            wrong_text,
            "Linux kernel ext4 Journal (JBD2)；"
            "Linux kernel ext4 administration guide；"
            "Btrfs documentation Introduction",
        )
        self.assertIn("Btrfs must be identified as copy-on-write", errors)
        self.assertIn("Btrfs must be separated from ext4 journaling modes", errors)
        self.assertIn("Btrfs must not be called an ext4-style journaling mode", errors)
        self.assertIn("ZFS must not be grouped into ext4 journaling modes", errors)

    def test_web_extractor_ignores_comments_and_unexported_objects(self):
        fixture = '''
// { id: "cs102_k28", text: "fake", source: "fake", courseId: "x", topic: "x" }
export const cs102KnowledgeChunks: KnowledgeChunk[] = [
  /* { id: "cs102_k28", text: "fake", source: "fake", courseId: "x", topic: "x" } */
  {
    id: "cs102_k28",
    text: "real text",
    source: "real source",
    courseId: "cs102",
    topic: "文件系统",
  },
];
const unused = {
  id: "cs102_k28", text: "fake", source: "fake", courseId: "x", topic: "x",
};
'''
        self.assertEqual(
            {
                "id": "cs102_k28",
                "text": "real text",
                "source": "real source",
                "courseId": "cs102",
                "topic": "文件系统",
            },
            extract_web_chunk(fixture, "cs102_k28"),
        )

    def test_k28_is_identical_offline_and_preserves_verified_boundaries(self):
        self.assertEqual(
            {key: self.raw_chunk[key] for key in (
                "id", "text", "source", "courseId", "topic"
            )},
            self.web_chunk,
        )
        self.assertEqual(
            [],
            ext4_knowledge_contract_errors(self.web_text, self.web_source),
        )


if __name__ == "__main__":
    unittest.main()
