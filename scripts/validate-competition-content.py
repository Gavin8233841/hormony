#!/usr/bin/env python3
"""竞赛内容与提交包只读门禁。

默认读取 ``docs/SUBMISSION-SOURCE-MANIFEST.md`` 并展开其中明确列出的
Git 跟踪文件；也可通过 ``--submission-path`` 核对一个明确目录或 ZIP。
脚本不会联网、生成包、解压文件、删除文件或改写数据。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import zipfile
from collections import Counter, defaultdict
from collections.abc import Callable
from datetime import date
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
LEARNING_ROOT = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning"
QUIZZES_PATH = LEARNING_ROOT / "quizzes.json"
KNOWLEDGE_PATH = LEARNING_ROOT / "knowledge-chunks.json"
RESOURCES_PATH = LEARNING_ROOT / "external-resources.json"
LESSONS_PATH = LEARNING_ROOT / "lesson-experiences.json"

EXPECTED_QUIZ_COUNT = 165
EXPECTED_TOPIC_COUNT = 33
EXPECTED_QUESTIONS_PER_TOPIC = 5
EXPECTED_KNOWLEDGE_COUNT = 147
EXPECTED_RESOURCE_COUNT = 36
EXPECTED_LESSON_EXPERIENCE_COUNT = 33
EXPECTED_LESSON_ACTIVITY_COUNT = 59

ANSWER_LABELS = ("A", "B", "C", "D")
ANSWER_SHARE_RANGE = (0.20, 0.30)
DIFFICULTY_LEVELS = ("easy", "medium", "hard")
# docs/QUIZ-DIFFICULTY-AUDIT-CS103.md 明确给出的三级难度建议区间。
DIFFICULTY_SHARE_RANGES = {
    "easy": (0.40, 0.50),
    "medium": (0.35, 0.45),
    "hard": (0.10, 0.20),
}

PROVENANCE_FIELDS = frozenset(
    {
        "sourceTitle",
        "sourceVersion",
        "sourceLocator",
        "sourceUrl",
        "rightsStatus",
        "rightsName",
        "rightsUrl",
        "accessStatus",
        "checkedAt",
        "httpStatus",
    }
)
PROVENANCE_STRING_FIELDS = frozenset(
    {
        "sourceTitle",
        "sourceVersion",
        "sourceLocator",
        "sourceUrl",
        "rightsStatus",
        "rightsName",
        "rightsUrl",
        "accessStatus",
    }
)
RIGHTS_STATUSES = frozenset({"reference-only", "external-link-only", "redistributable"})
ACCESS_STATUSES = frozenset({"reachable", "unreachable", "not-checked"})
PLACEHOLDER_VALUES = frozenset({"TBD", "待确认", "未知", "未核验", "placeholder"})
RESOURCE_TYPES = frozenset({"textbook", "documentation", "course", "standard", "tool"})
ACTIVITY_TYPES = frozenset({"code_fill", "step_order", "state_trace", "output_predict"})
INTERACTION_MODES = frozenset({"single_choice", "ordered_choice", "free_response"})
DISALLOWED_FACT_FRAGMENTS = frozenset(
    {
        "彻底解决了队头阻塞问题",
        "实现了可靠传输、多路复用和前向纠错",
        "实现了可靠传输和前向纠错",
        "HPKP公钥固定进一步增强",
    }
)

SUBMISSION_MANIFEST = "docs/SUBMISSION-SOURCE-MANIFEST.md"
SUBMISSION_MANIFEST_MARKER = "<!-- competition-source-manifest:v1 -->"
COMPETITION_NOTICE = "docs/COMPETITION-NOTICE.md"
PENDING_SUBMISSION_MARKER = b"CHECK-BEFORE-" + b"SUBMISSION"
REQUIRED_SUBMISSION_PATHS = frozenset(
    {
        "README.md",
        "apps/web/package.json",
        "apps/web/pnpm-lock.yaml",
        "apps/harmonyos/build-profile.json5",
        "apps/harmonyos/oh-package.json5",
        "apps/harmonyos/entry/build-profile.json5",
        "apps/harmonyos/entry/src/main/module.json5",
        "apps/harmonyos/entry/src/main/ets/entryability/EntryAbility.ets",
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json",
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json",
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/external-resources.json",
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json",
        "apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json",
        "scripts/generate-learning-activities.mjs",
        "scripts/generate-learning-content-json.mjs",
        "scripts/generate-quizzes-json.mjs",
        COMPETITION_NOTICE,
        SUBMISSION_MANIFEST,
    }
)
REQUIRED_MANIFEST_ROOTS = frozenset({"apps/harmonyos", "apps/web"})
ALLOWED_MANIFEST_EXCLUDES = frozenset(
    {
        "apps/harmonyos/screenshot",
        "apps/web/BACKEND_P1_FIX_DEVLOG.md",
        "apps/web/BACKEND_P2_CLEANUP_DEVLOG.md",
    }
)
FORBIDDEN_DIRECTORY_NAMES = frozenset(
    {
        ".agents",
        ".git",
        ".trae",
        ".tmp",
        ".runtime",
        "node_modules",
        ".pnpm-store",
        ".next",
        "build",
        "dist",
        "out",
        "oh_modules",
        ".hvigor",
        ".cxx",
        ".idea",
        ".vscode",
        "screenshot",
        "screenshots",
        "assets",
        "coverage",
    }
)
FORBIDDEN_FILE_SUFFIXES = frozenset(
    {
        ".app",
        ".cer",
        ".crt",
        ".der",
        ".hap",
        ".hsp",
        ".jks",
        ".key",
        ".keystore",
        ".log",
        ".p12",
        ".pem",
        ".pfx",
        ".zip",
    }
)
FORBIDDEN_FILE_NAMES = frozenset(
    {"local.properties", ".ds_store", "thumbs.db", "desktop.ini", "id_rsa", "id_ed25519"}
)
TEXT_FILE_SUFFIXES = frozenset(
    {
        ".cjs",
        ".css",
        ".ets",
        ".html",
        ".js",
        ".json",
        ".json5",
        ".jsx",
        ".md",
        ".mjs",
        ".ps1",
        ".py",
        ".sh",
        ".ts",
        ".tsx",
        ".txt",
        ".yaml",
        ".yml",
    }
)
MAX_TEXT_SCAN_BYTES = 2 * 1024 * 1024
SECRET_RULES = (
    (
        "private-key-marker",
        re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ),
    (
        "literal-bearer-authorization",
        re.compile(
            rb"\bAuthorization\b\s*[:=]\s*[\"']Bearer [A-Za-z0-9._~+/-]{12,}[\"']",
            re.IGNORECASE,
        ),
    ),
    (
        "literal-server-secret",
        re.compile(
            rb"\b(?:MODEL_API_KEY|VERCEL_TOKEN)\b\s*[:=]\s*[\"'](?!<)[^\"'\r\n]{16,}[\"']"
        ),
    ),
    (
        "unquoted-server-secret",
        re.compile(
            rb"\b(?:MODEL_API_KEY|VERCEL_TOKEN)\b\s*[:=]\s*"
            rb"(?![\"'<$%{])(?!(?:your|replace|example|placeholder|redacted|process\.)\b)"
            rb"[A-Za-z0-9._~+/-]{24,}",
            re.IGNORECASE,
        ),
    ),
    (
        "package-registry-auth-token",
        re.compile(
            rb"\b_authToken\s*=\s*"
            rb"(?![\"'<$%{])"
            rb"(?!(?:your|replace|example|placeholder|redacted)\b)"
            rb"[^\s#;]{12,}",
            re.IGNORECASE,
        ),
    ),
)


def load_json_array(path: Path) -> list[dict[str, object]]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, list):
        raise ValueError(f"{path}: top-level JSON must be an array")
    if not all(isinstance(item, dict) for item in value):
        raise ValueError(f"{path}: every array item must be an object")
    return value


def item_label(item: dict[str, object], index: int) -> str:
    value = item.get("id")
    return value if isinstance(value, str) and value else f"index={index}"


def topic_key(item: dict[str, object]) -> tuple[object, object]:
    return item.get("courseId"), item.get("topic")


def check_quiz_distribution(quizzes: list[dict[str, object]]) -> list[str]:
    errors: list[str] = []
    if len(quizzes) != EXPECTED_QUIZ_COUNT:
        errors.append(f"题库题数应为 {EXPECTED_QUIZ_COUNT}，实际 {len(quizzes)}")

    ids: set[str] = set()
    topic_questions: dict[tuple[object, object], list[dict[str, object]]] = defaultdict(list)
    for index, question in enumerate(quizzes):
        label = item_label(question, index)
        question_id = question.get("id")
        if not isinstance(question_id, str) or not question_id.strip():
            errors.append(f"题目 {label} 缺少非空 id")
        elif question_id in ids:
            errors.append(f"题目 id 重复: {question_id}")
        else:
            ids.add(question_id)

        course_id, topic = topic_key(question)
        if not isinstance(course_id, str) or not course_id.strip():
            errors.append(f"题目 {label} 缺少非空 courseId")
        if not isinstance(topic, str) or not topic.strip():
            errors.append(f"题目 {label} 缺少非空 topic")
        if isinstance(course_id, str) and course_id and isinstance(topic, str) and topic:
            topic_questions[(course_id, topic)].append(question)

        for field in ("question", "explanation"):
            if not non_placeholder_string(question.get(field)):
                errors.append(f"题目 {label}.{field} 必须为非空且非占位字符串")
        errors.extend(check_nonempty_string_list(question.get("tags"), f"题目 {label}.tags"))

        options = question.get("options")
        if not isinstance(options, list) or len(options) != 4:
            errors.append(f"题目 {label} 的 options 必须正好包含 4 项")
        else:
            option_bodies: list[str] = []
            for option_index, option in enumerate(options):
                prefix = f"{ANSWER_LABELS[option_index]}."
                if not isinstance(option, str) or not option.startswith(prefix):
                    errors.append(f"题目 {label} 的第 {option_index + 1} 个选项必须以 {prefix} 开头")
                elif not option[len(prefix):].strip():
                    errors.append(f"题目 {label} 的第 {option_index + 1} 个选项正文不得为空")
                else:
                    option_bodies.append(option[len(prefix):].strip())
            if len(option_bodies) == len(options) and len(set(option_bodies)) != len(option_bodies):
                errors.append(f"题目 {label} 的 4 个选项正文不得重复")

        answer = question.get("answer")
        if answer not in ANSWER_LABELS:
            errors.append(f"题目 {label} 的 answer 必须为 A/B/C/D")
        difficulty = question.get("difficulty")
        if difficulty not in DIFFICULTY_LEVELS:
            errors.append(f"题目 {label} 的 difficulty 必须为 easy/medium/hard")

    if len(topic_questions) != EXPECTED_TOPIC_COUNT:
        errors.append(f"题库 Topic 数应为 {EXPECTED_TOPIC_COUNT}，实际 {len(topic_questions)}")

    for key, questions in sorted(topic_questions.items()):
        course_id, topic = key
        if len(questions) != EXPECTED_QUESTIONS_PER_TOPIC:
            errors.append(
                f"{course_id}/{topic} 应有 {EXPECTED_QUESTIONS_PER_TOPIC} 道题，实际 {len(questions)}"
            )

        answers = {question.get("answer") for question in questions}
        missing_answers = [answer for answer in ANSWER_LABELS if answer not in answers]
        if missing_answers:
            errors.append(
                f"{course_id}/{topic} 的 5 道题未覆盖全部答案位置，缺少 {','.join(missing_answers)}"
            )
        topic_answer_counts = Counter(question.get("answer") for question in questions)
        overused_answers = [
            f"{answer}={topic_answer_counts[answer]}"
            for answer in ANSWER_LABELS
            if topic_answer_counts[answer] > 2
        ]
        if overused_answers:
            errors.append(
                f"{course_id}/{topic} 的单一答案位置不得超过 2 次，实际 {','.join(overused_answers)}"
            )

    answer_counts = Counter(question.get("answer") for question in quizzes)
    difficulty_counts = Counter(question.get("difficulty") for question in quizzes)
    if quizzes:
        answer_minimum, answer_maximum = ANSWER_SHARE_RANGE
        for answer in ANSWER_LABELS:
            share = answer_counts[answer] / len(quizzes)
            if share < answer_minimum or share > answer_maximum:
                errors.append(
                    f"答案 {answer} 占比应在 {answer_minimum:.0%}-{answer_maximum:.0%}，"
                    f"实际 {answer_counts[answer]}/{len(quizzes)} ({share:.1%})"
                )
        for level in DIFFICULTY_LEVELS:
            minimum, maximum = DIFFICULTY_SHARE_RANGES[level]
            share = difficulty_counts[level] / len(quizzes)
            if share < minimum or share > maximum:
                errors.append(
                    f"{level} 占比应在 {minimum:.0%}-{maximum:.0%}，"
                    f"实际 {difficulty_counts[level]}/{len(quizzes)} ({share:.1%})"
                )
    return errors


def quiz_distribution_summary(quizzes: list[dict[str, object]]) -> str:
    answers = Counter(question.get("answer") for question in quizzes)
    difficulties = Counter(question.get("difficulty") for question in quizzes)
    answer_text = ", ".join(f"{label}={answers[label]}" for label in ANSWER_LABELS)
    difficulty_text = ", ".join(f"{level}={difficulties[level]}" for level in DIFFICULTY_LEVELS)
    return f"答案位置: {answer_text}; 难度: {difficulty_text}"


def non_placeholder_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip()) and value.strip() not in PLACEHOLDER_VALUES


def check_nonempty_string_list(
    value: object,
    label: str,
    require_unique: bool = True,
) -> list[str]:
    if not isinstance(value, list) or not value:
        return [f"{label} 必须为非空字符串数组"]
    if not all(non_placeholder_string(item) for item in value):
        return [f"{label} 只能包含非空且非占位字符串"]
    if require_unique and len(set(value)) != len(value):
        return [f"{label} 不得包含重复值"]
    return []


def valid_https_url(value: object) -> bool:
    if not non_placeholder_string(value):
        return False
    parsed = urlsplit(value.strip())
    return parsed.scheme == "https" and bool(parsed.netloc) and not parsed.username and not parsed.password


def valid_iso_date(value: object) -> bool:
    if not isinstance(value, str) or re.fullmatch(r"\d{4}-\d{2}-\d{2}", value) is None:
        return False
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


def check_provenance(item: dict[str, object], label: str) -> list[str]:
    provenance = item.get("provenance")
    if not isinstance(provenance, dict):
        return [f"{label} 缺少对象字段 provenance"]

    errors: list[str] = []
    actual_fields = set(provenance)
    missing_fields = sorted(PROVENANCE_FIELDS - actual_fields)
    unexpected_fields = sorted(actual_fields - PROVENANCE_FIELDS)
    if missing_fields:
        errors.append(f"{label}.provenance 缺少字段: {','.join(missing_fields)}")
    if unexpected_fields:
        errors.append(f"{label}.provenance 包含未定义字段: {','.join(unexpected_fields)}")

    for field in sorted(PROVENANCE_STRING_FIELDS):
        if field in provenance and not non_placeholder_string(provenance[field]):
            errors.append(f"{label}.provenance.{field} 必须为非空且非占位字符串")

    if "sourceUrl" in provenance and not valid_https_url(provenance["sourceUrl"]):
        errors.append(f"{label}.provenance.sourceUrl 必须为不含凭据的 HTTPS URL")
    if "rightsUrl" in provenance and not valid_https_url(provenance["rightsUrl"]):
        errors.append(f"{label}.provenance.rightsUrl 必须为不含凭据的 HTTPS URL")

    rights_status = provenance.get("rightsStatus")
    if rights_status not in RIGHTS_STATUSES:
        errors.append(
            f"{label}.provenance.rightsStatus 必须为 reference-only/external-link-only/redistributable"
        )

    access_status = provenance.get("accessStatus")
    if access_status not in ACCESS_STATUSES:
        errors.append(f"{label}.provenance.accessStatus 必须为 reachable/unreachable/not-checked")
        return errors

    checked_at = provenance.get("checkedAt")
    http_status = provenance.get("httpStatus")
    is_integer_status = isinstance(http_status, int) and not isinstance(http_status, bool)
    if access_status == "reachable":
        if not valid_iso_date(checked_at):
            errors.append(f"{label}.provenance.checkedAt 在 reachable 时必须为 YYYY-MM-DD")
        if not is_integer_status or not 200 <= http_status <= 399:
            errors.append(f"{label}.provenance.httpStatus 在 reachable 时必须为 200-399 整数")
    elif access_status == "unreachable":
        if not valid_iso_date(checked_at):
            errors.append(f"{label}.provenance.checkedAt 在 unreachable 时必须为 YYYY-MM-DD")
        if http_status is not None and (not is_integer_status or not 400 <= http_status <= 599):
            errors.append(f"{label}.provenance.httpStatus 在 unreachable 时必须为 null 或 400-599 整数")
    elif checked_at is not None or http_status is not None:
        errors.append(f"{label}.provenance 在 not-checked 时要求 checkedAt/httpStatus 均为 null")
    return errors


def check_knowledge_provenance(chunks: list[dict[str, object]]) -> list[str]:
    errors: list[str] = []
    if len(chunks) != EXPECTED_KNOWLEDGE_COUNT:
        errors.append(f"知识切片数应为 {EXPECTED_KNOWLEDGE_COUNT}，实际 {len(chunks)}")

    ids: set[str] = set()
    missing_source: list[str] = []
    missing_provenance: list[str] = []
    for index, chunk in enumerate(chunks):
        label = item_label(chunk, index)
        chunk_id = chunk.get("id")
        if not isinstance(chunk_id, str) or not chunk_id.strip():
            errors.append(f"知识切片 {label} 缺少非空 id")
        elif chunk_id in ids:
            errors.append(f"知识切片 id 重复: {chunk_id}")
        else:
            ids.add(chunk_id)

        for field in ("text", "courseId", "topic"):
            if not non_placeholder_string(chunk.get(field)):
                errors.append(f"知识切片 {label}.{field} 必须为非空且非占位字符串")

        source = chunk.get("source")
        if not isinstance(source, str) or not source.strip():
            missing_source.append(label)
        if not isinstance(chunk.get("provenance"), dict):
            missing_provenance.append(label)
        else:
            errors.extend(check_provenance(chunk, f"知识切片 {label}"))

    if missing_source:
        errors.append(f"{len(missing_source)} 条知识切片缺少非空 source: {', '.join(missing_source[:8])}")
    if missing_provenance:
        errors.append(
            f"{len(missing_provenance)} 条知识切片缺少完整 provenance: "
            f"{', '.join(missing_provenance[:8])}"
        )
    return errors


def check_external_resources(resources: list[dict[str, object]]) -> list[str]:
    errors: list[str] = []
    if len(resources) != EXPECTED_RESOURCE_COUNT:
        errors.append(f"外部资源数应为 {EXPECTED_RESOURCE_COUNT}，实际 {len(resources)}")

    ids: set[str] = set()
    urls: set[str] = set()
    missing_provenance: list[str] = []
    for index, resource in enumerate(resources):
        label = item_label(resource, index)
        resource_id = resource.get("id")
        if not isinstance(resource_id, str) or not resource_id.strip():
            errors.append(f"外部资源 {label} 缺少非空 id")
        elif resource_id in ids:
            errors.append(f"外部资源 id 重复: {resource_id}")
        else:
            ids.add(resource_id)

        for field in ("title", "description"):
            if not non_placeholder_string(resource.get(field)):
                errors.append(f"外部资源 {label}.{field} 必须为非空且非占位字符串")
        if "courseId" in resource and not non_placeholder_string(resource.get("courseId")):
            errors.append(f"外部资源 {label}.courseId 出现时必须为非空且非占位字符串")
        errors.extend(
            check_nonempty_string_list(resource.get("tags"), f"外部资源 {label}.tags")
        )

        resource_type = resource.get("type")
        if resource_type not in RESOURCE_TYPES:
            errors.append(f"外部资源 {label} 的 type 不受支持: {resource_type}")

        url = resource.get("url")
        if not isinstance(url, str) or not url.strip():
            errors.append(f"外部资源 {label} 缺少非空 url")
        else:
            parsed = urlsplit(url)
            if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
                errors.append(f"外部资源 {label} 不是不含凭据的 HTTPS URL")
            if url in urls:
                errors.append(f"外部资源 URL 重复: {url}")
            urls.add(url)

        if not isinstance(resource.get("provenance"), dict):
            missing_provenance.append(label)
        else:
            errors.extend(check_provenance(resource, f"外部资源 {label}"))
            if isinstance(url, str) and resource["provenance"].get("sourceUrl") != url:
                errors.append(f"外部资源 {label} 的 url 必须与 provenance.sourceUrl 完全一致")

    if missing_provenance:
        errors.append(
            f"{len(missing_provenance)} 条外部资源缺少完整 provenance: "
            f"{', '.join(missing_provenance[:8])}"
        )
    return errors


def check_lesson_experiences(
    experiences: list[dict[str, object]],
    quizzes: list[dict[str, object]],
) -> list[str]:
    errors: list[str] = []
    if len(experiences) != EXPECTED_LESSON_EXPERIENCE_COUNT:
        errors.append(
            f"Lesson 体验 Topic 数应为 {EXPECTED_LESSON_EXPERIENCE_COUNT}，实际 {len(experiences)}"
        )

    expected_topics = {
        topic_key(question)
        for question in quizzes
        if all(isinstance(value, str) and value for value in topic_key(question))
    }
    actual_topics: set[tuple[object, object]] = set()
    activity_ids: set[str] = set()
    activity_count = 0
    for index, experience in enumerate(experiences):
        course_id, topic = topic_key(experience)
        label = f"Lesson 体验 {course_id}/{topic}" if course_id and topic else f"Lesson 体验 index={index}"
        if experience.get("schemaVersion") != 2:
            errors.append(f"{label} 的 schemaVersion 必须为 2")
        if not isinstance(course_id, str) or not course_id.strip():
            errors.append(f"{label} 缺少非空 courseId")
        if not isinstance(topic, str) or not topic.strip():
            errors.append(f"{label} 缺少非空 topic")
        if isinstance(course_id, str) and course_id and isinstance(topic, str) and topic:
            key = (course_id, topic)
            if key in actual_topics:
                errors.append(f"Lesson 体验 Topic 重复: {course_id}/{topic}")
            actual_topics.add(key)

        for field in ("visualTitle", "caseTitle", "caseBody", "workedExampleTitle"):
            if not non_placeholder_string(experience.get(field)):
                errors.append(f"{label}.{field} 必须为非空且非占位字符串")
        visual_steps = experience.get("visualSteps")
        errors.extend(
            check_nonempty_string_list(
                visual_steps,
                f"{label}.visualSteps",
                require_unique=False,
            )
        )
        if isinstance(visual_steps, list) and len(visual_steps) > 4:
            errors.append(f"{label}.visualSteps 不得超过 4 项")
        errors.extend(
            check_nonempty_string_list(
                experience.get("workedExampleSteps"),
                f"{label}.workedExampleSteps",
                require_unique=False,
            )
        )

        activities = experience.get("activities")
        if not isinstance(activities, list) or not activities:
            errors.append(f"{label} 的 activities 必须为非空数组")
            continue
        if len(activities) > 2:
            errors.append(f"{label} 的 activities 不得超过 2 项")
        for activity_index, activity in enumerate(activities):
            activity_count += 1
            activity_label = f"{label} activity[{activity_index}]"
            if not isinstance(activity, dict):
                errors.append(f"{activity_label} 必须为对象")
                continue
            activity_id = activity.get("id")
            if not isinstance(activity_id, str) or not activity_id.strip():
                errors.append(f"{activity_label} 缺少非空 id")
            elif activity_id in activity_ids:
                errors.append(f"Lesson activity id 重复: {activity_id}")
            else:
                activity_ids.add(activity_id)
            if activity.get("type") not in ACTIVITY_TYPES:
                errors.append(f"{activity_label} 的 type 不受支持: {activity.get('type')}")
            if activity.get("interactionMode") not in INTERACTION_MODES:
                errors.append(
                    f"{activity_label} 的 interactionMode 不受支持: {activity.get('interactionMode')}"
                )
            for field in ("title", "prompt", "language", "answer", "feedback", "source"):
                if not non_placeholder_string(activity.get(field)):
                    errors.append(f"{activity_label}.{field} 必须为非空且非占位字符串")

            options = activity.get("options")
            answer_indexes = activity.get("answerIndexes")
            if not isinstance(options, list):
                errors.append(f"{activity_label}.options 必须为数组")
                continue
            if not isinstance(answer_indexes, list):
                errors.append(f"{activity_label}.answerIndexes 必须为数组")
                continue
            mode = activity.get("interactionMode")
            if mode == "free_response":
                if options or answer_indexes:
                    errors.append(
                        f"{activity_label} 的 free_response 要求 options/answerIndexes 均为空"
                    )
            elif mode == "single_choice":
                errors.extend(check_nonempty_string_list(options, f"{activity_label}.options"))
                valid_index = (
                    len(answer_indexes) == 1
                    and isinstance(answer_indexes[0], int)
                    and not isinstance(answer_indexes[0], bool)
                    and 0 <= answer_indexes[0] < len(options)
                )
                if len(options) < 2 or not valid_index:
                    errors.append(
                        f"{activity_label} 的 single_choice 要求至少 2 个选项和 1 个有效答案索引"
                    )
                elif activity.get("answer") != options[answer_indexes[0]]:
                    errors.append(
                        f"{activity_label} 的 single_choice 标准答案必须等于答案索引指向的选项"
                    )
            elif mode == "ordered_choice":
                errors.extend(check_nonempty_string_list(options, f"{activity_label}.options"))
                valid_indexes = all(
                    isinstance(value, int) and not isinstance(value, bool)
                    for value in answer_indexes
                )
                if (
                    len(options) < 2
                    or len(answer_indexes) != len(options)
                    or not valid_indexes
                    or set(answer_indexes) != set(range(len(options)))
                ):
                    errors.append(
                        f"{activity_label} 的 ordered_choice 要求答案索引完整且不重复"
                    )
                else:
                    expected_answer = " → ".join(
                        chr(ord("A") + value) for value in answer_indexes
                    )
                    if activity.get("answer") != expected_answer:
                        errors.append(
                            f"{activity_label} 的 ordered_choice 标准答案与答案索引不一致"
                        )

    if activity_count != EXPECTED_LESSON_ACTIVITY_COUNT:
        errors.append(
            f"Lesson 活动数应为 {EXPECTED_LESSON_ACTIVITY_COUNT}，实际 {activity_count}"
        )
    missing_topics = sorted(expected_topics - actual_topics)
    unexpected_topics = sorted(actual_topics - expected_topics)
    if missing_topics:
        errors.append(
            f"Lesson 体验缺少题库 Topic {len(missing_topics)} 项: "
            + ", ".join(f"{course}/{topic}" for course, topic in missing_topics[:8])
        )
    if unexpected_topics:
        errors.append(
            f"Lesson 体验包含题库外 Topic {len(unexpected_topics)} 项: "
            + ", ".join(f"{course}/{topic}" for course, topic in unexpected_topics[:8])
        )
    return errors


def nested_strings(value: object):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from nested_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from nested_strings(item)


def check_disallowed_fact_fragments(
    collections: list[tuple[str, list[dict[str, object]]]],
) -> list[str]:
    errors: list[str] = []
    for collection_name, items in collections:
        for index, item in enumerate(items):
            label = item_label(item, index)
            for text_value in nested_strings(item):
                for fragment in DISALLOWED_FACT_FRAGMENTS:
                    if fragment in text_value:
                        errors.append(f"{collection_name} {label} 仍含已纠正失实表述: {fragment}")
    return errors


def external_access_note(resources: list[dict[str, object]]) -> str:
    syntax_valid = 0
    access_counts: Counter[object] = Counter()
    for resource in resources:
        url = resource.get("url")
        if not isinstance(url, str):
            continue
        parsed = urlsplit(url)
        if parsed.scheme == "https" and parsed.netloc and not parsed.username and not parsed.password:
            syntax_valid += 1
        provenance = resource.get("provenance")
        if isinstance(provenance, dict):
            access_counts[provenance.get("accessStatus")] += 1
        else:
            access_counts[None] += 1
    return (
        f"[UNVERIFIED] 外部 URL 实时可达性：HTTPS 语法 {syntax_valid}/{len(resources)}；"
        f"记录状态 reachable={access_counts['reachable']}, unreachable={access_counts['unreachable']}, "
        f"not-checked={access_counts['not-checked']}, missing={access_counts[None]}；"
        "本命令未发起网络请求，不能独立证明当前可用"
    )


def check_topic_alignment(
    knowledge: list[dict[str, object]],
    quizzes: list[dict[str, object]],
) -> list[str]:
    knowledge_topics = {
        topic_key(item)
        for item in knowledge
        if all(isinstance(value, str) and value for value in topic_key(item))
    }
    quiz_topics = {
        topic_key(item)
        for item in quizzes
        if all(isinstance(value, str) and value for value in topic_key(item))
    }
    errors: list[str] = []
    missing = sorted(quiz_topics - knowledge_topics)
    unexpected = sorted(knowledge_topics - quiz_topics)
    if missing:
        errors.append(
            f"知识切片缺少题库 Topic {len(missing)} 项: "
            + ", ".join(f"{course}/{topic}" for course, topic in missing[:8])
        )
    if unexpected:
        errors.append(
            f"知识切片包含题库外 Topic {len(unexpected)} 项: "
            + ", ".join(f"{course}/{topic}" for course, topic in unexpected[:8])
        )
    return errors


def invalid_relative_path_reason(name: str) -> str | None:
    if not name or name.startswith("/") or "\\" in name:
        return "路径不是规范的包内相对路径"
    path = PurePosixPath(name)
    if path.parts and ":" in path.parts[0]:
        return "路径包含 Windows 绝对路径前缀"
    if ".." in path.parts:
        return "路径包含父目录跳转"
    if path.as_posix() != name:
        return "路径不是规范化的仓库相对路径"
    return None


def forbidden_submission_reason(name: str) -> str | None:
    invalid_reason = invalid_relative_path_reason(name)
    if invalid_reason is not None:
        return invalid_reason
    path = PurePosixPath(name)
    blocked = next(
        (part for part in path.parts if part.casefold() in FORBIDDEN_DIRECTORY_NAMES),
        None,
    )
    if blocked is not None:
        return f"包含禁止目录 {blocked}"
    file_name = path.name
    normalized_file_name = file_name.casefold()
    if normalized_file_name.startswith(".env") and normalized_file_name != ".env.example":
        return "包含环境凭证文件"
    if normalized_file_name in FORBIDDEN_FILE_NAMES:
        return f"包含本地配置或系统文件 {file_name}"
    normalized_suffix = path.suffix.casefold()
    if normalized_suffix in FORBIDDEN_FILE_SUFFIXES:
        return f"包含禁止文件类型 {path.suffix}"
    return None


def is_text_entry(name: str) -> bool:
    path = PurePosixPath(name)
    return path.suffix.casefold() in TEXT_FILE_SUFFIXES or path.name.casefold() == ".env.example"


def should_scan_text(name: str, content: bytes | None) -> bool:
    return content is not None and len(content) <= MAX_TEXT_SCAN_BYTES and is_text_entry(name)


def pending_submission_marker_paths(entries: dict[str, bytes | None]) -> list[str]:
    return sorted(
        name
        for name, content in entries.items()
        if content is not None and PENDING_SUBMISSION_MARKER in content
    )


def resolve_package_manifest_selection(
    include: list[str],
    exclude: list[str],
    names: set[str],
) -> tuple[set[str], list[str]]:
    errors: list[str] = []

    def expand(entry: str, section: str) -> set[str]:
        invalid_reason = invalid_relative_path_reason(entry)
        if invalid_reason is not None:
            errors.append(f"manifest.{section} 路径无效: {entry} ({invalid_reason})")
            return set()
        if entry in names:
            return {entry}
        prefix = "" if entry == "." else f"{entry}/"
        matches = {name for name in names if name.startswith(prefix)}
        if section == "include" and not matches:
            errors.append(f"manifest.include 未匹配提交包条目: {entry}")
        return matches

    selected: set[str] = set()
    for entry in include:
        selected.update(expand(entry, "include"))
    for entry in exclude:
        selected.difference_update(expand(entry, "exclude"))

    omitted = sorted(names - selected)
    if omitted:
        errors.append(
            f"提交包包含 manifest 未选择条目 {len(omitted)} 项: {', '.join(omitted[:8])}"
        )
    return selected, errors


def check_submission_package(
    entries: dict[str, bytes | None],
    allow_pending_notice: bool = False,
    expected_names: set[str] | None = None,
    expected_entries: dict[str, bytes | None] | None = None,
) -> list[str]:
    errors: list[str] = []
    names = set(entries)
    if expected_names is not None:
        missing = sorted(expected_names - names)
        unexpected = sorted(names - expected_names)
        if missing:
            errors.append(
                f"提交包缺少 manifest 展开文件 {len(missing)} 项: {', '.join(missing[:8])}"
            )
        if unexpected:
            errors.append(
                f"提交包包含 manifest 外文件 {len(unexpected)} 项: {', '.join(unexpected[:8])}"
            )
    for required in sorted(REQUIRED_SUBMISSION_PATHS):
        if required not in names:
            errors.append(f"提交源码清单缺少: {required}")
        elif entries[required] is None:
            errors.append(f"提交源码清单无法读取: {required}")
        elif not entries[required].strip():
            errors.append(f"提交源码清单为空: {required}")

    if expected_entries is not None:
        for name in sorted(names & set(expected_entries)):
            expected_content = expected_entries[name]
            actual_content = entries[name]
            if expected_content is None or actual_content is None:
                errors.append(f"提交包无法核对 manifest 源文件内容: {name}")
            elif actual_content != expected_content:
                errors.append(f"提交包内容与 manifest 源文件不一致: {name}")

    if SUBMISSION_MANIFEST in names:
        manifest = entries[SUBMISSION_MANIFEST]
        if manifest is None:
            errors.append(f"提交源码清单无法读取: {SUBMISSION_MANIFEST}")
        elif not manifest.strip():
            errors.append(f"提交源码清单为空: {SUBMISSION_MANIFEST}")
        else:
            try:
                manifest_text = manifest.decode("utf-8")
            except UnicodeDecodeError:
                errors.append(f"提交源码清单不是 UTF-8: {SUBMISSION_MANIFEST}")
            else:
                include, exclude, manifest_errors = parse_submission_manifest(manifest_text)
                errors.extend(f"提交包内 {error}" for error in manifest_errors)
                if not manifest_errors:
                    errors.extend(
                        f"提交包内 {error}"
                        for error in check_manifest_policy(include, exclude)
                    )
                    _, selection_errors = resolve_package_manifest_selection(
                        include,
                        exclude,
                        names,
                    )
                    errors.extend(f"提交包内 {error}" for error in selection_errors)

    if COMPETITION_NOTICE in names and entries[COMPETITION_NOTICE] is None:
        errors.append(f"竞赛 NOTICE 无法读取: {COMPETITION_NOTICE}")
    if not allow_pending_notice:
        for name in pending_submission_marker_paths(entries):
            marker = PENDING_SUBMISSION_MARKER.decode("ascii")
            errors.append(f"最终提交包仍含待人工处理标记: {name} ({marker})")

    for name in sorted(names):
        reason = forbidden_submission_reason(name)
        if reason is not None:
            errors.append(f"提交包禁止项: {name} ({reason})")
        content = entries[name]
        if content is None or len(content) > MAX_TEXT_SCAN_BYTES:
            errors.append(f"提交包条目无法完成敏感信息扫描: {name}")
        else:
            for rule_name, rule in SECRET_RULES:
                if rule.search(content):
                    errors.append(f"提交包敏感信息命中: {name} ({rule_name})")
    return errors


def read_small_text_file(path: Path) -> bytes | None:
    try:
        if path.stat().st_size > MAX_TEXT_SCAN_BYTES:
            return None
        return path.read_bytes()
    except OSError:
        return None


def git_tracked_names() -> tuple[set[str], list[str]]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return set(), [f"git ls-files 失败，exit={result.returncode}"]
    names: set[str] = set()
    for raw_name in result.stdout.split(b"\0"):
        if not raw_name:
            continue
        names.add(raw_name.decode("utf-8"))
    return names, []


def parse_submission_manifest(content: str) -> tuple[list[str], list[str], list[str]]:
    errors: list[str] = []
    marker_count = content.count(SUBMISSION_MANIFEST_MARKER)
    if marker_count != 1:
        errors.append(f"manifest 必须且只能包含一个版本标记，实际 {marker_count}")

    pattern = re.compile(
        re.escape(SUBMISSION_MANIFEST_MARKER) + r"\r?\n```json\r?\n(.*?)\r?\n```",
        re.DOTALL,
    )
    matches = pattern.findall(content)
    if len(matches) != 1:
        errors.append("版本标记后必须紧邻一个 json fenced block")
        return [], [], errors

    try:
        document = json.loads(matches[0])
    except json.JSONDecodeError as error:
        errors.append(f"manifest JSON 无效: line={error.lineno}, column={error.colno}")
        return [], [], errors
    if not isinstance(document, dict):
        return [], [], errors + ["manifest JSON 顶层必须为对象"]

    expected_keys = {"include", "exclude"}
    actual_keys = set(document)
    missing_keys = sorted(expected_keys - actual_keys)
    unexpected_keys = sorted(actual_keys - expected_keys)
    if missing_keys:
        errors.append(f"manifest JSON 缺少键: {','.join(missing_keys)}")
    if unexpected_keys:
        errors.append(f"manifest JSON 包含未定义键: {','.join(unexpected_keys)}")

    def path_list(key: str) -> list[str]:
        value = document.get(key)
        if not isinstance(value, list):
            errors.append(f"manifest.{key} 必须为字符串数组")
            return []
        paths: list[str] = []
        for index, item in enumerate(value):
            if not isinstance(item, str) or not item:
                errors.append(f"manifest.{key}[{index}] 必须为非空字符串")
            else:
                paths.append(item)
        duplicates = sorted(path for path, count in Counter(paths).items() if count > 1)
        if duplicates:
            errors.append(f"manifest.{key} 包含重复项: {','.join(duplicates)}")
        return paths

    include = path_list("include")
    exclude = path_list("exclude")
    if not include:
        errors.append("manifest.include 不得为空")
    return include, exclude, errors


def check_manifest_policy(include: list[str], exclude: list[str]) -> list[str]:
    errors: list[str] = []
    missing_roots = sorted(REQUIRED_MANIFEST_ROOTS - set(include))
    if missing_roots:
        errors.append(f"manifest.include 缺少完整应用源码根: {','.join(missing_roots)}")
    unsupported_excludes = sorted(set(exclude) - ALLOWED_MANIFEST_EXCLUDES)
    if unsupported_excludes:
        errors.append(
            f"manifest.exclude 包含未批准路径: {','.join(unsupported_excludes)}"
        )
    return errors


def repository_path_kind(name: str) -> str | None:
    path = ROOT / Path(*PurePosixPath(name).parts)
    if path.is_symlink():
        return "symlink"
    if path.is_file():
        return "file"
    if path.is_dir():
        return "directory"
    return None


def manifest_tracking_errors(tracked_names: set[str]) -> list[str]:
    if SUBMISSION_MANIFEST in tracked_names:
        return []
    return [f"提交源码 manifest 未被 Git 跟踪: {SUBMISSION_MANIFEST}"]


def resolve_manifest_selection(
    include: list[str],
    exclude: list[str],
    tracked_names: set[str],
    path_kind: Callable[[str], str | None],
) -> tuple[set[str], list[str]]:
    errors: list[str] = []

    def expand(entry: str, section: str) -> set[str]:
        invalid_reason = invalid_relative_path_reason(entry)
        if invalid_reason is not None:
            errors.append(f"manifest.{section} 路径无效: {entry} ({invalid_reason})")
            return set()
        kind = path_kind(entry)
        if kind is None:
            errors.append(f"manifest.{section} 路径不存在: {entry}")
            return set()
        if kind == "symlink":
            errors.append(f"manifest.{section} 不得包含符号链接: {entry}")
            return set()
        if kind == "file":
            if entry not in tracked_names:
                errors.append(f"manifest.{section} 文件未被 Git 跟踪: {entry}")
                return set()
            return {entry}
        prefix = "" if entry == "." else f"{entry}/"
        matches = {name for name in tracked_names if name.startswith(prefix)}
        if not matches:
            errors.append(f"manifest.{section} 目录内没有 Git 跟踪文件: {entry}")
        nested_symlinks = sorted(name for name in matches if path_kind(name) == "symlink")
        for name in nested_symlinks:
            errors.append(f"manifest.{section} 目录包含符号链接: {name}")
        return matches

    selected: set[str] = set()
    include_owners: dict[str, str] = {}
    for entry in include:
        expanded = expand(entry, "include")
        overlaps = sorted(expanded & selected)
        if overlaps:
            first_owner = include_owners[overlaps[0]]
            errors.append(
                f"manifest.include 路径重叠: {entry} 与 {first_owner} 同时包含 {overlaps[0]}"
            )
        for name in expanded:
            include_owners.setdefault(name, entry)
        selected.update(expanded)

    for entry in exclude:
        expanded = expand(entry, "exclude")
        outside = sorted(expanded - selected)
        if outside:
            errors.append(
                f"manifest.exclude 只能剔除 include 已展开文件: {entry} 包含未选文件 {outside[0]}"
            )
            continue
        selected.difference_update(expanded)

    if not selected:
        errors.append("manifest 展开并排除后不得为空")
    return selected, errors


def repository_manifest_selection() -> tuple[set[str], list[str]]:
    manifest_path = ROOT / Path(*PurePosixPath(SUBMISSION_MANIFEST).parts)
    if not manifest_path.is_file():
        return set(), [f"提交源码 manifest 不存在: {SUBMISSION_MANIFEST}"]

    tracked_names, errors = git_tracked_names()
    errors.extend(manifest_tracking_errors(tracked_names))
    try:
        content = manifest_path.read_text(encoding="utf-8")
    except OSError as error:
        return set(), errors + [f"无法读取提交源码 manifest: {error}"]

    include, exclude, parse_errors = parse_submission_manifest(content)
    errors.extend(parse_errors)
    errors.extend(check_manifest_policy(include, exclude))
    selected, selection_errors = resolve_manifest_selection(
        include,
        exclude,
        tracked_names,
        repository_path_kind,
    )
    errors.extend(selection_errors)
    return selected, errors


def manifest_submission_entries() -> tuple[dict[str, bytes | None], list[str]]:
    selected, errors = repository_manifest_selection()

    entries: dict[str, bytes | None] = {}
    for name in selected:
        path = ROOT / Path(*PurePosixPath(name).parts)
        entries[name] = read_small_text_file(path)
    return entries, errors


def directory_submission_entries(path: Path) -> tuple[dict[str, bytes | None], list[str]]:
    entries: dict[str, bytes | None] = {}
    errors: list[str] = []
    for item in path.rglob("*"):
        relative = item.relative_to(path).as_posix()
        if item.is_symlink():
            errors.append(f"提交目录包含符号链接: {relative}")
        elif item.is_file():
            entries[relative] = read_small_text_file(item)
    return entries, errors


def zip_submission_entries(path: Path) -> tuple[dict[str, bytes | None], list[str]]:
    entries: dict[str, bytes | None] = {}
    errors: list[str] = []
    try:
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                if info.is_dir():
                    continue
                name = info.filename
                if name in entries:
                    errors.append(f"ZIP 包含重复路径: {name}")
                    continue
                unix_mode = (info.external_attr >> 16) & 0o170000
                if unix_mode == 0o120000:
                    errors.append(f"ZIP 包含符号链接: {name}")
                if info.flag_bits & 0x1:
                    errors.append(f"ZIP 包含加密条目，无法审计: {name}")
                    entries[name] = None
                elif info.file_size <= MAX_TEXT_SCAN_BYTES:
                    entries[name] = archive.read(info)
                else:
                    entries[name] = None
    except (OSError, zipfile.BadZipFile) as error:
        errors.append(f"无法读取 ZIP: {path} ({error})")
    return entries, errors


def submission_entries(path: Path | None) -> tuple[dict[str, bytes | None], list[str], str]:
    if path is None:
        entries, errors = manifest_submission_entries()
        return entries, errors, f"manifest @ {ROOT / SUBMISSION_MANIFEST}"
    resolved = path.resolve()
    if resolved.is_dir():
        entries, errors = directory_submission_entries(resolved)
        return entries, errors, f"目录 @ {resolved}"
    if resolved.is_file() and resolved.suffix == ".zip":
        entries, errors = zip_submission_entries(resolved)
        return entries, errors, f"ZIP @ {resolved}"
    return {}, [f"提交路径必须是现有目录或 .zip 文件: {resolved}"], str(resolved)


def report_check(label: str, errors: list[str], success: str) -> bool:
    if not errors:
        print(f"[PASS] {label}: {success}")
        return True
    print(f"[FAIL] {label}: {len(errors)} 项")
    for error in errors:
        print(f"  - {error}")
    return False


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--submission-path",
        type=Path,
        help=f"明确的源码目录或源码 ZIP；省略时读取 {SUBMISSION_MANIFEST}",
    )
    parser.add_argument(
        "--require-notice-ready",
        action="store_true",
        help="正式发布模式：源码 manifest 中的 NOTICE 仍含待处理标记时失败",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        quizzes = load_json_array(QUIZZES_PATH)
        knowledge = load_json_array(KNOWLEDGE_PATH)
        resources = load_json_array(RESOURCES_PATH)
        lessons = load_json_array(LESSONS_PATH)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"[FAIL] 内容数据读取失败: {error}")
        return 1

    print(
        f"Loaded quizzes={len(quizzes)}, knowledge={len(knowledge)}, "
        f"external-resources={len(resources)}, lesson-experiences={len(lessons)}"
    )
    print(f"[INFO] {quiz_distribution_summary(quizzes)}")

    all_passed = True
    all_passed &= report_check(
        "题库答案位置与难度分布",
        check_quiz_distribution(quizzes),
        "165 道题、33 Topic、答案位置和全局难度分布均满足门禁",
    )
    all_passed &= report_check(
        "知识切片溯源元数据",
        check_knowledge_provenance(knowledge),
        "147 条知识切片具备可核验的结构化溯源元数据",
    )
    all_passed &= report_check(
        "知识与题库 Topic 对齐",
        check_topic_alignment(knowledge, quizzes),
        "知识切片与题库的 33 个 courseId/Topic 集合完全一致",
    )
    all_passed &= report_check(
        "外部资源许可证与访问状态",
        check_external_resources(resources),
        "36 条资源具备许可证与访问状态证据",
    )
    all_passed &= report_check(
        "Lesson 体验完整性",
        check_lesson_experiences(lessons, quizzes),
        "33 个 Topic、59 个活动、唯一 ID 与非空来源均满足门禁",
    )
    all_passed &= report_check(
        "已知失实内容回归",
        check_disallowed_fact_fragments(
            [("知识切片", knowledge), ("Lesson 体验", lessons)]
        ),
        "HTTP/2、QUIC FEC 与 HPKP 的已纠正错误未重新出现",
    )
    print(external_access_note(resources))

    entries, collection_errors, submission_label = submission_entries(args.submission_path)
    manifest_mode = args.submission_path is None
    submission_errors = list(collection_errors)
    expected_names: set[str] | None = None
    expected_entries: dict[str, bytes | None] | None = None
    if not manifest_mode:
        expected_entries, manifest_errors = manifest_submission_entries()
        expected_names = set(expected_entries)
        submission_errors.extend(manifest_errors)
    if entries or not collection_errors:
        submission_errors.extend(
            check_submission_package(
                entries,
                allow_pending_notice=(
                    manifest_mode and not args.require_notice_ready
                ),
                expected_names=expected_names,
                expected_entries=expected_entries,
            )
        )
    all_passed &= report_check(
        "源码提交集合真实性预检",
        submission_errors,
        f"{submission_label} 包含必要源码且不含禁止项或可识别秘密",
    )
    if manifest_mode:
        pending_paths = pending_submission_marker_paths(entries)
        if pending_paths:
            marker = PENDING_SUBMISSION_MARKER.decode("ascii")
            print(
                f"[UNVERIFIED] 源码 NOTICE 尚未就绪：仍含 {marker}: "
                + ", ".join(pending_paths)
            )
        print(
            "[UNVERIFIED] 最终 Demo ZIP：本次只检查 manifest 展开的源码集合；"
            "需用 --submission-path 指向最终目录或 ZIP 后重新执行"
        )
    else:
        print(
            "[UNVERIFIED] 最终 Demo/源码 ZIP：--submission-path 只证明 Git 源码集合逐字一致；"
            "最终包仍须另行核验 HAP、许可证附件、原创/AI 声明和发布证据索引"
        )

    print("\nALL CHECKS PASSED" if all_passed else "\nSOME CHECKS FAILED")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
