"""Executable fact contracts for the CS102 paging-fragmentation lesson.

Verified primary references:
- Operating System Concepts, 10th ed., official Chapter 9 slides 23 and 28:
  https://www.os-book.com/OS10/slide-dir/PPTX-dir/ch9.pptx
  Paging allows a process's physical address space to be noncontiguous, avoids
  external fragmentation, and can leave internal fragmentation in its last page.
- The same official slides 59-60 describe IA-32 segmentation with paging: the
  segmentation unit produces a linear address, then the paging unit maps it to
  fixed-size physical frames. Therefore paging each segment does not restore a
  requirement for physically contiguous variable-size segments.

The executable fixture below gives both allocators the same two noncontiguous
4 KiB free regions. A 6 KiB segment cannot fit contiguously despite 8 KiB total
free space, while two 4 KiB pages can occupy those two frames and leave 2 KiB
of internal fragmentation. This makes ``cs102_q35`` ambiguous as currently
written: both pure paging and segmentation with paging have internal, but no
physical-memory external, fragmentation.
"""

import json
import math
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"

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


def allocate_contiguous_segment(size, free_extents):
    """Return whether one variable-size segment fits a single free extent."""
    return any(length >= size for _, length in free_extents)


def allocate_paged_segment(size, page_size, free_frame_numbers):
    """Map a segment's pages to arbitrary free frames and report wasted bytes."""
    page_count = math.ceil(size / page_size)
    if len(free_frame_numbers) < page_count:
        return {
            "allocated": False,
            "frames": [],
            "internal_fragmentation": 0,
            "external_fragmentation": False,
        }
    frames = list(free_frame_numbers[:page_count])
    return {
        "allocated": True,
        "frames": frames,
        "internal_fragmentation": page_count * page_size - size,
        "external_fragmentation": False,
    }


def answered_option(question):
    prefix = f'{question.get("answer", "")}.'
    matches = [
        option for option in question.get("options", []) if option.startswith(prefix)
    ]
    if len(matches) != 1:
        return ""
    return matches[0]


def fragmentation_quiz_contract_errors(question):
    errors = []
    stem = compact(question.get("question", ""))
    options = question.get("options", [])
    answer = compact(answered_option(question))
    explanation = compact(question.get("explanation", ""))

    if "分页存储管理" not in stem or "哪种存储管理方式" in stem:
        errors.append(
            "question must isolate paging instead of comparing it with paged segmentation"
        )
    if any("段页式存储管理" in option for option in options):
        errors.append(
            "paged segmentation cannot be an incorrect distractor for this property"
        )
    if "内部碎片" not in answer or not any(
        wording in answer for wording in ("不产生外部碎片", "无外部碎片")
    ):
        errors.append(
            "the keyed option must say paging can have internal but no external fragmentation"
        )
    if "物理页框" not in explanation or not any(
        wording in explanation for wording in ("不连续", "任意空闲")
    ):
        errors.append(
            "explanation must connect the result to noncontiguous physical frames"
        )
    if "内部碎片" not in explanation or not any(
        wording in explanation for wording in ("不产生外部碎片", "无外部碎片")
    ):
        errors.append("explanation must distinguish internal and external fragmentation")
    if re.search(r"段页式.*(?:产生|存在|有).*外部碎片", explanation):
        errors.append(
            "segmentation with paging must not be said to cause physical external fragmentation"
        )
    return errors


class Cs102MemoryLessonFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        web_source = WEB_QUIZZES_PATH.read_text(encoding="utf-8")
        cls.web_q35 = extract_web_choice(web_source, "cs102_q35")
        cls.web_q50 = extract_web_choice(web_source, "cs102_q50")

        quizzes = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))
        cls.raw_q35 = find_unique(quizzes, "cs102_q35")
        cls.raw_q50 = find_unique(quizzes, "cs102_q50")

        knowledge = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.paged_segmentation_chunk = find_unique(knowledge, "cs102_k21")
        cls.spec = SPEC_PATH.read_text(encoding="utf-8")

    def test_scattered_frames_distinguish_paging_from_contiguous_segmentation(self):
        page_size = 4096
        segment_size = 6144
        free_extents = [(2 * page_size, page_size), (9 * page_size, page_size)]

        self.assertEqual(8192, sum(length for _, length in free_extents))
        self.assertFalse(allocate_contiguous_segment(segment_size, free_extents))

        paged = allocate_paged_segment(segment_size, page_size, [2, 9])
        self.assertEqual(
            {
                "allocated": True,
                "frames": [2, 9],
                "internal_fragmentation": 2048,
                "external_fragmentation": False,
            },
            paged,
        )

    def test_correct_fixture_is_green_and_legacy_claim_is_rejected(self):
        correct = {
            "question": "关于分页存储管理中的物理内存碎片，以下说法正确的是？",
            "options": [
                "A. 只产生外部碎片",
                "B. 可能产生内部碎片，但不产生外部碎片",
                "C. 同时产生内部碎片和外部碎片",
                "D. 两种碎片都不会产生",
            ],
            "answer": "B",
            "explanation": (
                "分页按固定大小的物理页框分配，页框可以不连续，因此不产生"
                "外部碎片；进程最后一页未填满时仍会产生内部碎片。"
            ),
        }
        wrong = {
            **correct,
            "explanation": correct["explanation"]
            + "段页式结合两者，可能同时存在内部和外部碎片。",
        }

        self.assertEqual([], fragmentation_quiz_contract_errors(correct))
        self.assertIn(
            "segmentation with paging must not be said to cause physical external fragmentation",
            fragmentation_quiz_contract_errors(wrong),
        )

    def test_web_and_generated_q35_have_one_unambiguous_paging_answer(self):
        self.assertEqual(self.web_q35, quiz_content(self.raw_q35))
        self.assertEqual([], fragmentation_quiz_contract_errors(self.web_q35))
        self.assertEqual([], fragmentation_quiz_contract_errors(self.raw_q35))

    def test_existing_supporting_content_preserves_paged_segmentation_boundary(self):
        self.assertIn(
            "分页消除外部碎片",
            self.paged_segmentation_chunk["text"],
        )
        self.assertIn("分页的无外部碎片优点", self.web_q50["explanation"])
        self.assertEqual(self.web_q50, quiz_content(self.raw_q50))
        self.assertIn("因格大小固定消除了区间的外部碎片", self.spec)


if __name__ == "__main__":
    unittest.main()
