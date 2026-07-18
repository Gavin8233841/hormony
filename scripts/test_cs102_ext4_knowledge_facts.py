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


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


def recover_ext4_after_crash(mode, events):
    """Execute the ordering guarantees documented for the three ext4 modes."""

    if mode not in {"journal", "ordered", "writeback"}:
        raise ValueError(f"unknown ext4 data mode: {mode}")

    main_data = False
    journal_data = False
    journal_metadata = False
    committed = False
    crashed = False

    for event in events:
        if crashed:
            raise ValueError("events cannot execute after crash")
        if event == "main_data":
            main_data = True
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
            if mode == "ordered" and not main_data:
                raise ValueError(
                    "data=ordered must persist file data before metadata commit"
                )
            committed = True
        elif event == "crash":
            crashed = True
        else:
            raise ValueError(f"unknown ext4 event: {event}")

    if not crashed:
        raise ValueError("fixture must end in a crash")
    if not committed:
        return {"metadata": "old", "file_data": "new" if main_data else "old"}
    return {
        "metadata": "replayed",
        "file_data": "new" if main_data or journal_data else "old_or_stale",
    }


def ext4_knowledge_contract_errors(text, source):
    normalized = compact(text)
    normalized_source = compact(source)
    errors = []

    if not all(term in normalized for term in ("ext4", "崩溃", "元数据", "一致性")):
        errors.append(
            "ext4 journal guarantee must be scoped to crash-time metadata consistency"
        )

    if not (
        "data=journal" in normalized
        and "数据和元数据" in normalized
        and ("先写入日志" in normalized or "通过日志" in normalized)
    ):
        errors.append("data=journal must put file data and metadata through the journal")

    if not (
        "data=ordered" in normalized
        and "默认" in normalized
        and ("只记录元数据" in normalized or "仅记录元数据" in normalized)
        and "文件数据" in normalized
        and (
            "先写入主文件系统" in normalized
            or "先强制写入主文件系统" in normalized
        )
        and "元数据" in normalized
        and "提交" in normalized
    ):
        errors.append(
            "default data=ordered must write file data before committing metadata"
        )

    if not (
        "data=writeback" in normalized
        and "文件数据" in normalized
        and (
            "可在元数据提交后写入" in normalized
            or "可能在元数据提交后写入" in normalized
        )
        and ("旧数据" in normalized or "陈旧数据" in normalized)
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
        cls.web_text, cls.web_source = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs102_k28",
        )
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_chunk = find_unique(
            chunks,
            "cs102_k28 raw knowledge chunk",
            lambda item: item.get("id") == "cs102_k28",
        )

    def test_ext4_modes_produce_distinct_crash_states(self):
        self.assertEqual(
            {"metadata": "replayed", "file_data": "new"},
            recover_ext4_after_crash(
                "journal",
                ["journal_data", "journal_metadata", "commit", "crash"],
            ),
        )
        self.assertEqual(
            {"metadata": "replayed", "file_data": "new"},
            recover_ext4_after_crash(
                "ordered",
                ["main_data", "journal_metadata", "commit", "crash"],
            ),
        )
        self.assertEqual(
            {"metadata": "replayed", "file_data": "old_or_stale"},
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
        self.assertEqual("old_or_stale", writeback["file_data"])

        with self.assertRaisesRegex(
            ValueError,
            "data=ordered must persist file data before metadata commit",
        ):
            recover_ext4_after_crash(
                "ordered",
                ["journal_metadata", "commit", "crash"],
            )

    def test_uncommitted_transaction_is_discarded_during_replay(self):
        self.assertEqual(
            {"metadata": "old", "file_data": "old"},
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

    def test_k28_is_identical_offline_and_preserves_verified_boundaries(self):
        self.assertEqual(self.web_text, self.raw_chunk["text"])
        self.assertEqual(self.web_source, self.raw_chunk["source"])
        self.assertEqual(
            [],
            ext4_knowledge_contract_errors(self.web_text, self.web_source),
        )


if __name__ == "__main__":
    unittest.main()
