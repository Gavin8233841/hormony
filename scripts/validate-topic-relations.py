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

def check_reference_integrity(nodes):
    ids = {n["id"] for n in nodes}
    errors = []
    for n in nodes:
        for prereq in n.get("prerequisiteIds", []):
            if prereq not in ids:
                errors.append(f'{n["id"]}: prerequisite "{prereq}" not found')
            if prereq == n["id"]:
                errors.append(f'{n["id"]}: self-reference')
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

def main():
    nodes = load_json(RELATIONS_PATH)
    chunks = load_json(CHUNKS_PATH)
    all_passed = True

    print(f"Loaded {len(nodes)} nodes from topic-relations.json")
    print(f"Loaded {len(chunks)} chunks from knowledge-chunks.json\n")

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

    print(f"\n{'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
