#!/usr/bin/env python3
"""
topic-relations.json 只读校验脚本
检查项：引用完整性、无环、每门课程连通、topic 与知识资产一致，
Course -> Topic -> Lesson -> 互动 -> 聚焦标签测验/本地练习可达
用法：python scripts/validate-topic-relations.py
"""
import json
import sys
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELATIONS_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json"
CHUNKS_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
QUIZZES_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
LESSON_EXPERIENCES_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
COURSE_IDS = {"cs101", "cs102", "cs103"}
ACTIVITY_TYPES = {"code_fill", "step_order", "state_trace", "output_predict"}
INTERACTION_MODES = {"single_choice", "ordered_choice", "free_response"}
ACTIVITY_MODES = {
    "code_fill": {"free_response"},
    "step_order": {"ordered_choice"},
    "state_trace": {"free_response"},
    "output_predict": {"single_choice", "free_response"},
}
MAX_FOCUS_TAG_LENGTH = 12

def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def is_non_empty_string(value):
    return isinstance(value, str) and bool(value.strip())

def utf16_length(value):
    """Match the JavaScript/ArkTS String.length used by the Quiz request path."""
    return len(value.encode("utf-16-le")) // 2

def topic_key(item):
    if not isinstance(item, dict):
        return (None, None)
    return (item.get("courseId"), item.get("topic"))

def check_id_uniqueness(nodes):
    seen = {}
    duplicates = []
    for n in nodes:
        if n["id"] in seen:
            duplicates.append(n["id"])
        seen[n["id"]] = True
    return duplicates

def check_schema(nodes):
    errors = []
    seen_topics = {}
    for index, n in enumerate(nodes):
        prefix = f"node[{index}]"
        if not isinstance(n, dict):
            errors.append(f"{prefix}: must be object")
            continue
        for key in ("id", "courseId", "topic"):
            if not isinstance(n.get(key), str) or not n.get(key).strip():
                errors.append(f'{prefix}: "{key}" must be non-empty string')
        if n.get("courseId") not in COURSE_IDS:
            errors.append(f'{prefix}: unsupported courseId "{n.get("courseId")}"')
        if not isinstance(n.get("level"), int) or n.get("level") < 0:
            errors.append(f'{prefix}: "level" must be non-negative integer')
        prereqs = n.get("prerequisiteIds")
        if not isinstance(prereqs, list) or not all(isinstance(item, str) and item.strip() for item in prereqs):
            errors.append(f'{prefix}: "prerequisiteIds" must be string array')
        elif len(prereqs) != len(set(prereqs)):
            errors.append(f'{prefix}: duplicate prerequisiteIds')
        topic_key = (n.get("courseId"), n.get("topic"))
        if topic_key in seen_topics:
            errors.append(f'{prefix}: duplicate topic "{n.get("topic")}" in {n.get("courseId")}')
        else:
            seen_topics[topic_key] = True
    return errors

def check_reference_integrity(nodes):
    node_map = {n["id"]: n for n in nodes}
    ids = set(node_map)
    errors = []
    for n in nodes:
        for prereq in n.get("prerequisiteIds", []):
            if prereq not in ids:
                errors.append(f'{n["id"]}: prerequisite "{prereq}" not found')
            if prereq == n["id"]:
                errors.append(f'{n["id"]}: self-reference')
            if prereq in node_map and node_map[prereq]["courseId"] != n["courseId"]:
                errors.append(f'{n["id"]}: cross-course prerequisite "{prereq}"')
    return errors

def check_dag(nodes):
    """Kahn's algorithm for cycle detection"""
    adj = {n["id"]: [] for n in nodes}
    in_degree = {n["id"]: 0 for n in nodes}
    for n in nodes:
        for prereq in n.get("prerequisiteIds", []):
            adj[prereq].append(n["id"])
            in_degree[n["id"]] += 1
    queue = deque([nid for nid, d in in_degree.items() if d == 0])
    topo_order = []
    while queue:
        nid = queue.popleft()
        topo_order.append(nid)
        for neighbor in adj[nid]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)
    if len(topo_order) != len(nodes):
        cyclic = [nid for nid, d in in_degree.items() if d > 0]
        return False, cyclic
    return True, topo_order

def check_connectivity(nodes):
    """Check each course forms a connected DAG (reachable from roots)"""
    courses = {}
    for n in nodes:
        cid = n["courseId"]
        if cid not in courses:
            courses[cid] = []
        courses[cid].append(n)
    errors = []
    for cid, course_nodes in courses.items():
        ids = {n["id"] for n in course_nodes}
        adj = {n["id"]: [] for n in course_nodes}
        for n in course_nodes:
            for prereq in n.get("prerequisiteIds", []):
                if prereq in ids:
                    adj[prereq].append(n["id"])
        roots = [n["id"] for n in course_nodes if not n.get("prerequisiteIds")]
        if not roots:
            errors.append(f"{cid}: no root nodes (cycle or missing)")
            continue
        # BFS from all roots
        visited = set()
        queue = deque(roots)
        while queue:
            nid = queue.popleft()
            if nid in visited:
                continue
            visited.add(nid)
            for neighbor in adj[nid]:
                if neighbor not in visited:
                    queue.append(neighbor)
        unreachable = ids - visited
        if unreachable:
            errors.append(f"{cid}: unreachable nodes: {unreachable}")
    return errors

def check_single_root(nodes):
    courses = {}
    for n in nodes:
        cid = n["courseId"]
        if cid not in courses:
            courses[cid] = []
        courses[cid].append(n)
    errors = []
    for cid, course_nodes in courses.items():
        roots = [n["id"] for n in course_nodes if not n.get("prerequisiteIds")]
        if len(roots) != 1:
            errors.append(f"{cid}: expected exactly 1 root, got {len(roots)} ({roots})")
    return errors

def check_level_consistency(nodes):
    """Check level = 0 for roots, level = max(prereq levels) + 1 otherwise"""
    node_map = {n["id"]: n for n in nodes}
    errors = []
    # Topological sort to process in order
    is_dag, topo = check_dag(nodes)
    if not is_dag:
        return ["Cannot check levels: graph has cycles"]
    for nid in topo:
        n = node_map[nid]
        prereqs = n.get("prerequisiteIds", [])
        if not prereqs:
            expected_level = 0
        else:
            expected_level = max(node_map[p]["level"] for p in prereqs) + 1
        if n["level"] != expected_level:
            errors.append(f'{nid}: level={n["level"]}, expected={expected_level}')
    return errors

def check_topic_consistency(nodes, chunks):
    """Check all topics match knowledge-chunks.json"""
    chunk_topics = set()
    for c in chunks:
        chunk_topics.add((c["courseId"], c["topic"]))
    node_topics = {(n["courseId"], n["topic"]) for n in nodes}
    missing_in_chunks = node_topics - chunk_topics
    missing_in_nodes = chunk_topics - node_topics
    errors = []
    if missing_in_chunks:
        for cid, topic in missing_in_chunks:
            errors.append(f'topic "{topic}" ({cid}) in relations but not in chunks')
    if missing_in_nodes:
        for cid, topic in missing_in_nodes:
            errors.append(f'topic "{topic}" ({cid}) in chunks but not in relations')
    return errors

def check_quiz_topic_consistency(nodes, quizzes):
    node_topics = {(n["courseId"], n["topic"]) for n in nodes}
    quiz_topics = {(q["courseId"], q["topic"]) for q in quizzes}
    errors = []
    missing_in_quizzes = node_topics - quiz_topics
    missing_in_nodes = quiz_topics - node_topics
    if missing_in_quizzes:
        for cid, topic in sorted(missing_in_quizzes):
            errors.append(f'topic "{topic}" ({cid}) in relations but not in quizzes')
    if missing_in_nodes:
        for cid, topic in sorted(missing_in_nodes):
            errors.append(f'topic "{topic}" ({cid}) in quizzes but not in relations')
    return errors

def check_lesson_flow_contract(nodes, chunks, quizzes, experiences):
    """Validate every data edge consumed by Lesson, focused Quiz, and Practice."""
    errors = []
    relation_topics = set()
    for node in nodes:
        key = topic_key(node)
        if isinstance(key[0], str) and isinstance(key[1], str):
            relation_topics.add(key)
    chunk_counts = Counter(topic_key(chunk) for chunk in chunks if isinstance(chunk, dict))
    quiz_counts = Counter(topic_key(quiz) for quiz in quizzes if isinstance(quiz, dict))
    quiz_tags_by_topic = {}
    for quiz in quizzes:
        if not isinstance(quiz, dict) or not isinstance(quiz.get("tags"), list):
            continue
        key = topic_key(quiz)
        if key not in quiz_tags_by_topic:
            quiz_tags_by_topic[key] = set()
        for tag in quiz["tags"]:
            if isinstance(tag, str):
                quiz_tags_by_topic[key].add(tag)
    experience_counts = Counter(
        topic_key(experience) for experience in experiences if isinstance(experience, dict)
    )
    activity_ids = {}

    for index, experience in enumerate(experiences):
        prefix = f"lessonExperience[{index}]"
        if not isinstance(experience, dict):
            errors.append(f"{prefix}: must be object")
            continue

        course_id = experience.get("courseId")
        topic = experience.get("topic")
        location = f'{course_id or "<missing-course>"}/{topic or "<missing-topic>"}'
        if experience.get("schemaVersion") != 2 or isinstance(experience.get("schemaVersion"), bool):
            errors.append(f"{prefix} {location}: schemaVersion must be 2")
        if not is_non_empty_string(course_id):
            errors.append(f'{prefix}: "courseId" must be non-empty string')
        elif course_id not in COURSE_IDS:
            errors.append(f'{prefix} {location}: unsupported courseId "{course_id}"')
        if not is_non_empty_string(topic):
            errors.append(f'{prefix}: "topic" must be non-empty string')
        if (course_id, topic) not in relation_topics:
            errors.append(f"{prefix} {location}: Topic not found in topic-relations.json")

        for field in ("visualTitle", "caseTitle", "caseBody", "workedExampleTitle"):
            if not is_non_empty_string(experience.get(field)):
                errors.append(f'{prefix} {location}: "{field}" must be non-empty string')

        visual_steps = experience.get("visualSteps")
        if (not isinstance(visual_steps, list) or not 1 <= len(visual_steps) <= 4 or
                not all(is_non_empty_string(step) for step in visual_steps)):
            errors.append(f'{prefix} {location}: "visualSteps" must contain 1-4 non-empty strings')
        worked_steps = experience.get("workedExampleSteps")
        if (not isinstance(worked_steps, list) or not worked_steps or
                not all(is_non_empty_string(step) for step in worked_steps)):
            errors.append(f'{prefix} {location}: "workedExampleSteps" must contain non-empty strings')

        activities = experience.get("activities")
        if not isinstance(activities, list) or not 1 <= len(activities) <= 2:
            errors.append(f'{prefix} {location}: "activities" must contain 1-2 items')
            continue

        for activity_index, activity in enumerate(activities):
            activity_prefix = f"{prefix}.activities[{activity_index}] {location}"
            if not isinstance(activity, dict):
                errors.append(f"{activity_prefix}: must be object")
                continue

            activity_id = activity.get("id")
            activity_location = f'{activity_prefix}/{activity_id or "<missing-activity>"}'
            if not is_non_empty_string(activity_id):
                errors.append(f'{activity_prefix}: "id" must be non-empty string')
            elif activity_id in activity_ids:
                errors.append(
                    f'{activity_location}: duplicate activity id; first used by {activity_ids[activity_id]}'
                )
            else:
                activity_ids[activity_id] = location

            activity_type = activity.get("type")
            interaction_mode = activity.get("interactionMode")
            if activity_type not in ACTIVITY_TYPES:
                errors.append(f'{activity_location}: unsupported type "{activity_type}"')
            if interaction_mode not in INTERACTION_MODES:
                errors.append(f'{activity_location}: unsupported interactionMode "{interaction_mode}"')
            elif activity_type in ACTIVITY_MODES and interaction_mode not in ACTIVITY_MODES[activity_type]:
                allowed = ", ".join(sorted(ACTIVITY_MODES[activity_type]))
                errors.append(
                    f'{activity_location}: type "{activity_type}" requires interactionMode in [{allowed}]'
                )

            for field in ("title", "focusTag", "prompt", "language", "answer", "feedback", "source"):
                if not is_non_empty_string(activity.get(field)):
                    errors.append(f'{activity_location}: "{field}" must be non-empty string')

            focus_tag = activity.get("focusTag")
            if isinstance(focus_tag, str):
                normalized_focus_tag = focus_tag.strip()
                if focus_tag != normalized_focus_tag or any(char in focus_tag for char in "\r\n\t"):
                    errors.append(f'{activity_location}: focusTag must be exact single-line text')
                if utf16_length(normalized_focus_tag) > MAX_FOCUS_TAG_LENGTH:
                    errors.append(
                        f'{activity_location}: focusTag "{normalized_focus_tag}" exceeds '
                        f'{MAX_FOCUS_TAG_LENGTH} characters'
                    )
                if (normalized_focus_tag and
                        normalized_focus_tag not in quiz_tags_by_topic.get((course_id, topic), set())):
                    errors.append(
                        f'{activity_location}: focusTag "{normalized_focus_tag}" is absent from '
                        "same-Topic curated question tags"
                    )

            options = activity.get("options")
            answer_indexes = activity.get("answerIndexes")
            options_valid = isinstance(options, list) and all(
                is_non_empty_string(option) for option in options
            )
            indexes_valid = isinstance(answer_indexes, list) and all(
                isinstance(answer_index, int) and not isinstance(answer_index, bool)
                for answer_index in answer_indexes
            )
            if not options_valid:
                errors.append(f'{activity_location}: "options" must be an array of non-empty strings')
                options = []
            if not indexes_valid:
                errors.append(f'{activity_location}: "answerIndexes" must be an integer array')
                answer_indexes = []

            if interaction_mode == "single_choice":
                if len(options) < 2:
                    errors.append(f"{activity_location}: single_choice requires at least 2 options")
                if len(answer_indexes) != 1:
                    errors.append(f"{activity_location}: single_choice requires exactly 1 answer index")
                elif answer_indexes[0] < 0 or answer_indexes[0] >= len(options):
                    errors.append(f"{activity_location}: single_choice answer index is out of range")
                elif (is_non_empty_string(activity.get("answer")) and
                      activity["answer"].strip() != options[answer_indexes[0]].strip()):
                    errors.append(f"{activity_location}: answer does not match the indexed option")
            elif interaction_mode == "ordered_choice":
                if len(options) < 2:
                    errors.append(f"{activity_location}: ordered_choice requires at least 2 options")
                if sorted(answer_indexes) != list(range(len(options))):
                    errors.append(
                        f"{activity_location}: ordered_choice answerIndexes must be a permutation of all options"
                    )
            elif interaction_mode == "free_response":
                if options:
                    errors.append(f"{activity_location}: free_response options must be empty")
                if answer_indexes:
                    errors.append(f"{activity_location}: free_response answerIndexes must be empty")

    for course_id, topic in sorted(relation_topics):
        location = f"{course_id}/{topic}"
        experience_count = experience_counts[(course_id, topic)]
        if experience_count != 1:
            errors.append(
                f"{location}: expected exactly 1 lesson experience, got {experience_count}"
            )
        if chunk_counts[(course_id, topic)] < 1:
            errors.append(
                f"{location}: Lesson and focused Quiz are unreachable without a knowledge chunk"
            )
        if quiz_counts[(course_id, topic)] < 1:
            errors.append(
                f"{location}: next-step local Practice is unreachable without a curated question"
            )

    for quiz_index, quiz in enumerate(quizzes):
        if not isinstance(quiz, dict):
            errors.append(f"quiz[{quiz_index}]: must be object")
            continue
        course_id, topic = topic_key(quiz)
        quiz_id = quiz.get("id") or "<missing-question>"
        location = f"quiz[{quiz_index}] {course_id}/{topic}/{quiz_id}"
        tags = quiz.get("tags")
        if not isinstance(tags, list) or not tags:
            errors.append(f'{location}: "tags" must contain at least 1 focus tag')
            continue
        for tag_index, tag in enumerate(tags):
            if not is_non_empty_string(tag):
                errors.append(f"{location}: tags[{tag_index}] must be non-empty string")
            elif tag != tag.strip() or any(char in tag for char in "\r\n\t"):
                errors.append(f"{location}: tags[{tag_index}] must be exact single-line text")
            elif utf16_length(tag) > MAX_FOCUS_TAG_LENGTH:
                errors.append(
                    f"{location}: tag \"{tag}\" exceeds {MAX_FOCUS_TAG_LENGTH} characters"
                )

    return errors

def main():
    nodes = load_json(RELATIONS_PATH)
    chunks = load_json(CHUNKS_PATH)
    quizzes = load_json(QUIZZES_PATH)
    experiences = load_json(LESSON_EXPERIENCES_PATH)
    all_passed = True

    print(f"Loaded {len(nodes)} nodes from topic-relations.json")
    print(f"Loaded {len(chunks)} chunks from knowledge-chunks.json")
    print(f"Loaded {len(quizzes)} questions from quizzes.json")
    print(f"Loaded {len(experiences)} experiences from lesson-experiences.json\n")

    # 0. Schema and course/topic uniqueness
    schema_errors = check_schema(nodes)
    if schema_errors:
        print(f"[FAIL] Schema: {schema_errors}")
        all_passed = False
    else:
        print("[PASS] Schema (required fields, course IDs, levels, unique topics)")

    # 1. ID uniqueness
    dups = check_id_uniqueness(nodes)
    if dups:
        print(f"[FAIL] Duplicate IDs: {dups}")
        all_passed = False
    else:
        print("[PASS] ID uniqueness")

    # 2. Reference integrity
    ref_errors = check_reference_integrity(nodes)
    if ref_errors:
        print(f"[FAIL] Reference integrity: {ref_errors}")
        all_passed = False
    else:
        print("[PASS] Reference integrity (no invalid refs, no self-refs)")

    # 3. DAG (no cycles)
    is_dag, cyclic = check_dag(nodes)
    if not is_dag:
        print(f"[FAIL] Cycle detected involving: {cyclic}")
        all_passed = False
    else:
        print(f"[PASS] DAG (no cycles, topo order length={len(cyclic)})")

    # 4. Connectivity per course
    conn_errors = check_connectivity(nodes)
    if conn_errors:
        print(f"[FAIL] Connectivity: {conn_errors}")
        all_passed = False
    else:
        courses = set(n["courseId"] for n in nodes)
        print(f"[PASS] Connectivity ({len(courses)} courses all connected)")

    # 4b. Single root per course
    root_errors = check_single_root(nodes)
    if root_errors:
        print(f"[FAIL] Single root per course: {root_errors}")
        all_passed = False
    else:
        print("[PASS] Single root per course")

    # 5. Level consistency
    level_errors = check_level_consistency(nodes)
    if level_errors:
        print(f"[FAIL] Level consistency: {level_errors}")
        all_passed = False
    else:
        print("[PASS] Level consistency (level = max(prereq levels) + 1)")

    # 6. Topic consistency with knowledge-chunks.json
    topic_errors = check_topic_consistency(nodes, chunks)
    if topic_errors:
        print(f"[FAIL] Topic consistency: {topic_errors}")
        all_passed = False
    else:
        print("[PASS] Topic consistency with knowledge-chunks.json")

    # 7. Topic consistency with quizzes.json
    quiz_topic_errors = check_quiz_topic_consistency(nodes, quizzes)
    if quiz_topic_errors:
        print(f"[FAIL] Topic consistency with quizzes.json: {quiz_topic_errors}")
        all_passed = False
    else:
        print("[PASS] Topic consistency with quizzes.json")

    # 8. Course -> Topic -> Lesson -> interaction -> focused Quiz / Practice
    lesson_flow_errors = check_lesson_flow_contract(nodes, chunks, quizzes, experiences)
    if lesson_flow_errors:
        print("[FAIL] Lesson flow contract:")
        for error in lesson_flow_errors:
            print(f"  - {error}")
        all_passed = False
    else:
        print("[PASS] Lesson flow contract (Lesson, focused Quiz tag, local Practice)")

    print(f"\n{'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
