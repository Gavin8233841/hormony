#!/usr/bin/env python3
"""
topic-relations.json 只读校验脚本
检查项：引用完整性、无环、每门课程连通、topic 与知识资产一致
用法：python scripts/validate-topic-relations.py
"""
import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELATIONS_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json"
CHUNKS_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
QUIZZES_PATH = ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
COURSE_IDS = {"cs101", "cs102", "cs103"}

def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

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

def main():
    nodes = load_json(RELATIONS_PATH)
    chunks = load_json(CHUNKS_PATH)
    quizzes = load_json(QUIZZES_PATH)
    all_passed = True

    print(f"Loaded {len(nodes)} nodes from topic-relations.json")
    print(f"Loaded {len(chunks)} chunks from knowledge-chunks.json\n")

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

    print(f"\n{'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
