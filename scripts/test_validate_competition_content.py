import importlib.util
import io
import json
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("validate-competition-content.py")
SPEC = importlib.util.spec_from_file_location("validate_competition_content", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def quiz(question_id: str, topic: str, answer: str, difficulty: str) -> dict[str, object]:
    return {
        "id": question_id,
        "courseId": "cs101",
        "topic": topic,
        "question": f"Question {question_id}",
        "options": ["A. one", "B. two", "C. three", "D. four"],
        "answer": answer,
        "explanation": "Explanation.",
        "difficulty": difficulty,
        "tags": ["tag"],
    }


def provenance(
    access_status: str = "reachable",
    checked_at: str | None = "2026-07-17",
    http_status: int | None = 200,
) -> dict[str, object]:
    return {
        "sourceTitle": "Introduction to Algorithms",
        "sourceVersion": "4th edition",
        "sourceLocator": "Chapter 2",
        "sourceUrl": "https://mitpress.mit.edu/9780262046305/introduction-to-algorithms/",
        "rightsStatus": "reference-only",
        "rightsName": "Publisher terms",
        "rightsUrl": "https://mitpress.mit.edu/terms-of-use/",
        "accessStatus": access_status,
        "checkedAt": checked_at,
        "httpStatus": http_status,
    }


def manifest_text(include: list[str], exclude: list[str]) -> str:
    document = json.dumps({"include": include, "exclude": exclude}, ensure_ascii=False)
    return f"{MODULE.SUBMISSION_MANIFEST_MARKER}\n```json\n{document}\n```\n"


def complete_submission_entries() -> dict[str, bytes | None]:
    entries = {path: b"content" for path in MODULE.REQUIRED_SUBMISSION_PATHS}
    entries[MODULE.SUBMISSION_MANIFEST] = manifest_text(
        sorted(MODULE.REQUIRED_SUBMISSION_PATHS | MODULE.REQUIRED_MANIFEST_ROOTS), []
    ).encode("utf-8")
    return entries


class CompetitionContentGateTests(unittest.TestCase):
    def test_answer_position_gate_requires_all_four_labels_per_topic(self) -> None:
        questions = [
            quiz("q1", "topic", "A", "easy"),
            quiz("q2", "topic", "B", "easy"),
            quiz("q3", "topic", "B", "medium"),
            quiz("q4", "topic", "B", "medium"),
            quiz("q5", "topic", "B", "hard"),
        ]

        errors = MODULE.check_quiz_distribution(questions)

        self.assertTrue(any("缺少 C,D" in error for error in errors))
        self.assertTrue(any("B=4" in error for error in errors))

    def test_difficulty_gate_uses_global_ranges_without_per_topic_labels(self) -> None:
        questions: list[dict[str, object]] = []
        for topic_index in range(33):
            topic = f"topic-{topic_index}"
            repeated_answer = MODULE.ANSWER_LABELS[topic_index % len(MODULE.ANSWER_LABELS)]
            answers = ["A", "B", "C", "D", repeated_answer]
            for question_index, answer in enumerate(answers):
                global_index = topic_index * len(answers) + question_index
                if global_index < 67:
                    difficulty = "easy"
                elif global_index < 132:
                    difficulty = "medium"
                else:
                    difficulty = "hard"
                questions.append(
                    quiz(
                        f"q-{topic_index}-{question_index}",
                        topic,
                        answer,
                        difficulty,
                    )
                )

        errors = MODULE.check_quiz_distribution(questions)

        self.assertEqual({"easy"}, {question["difficulty"] for question in questions[:5]})
        self.assertEqual([], errors)

    def test_quiz_gate_rejects_duplicate_option_bodies_after_prefixes(self) -> None:
        question = quiz("q1", "topic", "A", "easy")
        question["options"] = ["A. same", "B. same", "C. three", "D. four"]

        errors = MODULE.check_quiz_distribution([question])

        self.assertTrue(any("选项正文不得重复" in error for error in errors))

    def test_https_syntax_is_not_reported_as_reachable(self) -> None:
        source_url = "https://example.com/reference"
        source_provenance = provenance()
        source_provenance["sourceUrl"] = source_url
        resource = {
            "id": "res_01",
            "title": "Resource",
            "type": "documentation",
            "url": source_url,
            "description": "Description",
            "courseId": "cs101",
            "tags": ["tag"],
            "provenance": source_provenance,
        }
        resources = [resource]

        errors = MODULE.check_external_resources(resources)
        note = MODULE.external_access_note(resources)

        self.assertEqual([], MODULE.check_provenance(resource, "external res_01"))
        self.assertFalse(any("provenance" in error for error in errors))
        self.assertIn("[UNVERIFIED]", note)
        self.assertIn("未发起网络请求", note)
        self.assertIn("reachable=1", note)

    def test_external_resource_url_must_match_provenance_source_url(self) -> None:
        record = {
            "id": "res_01",
            "title": "Resource",
            "type": "documentation",
            "url": "https://example.com/reference",
            "description": "Description",
            "courseId": "cs101",
            "tags": ["tag"],
            "provenance": provenance(),
        }

        errors = MODULE.check_external_resources([record])

        self.assertTrue(any("url 必须与 provenance.sourceUrl 完全一致" in error for error in errors))

    def test_missing_structured_knowledge_provenance_fails(self) -> None:
        chunks = [
            {
                "id": "chunk-1",
                "text": "Knowledge",
                "source": "Book title",
                "courseId": "cs101",
                "topic": "topic",
            }
        ]

        errors = MODULE.check_knowledge_provenance(chunks)

        self.assertTrue(any("缺少完整 provenance" in error for error in errors))

    def test_lesson_gate_checks_topics_activity_ids_and_sources(self) -> None:
        questions = [quiz("q1", "topic", "A", "easy")]
        activity = {
            "id": "activity-1",
            "type": "state_trace",
            "title": "State trace",
            "interactionMode": "free_response",
            "prompt": "Trace the state.",
            "content": "Initial state.",
            "language": "Trace",
            "answer": "Final state.",
            "feedback": "Reasoning.",
            "source": "Source section.",
        }
        experiences = [
            {
                "schemaVersion": 2,
                "courseId": "cs101",
                "topic": "topic",
                "activities": [activity, dict(activity)],
            }
        ]

        errors = MODULE.check_lesson_experiences(experiences, questions)

        self.assertTrue(any("activity id 重复: activity-1" in error for error in errors))
        self.assertTrue(any("Lesson 活动数应为 59，实际 2" in error for error in errors))
        self.assertFalse(any("缺少题库 Topic" in error for error in errors))

    def test_lesson_gate_checks_mode_specific_answer_contracts(self) -> None:
        questions = [quiz("q1", "topic", "A", "easy")]
        base_activity = {
            "id": "activity-1",
            "type": "state_trace",
            "title": "State trace",
            "prompt": "Trace the state.",
            "content": "Initial state.",
            "language": "Trace",
            "feedback": "Reasoning.",
            "source": "Source section.",
        }
        activities = [
            {
                **base_activity,
                "interactionMode": "free_response",
                "options": ["unexpected"],
                "answerIndexes": [],
                "answer": "",
            },
            {
                **base_activity,
                "id": "activity-2",
                "interactionMode": "single_choice",
                "options": ["one", "two"],
                "answerIndexes": [1],
                "answer": "one",
            },
            {
                **base_activity,
                "id": "activity-3",
                "interactionMode": "ordered_choice",
                "options": ["one", "two"],
                "answerIndexes": [0, 0],
                "answer": "one then two",
            },
            {
                **base_activity,
                "id": "activity-4",
                "interactionMode": "ordered_choice",
                "options": ["one", "two"],
                "answerIndexes": [1, 0],
                "answer": "A → B",
            },
        ]
        experiences = [
            {
                "schemaVersion": 2,
                "courseId": "cs101",
                "topic": "topic",
                "activities": activities,
            }
        ]

        errors = MODULE.check_lesson_experiences(experiences, questions)

        self.assertTrue(any("activity[0].answer" in error for error in errors))
        self.assertTrue(any("free_response" in error for error in errors))
        self.assertTrue(any("标准答案必须等于" in error for error in errors))
        self.assertTrue(any("答案索引完整且不重复" in error for error in errors))
        self.assertTrue(any("标准答案与答案索引不一致" in error for error in errors))

    def test_lesson_gate_requires_rendered_experience_fields(self) -> None:
        experiences = [
            {
                "schemaVersion": 2,
                "courseId": "cs101",
                "topic": "topic",
                "visualTitle": "",
                "visualSteps": [],
                "caseTitle": "",
                "caseBody": "",
                "workedExampleTitle": "",
                "workedExampleSteps": [],
                "activities": [],
            }
        ]

        errors = MODULE.check_lesson_experiences(
            experiences,
            [quiz("q1", "topic", "A", "easy")],
        )

        for field in (
            "visualTitle",
            "visualSteps",
            "caseTitle",
            "caseBody",
            "workedExampleTitle",
            "workedExampleSteps",
        ):
            self.assertTrue(any(field in error for error in errors), field)

    def test_content_gate_requires_core_display_fields(self) -> None:
        question = quiz("q1", "topic", "A", "easy")
        question.pop("question")
        question["explanation"] = ""
        question["tags"] = []
        question_errors = MODULE.check_quiz_distribution([question])

        chunk = {
            "id": "chunk-1",
            "text": "",
            "source": "Introduction to Algorithms",
            "courseId": "",
            "topic": "",
            "provenance": provenance(),
        }
        knowledge_errors = MODULE.check_knowledge_provenance([chunk])

        source_url = provenance()["sourceUrl"]
        resource = {
            "id": "res_01",
            "title": "",
            "type": "documentation",
            "url": source_url,
            "description": "",
            "courseId": "",
            "tags": [],
            "provenance": provenance(),
        }
        resource_errors = MODULE.check_external_resources([resource])

        self.assertTrue(any("question" in error for error in question_errors))
        self.assertTrue(any("explanation" in error for error in question_errors))
        self.assertTrue(any("tags" in error for error in question_errors))
        self.assertTrue(any(".text" in error for error in knowledge_errors))
        self.assertTrue(any(".courseId" in error for error in knowledge_errors))
        self.assertTrue(any(".topic" in error for error in knowledge_errors))
        self.assertTrue(any(".title" in error for error in resource_errors))
        self.assertTrue(any(".description" in error for error in resource_errors))
        self.assertTrue(any(".courseId" in error for error in resource_errors))
        self.assertTrue(any(".tags" in error for error in resource_errors))

    def test_topic_alignment_compares_exact_course_topic_pairs(self) -> None:
        knowledge = [
            {"courseId": "cs101", "topic": "shared"},
            {"courseId": "cs102", "topic": "knowledge-only"},
        ]
        questions = [
            quiz("q1", "shared", "A", "easy"),
            {**quiz("q2", "quiz-only", "B", "medium"), "courseId": "cs103"},
        ]

        errors = MODULE.check_topic_alignment(knowledge, questions)

        self.assertTrue(any("缺少题库 Topic" in error and "cs103/quiz-only" in error for error in errors))
        self.assertTrue(any("题库外 Topic" in error and "cs102/knowledge-only" in error for error in errors))

    def test_known_false_content_fragments_are_rejected(self) -> None:
        records = [
            {
                "id": "chunk-1",
                "text": "HTTP/2 彻底解决了队头阻塞问题。",
                "nested": {"feedback": "HPKP公钥固定进一步增强了安全性。"},
            }
        ]

        errors = MODULE.check_disallowed_fact_fragments([("知识切片", records)])

        self.assertEqual(2, len(errors))
        self.assertTrue(all("chunk-1" in error for error in errors))

    def test_complete_provenance_accepts_all_access_states(self) -> None:
        records = [
            {"provenance": provenance()},
            {"provenance": provenance("unreachable", "2026-07-17", 503)},
            {"provenance": provenance("unreachable", "2026-07-17", None)},
            {"provenance": provenance("not-checked", None, None)},
        ]

        errors = [
            error
            for index, record in enumerate(records)
            for error in MODULE.check_provenance(record, f"record-{index}")
        ]

        self.assertEqual([], errors)

    def test_provenance_rejects_placeholders_and_invalid_status_evidence(self) -> None:
        invalid = provenance()
        invalid["sourceVersion"] = "TBD"
        invalid["sourceUrl"] = "http://example.com/source"
        invalid["checkedAt"] = None
        invalid["httpStatus"] = 404

        errors = MODULE.check_provenance({"provenance": invalid}, "record")

        self.assertTrue(any("sourceVersion" in error and "占位" in error for error in errors))
        self.assertTrue(any("sourceUrl" in error and "HTTPS" in error for error in errors))
        self.assertTrue(any("checkedAt" in error and "reachable" in error for error in errors))
        self.assertTrue(any("httpStatus" in error and "200-399" in error for error in errors))

    def test_submission_gate_rejects_forbidden_paths_and_secret_literals(self) -> None:
        entries = complete_submission_entries()
        entries[".trae/progress.json"] = b"{}"
        entries[".agents/instructions.md"] = b"content"
        entries["screenshot/demo.png"] = b"content"
        entries["Assets/reference.txt"] = b"content"
        entries["signing/release.P12"] = b"content"
        entries["docs/leak.md"] = b'VERCEL_TOKEN = "' + (b"x" * 16) + b'"'
        entries["docs/CONFIG.MD"] = b"MODEL_API_KEY=" + (b"aB3_" * 8)
        entries["docs/setup.md"] = 'MODEL_API_KEY="<在本机手动填入>"'.encode("utf-8")
        entries["apps/web/.npmrc"] = (
            b"//registry.example.invalid/:" + b"_auth" + b"Token=" + (b"z" * 24)
        )

        errors = MODULE.check_submission_package(entries)

        self.assertTrue(any(".trae/progress.json" in error for error in errors))
        self.assertTrue(any(".agents/instructions.md" in error for error in errors))
        self.assertTrue(any("screenshot/demo.png" in error for error in errors))
        self.assertTrue(any("Assets/reference.txt" in error for error in errors))
        self.assertTrue(any("signing/release.P12" in error for error in errors))
        self.assertTrue(any("literal-server-secret" in error for error in errors))
        self.assertTrue(any("unquoted-server-secret" in error for error in errors))
        self.assertTrue(any("package-registry-auth-token" in error for error in errors))
        self.assertTrue(all("x" * 16 not in error for error in errors))
        self.assertFalse(
            any(
                "docs/setup.md" in error and "敏感信息命中" in error
                for error in errors
            )
        )

    def test_submission_gate_requires_manifest_and_core_sources(self) -> None:
        errors = MODULE.check_submission_package({"README.md": b"readme"})

        self.assertTrue(any(MODULE.SUBMISSION_MANIFEST in error for error in errors))
        self.assertTrue(any("apps/web/package.json" in error for error in errors))
        self.assertTrue(any(MODULE.COMPETITION_NOTICE in error for error in errors))

    def test_submission_gate_rejects_empty_required_sources(self) -> None:
        entries = complete_submission_entries()
        entries["README.md"] = b""

        errors = MODULE.check_submission_package(entries)

        self.assertTrue(any("提交源码清单为空: README.md" in error for error in errors))

    def test_submission_gate_rejects_unsafe_relative_paths(self) -> None:
        entries = complete_submission_entries()
        entries["../outside.txt"] = b"content"
        entries["C:/absolute.txt"] = b"content"
        entries["apps/web/.env.production"] = b"content"

        errors = MODULE.check_submission_package(entries)

        self.assertTrue(any("../outside.txt" in error for error in errors))
        self.assertTrue(any("C:/absolute.txt" in error for error in errors))
        self.assertTrue(any(".env.production" in error for error in errors))

    def test_submission_gate_rejects_unscannable_large_text(self) -> None:
        entries = complete_submission_entries()
        entries["docs/oversized.md"] = b"x" * (MODULE.MAX_TEXT_SCAN_BYTES + 1)

        errors = MODULE.check_submission_package(entries)

        self.assertTrue(
            any("条目无法完成敏感信息扫描: docs/oversized.md" in error for error in errors)
        )

    def test_submission_gate_requires_exact_manifest_file_set(self) -> None:
        expected = set(MODULE.REQUIRED_SUBMISSION_PATHS)
        entries = complete_submission_entries()
        missing = "apps/web/package.json"
        entries.pop(missing)
        entries["docs/unlisted.md"] = b"content"

        errors = MODULE.check_submission_package(entries, expected_names=expected)

        self.assertTrue(any("缺少 manifest 展开文件" in error and missing in error for error in errors))
        self.assertTrue(
            any("包含 manifest 外文件" in error and "docs/unlisted.md" in error for error in errors)
        )

    def test_submission_gate_requires_manifest_content_identity(self) -> None:
        expected = complete_submission_entries()
        entries = dict(expected)
        entries["README.md"] = b"tampered"
        entries[MODULE.SUBMISSION_MANIFEST] = manifest_text(["README.md"], []).encode("utf-8")

        errors = MODULE.check_submission_package(
            entries,
            expected_names=set(expected),
            expected_entries=expected,
        )

        self.assertTrue(any("源文件不一致: README.md" in error for error in errors))
        self.assertTrue(any(MODULE.SUBMISSION_MANIFEST in error and "源文件不一致" in error for error in errors))
        self.assertTrue(any("manifest 未选择条目" in error for error in errors))

    def test_pending_notice_is_allowed_only_for_manifest_source_audit(self) -> None:
        entries = complete_submission_entries()
        entries[MODULE.COMPETITION_NOTICE] = MODULE.PENDING_SUBMISSION_MARKER

        source_errors = MODULE.check_submission_package(entries, allow_pending_notice=True)
        final_errors = MODULE.check_submission_package(entries, allow_pending_notice=False)
        pending_paths = MODULE.pending_submission_marker_paths(entries)

        self.assertFalse(any("待人工处理标记" in error for error in source_errors))
        self.assertTrue(any("待人工处理标记" in error for error in final_errors))
        self.assertEqual([MODULE.COMPETITION_NOTICE], pending_paths)

    def test_formal_notice_mode_fails_while_source_audit_stays_available(self) -> None:
        entries = complete_submission_entries()
        entries[MODULE.COMPETITION_NOTICE] = MODULE.PENDING_SUBMISSION_MARKER

        relaxed_output = io.StringIO()
        with mock.patch.object(
            MODULE,
            "submission_entries",
            return_value=(entries, [], "固定源码 manifest"),
        ), mock.patch("sys.stdout", relaxed_output):
            relaxed_exit = MODULE.main([])

        strict_output = io.StringIO()
        with mock.patch.object(
            MODULE,
            "submission_entries",
            return_value=(entries, [], "固定源码 manifest"),
        ), mock.patch("sys.stdout", strict_output):
            strict_exit = MODULE.main(["--require-notice-ready"])

        self.assertEqual(0, relaxed_exit)
        self.assertEqual(1, strict_exit)
        self.assertIn("[UNVERIFIED] 源码 NOTICE 尚未就绪", relaxed_output.getvalue())
        self.assertIn("待人工处理标记", strict_output.getvalue())
        self.assertIn("SOME CHECKS FAILED", strict_output.getvalue())

    def test_manifest_parser_and_selection_accept_explicit_tracked_paths(self) -> None:
        content = manifest_text(["README.md", "apps/web"], ["apps/web/dev-only.txt"])
        include, exclude, parse_errors = MODULE.parse_submission_manifest(content)
        tracked = {"README.md", "apps/web/package.json", "apps/web/dev-only.txt"}
        kinds = {
            "README.md": "file",
            "apps/web": "directory",
            "apps/web/dev-only.txt": "file",
        }

        selected, selection_errors = MODULE.resolve_manifest_selection(
            include,
            exclude,
            tracked,
            kinds.get,
        )

        self.assertEqual([], parse_errors)
        self.assertEqual([], selection_errors)
        self.assertEqual({"README.md", "apps/web/package.json"}, selected)

    def test_manifest_policy_requires_complete_app_roots_and_exact_excludes(self) -> None:
        errors = MODULE.check_manifest_policy(
            ["README.md", "apps/web"],
            ["apps/web/src"],
        )

        self.assertTrue(any("apps/harmonyos" in error for error in errors))
        self.assertTrue(any("未批准路径" in error and "apps/web/src" in error for error in errors))
        self.assertEqual(
            [],
            MODULE.check_manifest_policy(
                sorted(MODULE.REQUIRED_MANIFEST_ROOTS),
                sorted(MODULE.ALLOWED_MANIFEST_EXCLUDES),
            ),
        )

    def test_manifest_rejects_duplicates_overlap_missing_and_untracked(self) -> None:
        duplicate_content = manifest_text(["README.md", "README.md"], [])
        _, _, duplicate_errors = MODULE.parse_submission_manifest(duplicate_content)
        duplicate_exclude_content = manifest_text(["README.md"], ["docs", "docs"])
        _, _, duplicate_exclude_errors = MODULE.parse_submission_manifest(
            duplicate_exclude_content
        )
        tracked = {"README.md", "apps/web/package.json"}
        kinds = {
            "README.md": "file",
            "apps/web": "directory",
            "apps/web/package.json": "file",
            "untracked.txt": "file",
        }
        selected, selection_errors = MODULE.resolve_manifest_selection(
            ["apps/web", "apps/web/package.json", "missing", "untracked.txt"],
            [],
            tracked,
            kinds.get,
        )

        self.assertEqual({"apps/web/package.json"}, selected)
        self.assertTrue(any("重复项" in error for error in duplicate_errors))
        self.assertTrue(any("重复项" in error for error in duplicate_exclude_errors))
        self.assertTrue(any("路径重叠" in error for error in selection_errors))
        self.assertTrue(any("路径不存在: missing" in error for error in selection_errors))
        self.assertTrue(any("未被 Git 跟踪: untracked.txt" in error for error in selection_errors))

    def test_manifest_exclude_cannot_remove_files_outside_include(self) -> None:
        selected, errors = MODULE.resolve_manifest_selection(
            ["README.md"],
            ["apps/web"],
            {"README.md", "apps/web/package.json"},
            {"README.md": "file", "apps/web": "directory"}.get,
        )

        self.assertEqual({"README.md"}, selected)
        self.assertTrue(any("只能剔除 include" in error for error in errors))

    def test_manifest_directory_rejects_tracked_symlink(self) -> None:
        tracked = {"apps/web/package.json", "apps/web/shared-link.ts"}
        kinds = {
            "apps/web": "directory",
            "apps/web/package.json": "file",
            "apps/web/shared-link.ts": "symlink",
        }

        selected, errors = MODULE.resolve_manifest_selection(
            ["apps/web"],
            [],
            tracked,
            kinds.get,
        )

        self.assertEqual(tracked, selected)
        self.assertTrue(any("目录包含符号链接: apps/web/shared-link.ts" in error for error in errors))

    def test_manifest_rejects_untracked_manifest_and_empty_final_set(self) -> None:
        tracking_errors = MODULE.manifest_tracking_errors(set())
        selected, selection_errors = MODULE.resolve_manifest_selection(
            ["README.md"],
            ["README.md"],
            {"README.md"},
            {"README.md": "file"}.get,
        )

        self.assertEqual(set(), selected)
        self.assertTrue(any("manifest 未被 Git 跟踪" in error for error in tracking_errors))
        self.assertTrue(any("不得为空" in error for error in selection_errors))

    def test_gate_source_files_do_not_contain_secret_fixtures(self) -> None:
        entries = {
            "scripts/validate-competition-content.py": SCRIPT_PATH.read_bytes(),
            "scripts/test_validate_competition_content.py": Path(__file__).read_bytes(),
        }

        errors = MODULE.check_submission_package(entries)

        self.assertFalse(any("提交包敏感信息命中" in error for error in errors))
        self.assertEqual([], MODULE.pending_submission_marker_paths(entries))


if __name__ == "__main__":
    unittest.main()
