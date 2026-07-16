import heapq
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
WEB_CS103_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"
CS101_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS101.md"
CS102_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"
CS103_SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"

DIJKSTRA_EDGE_PATTERN = re.compile(
    r"([A-Z])\s*→\s*([A-Z])\s*\(权\s*(\d+)\)"
)
DIJKSTRA_SOURCE_PATTERN = re.compile(r"源点:\s*([A-Z])")
DIJKSTRA_STEP_PATTERN = re.compile(
    r"^\s*\d+\.\s*选\s+([A-Z])\((\d+)\)：([^\n]*)$",
    re.MULTILINE,
)
DIJKSTRA_UPDATE_PATTERN = re.compile(
    r"dist\[([A-Z])\]\s*=\s*min\([^,]+,\s*(\d+)\s*\+\s*(\d+)\)"
)
DIJKSTRA_FINAL_PATTERN = re.compile(r"([A-Z])=(\d+)")


def load_json(path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


def find_activity(experiences, course_id, topic, activity_id):
    experience = find_unique(
        experiences,
        f"{course_id}/{topic} experience",
        lambda item: item.get("courseId") == course_id
        and item.get("topic") == topic,
    )
    return find_unique(
        experience["activities"],
        f"{activity_id} activity",
        lambda item: item.get("id") == activity_id,
    )


def dijkstra_contract_errors(activity):
    prompt = activity["prompt"]
    answer = activity["answer"]
    edge_matches = DIJKSTRA_EDGE_PATTERN.findall(prompt)
    source_matches = DIJKSTRA_SOURCE_PATTERN.findall(prompt)
    errors = []
    if len(source_matches) != 1:
        return [f"expected one source vertex, got {len(source_matches)}"]
    if not edge_matches:
        return ["expected at least one directed weighted edge"]

    source = source_matches[0]
    weights = {}
    vertices = {source}
    adjacency = {}
    for start, end, raw_weight in edge_matches:
        edge = (start, end)
        weight = int(raw_weight)
        if edge in weights:
            errors.append(f"duplicate directed edge {start}→{end}")
            continue
        weights[edge] = weight
        vertices.update(edge)
        adjacency.setdefault(start, []).append((end, weight))

    distances = {vertex: float("inf") for vertex in vertices}
    distances[source] = 0
    queue = [(0, source)]
    while queue:
        distance, vertex = heapq.heappop(queue)
        if distance != distances[vertex]:
            continue
        for neighbor, weight in adjacency.get(vertex, []):
            next_distance = distance + weight
            if next_distance < distances[neighbor]:
                distances[neighbor] = next_distance
                heapq.heappush(queue, (next_distance, neighbor))

    used_edges = set()
    selected_vertices = []
    for vertex, raw_distance, body in DIJKSTRA_STEP_PATTERN.findall(answer):
        selected_vertices.append(vertex)
        selected_distance = int(raw_distance)
        if vertex not in distances:
            errors.append(f"selected unknown vertex {vertex}")
        elif selected_distance != distances[vertex]:
            errors.append(
                f"selected {vertex} at {selected_distance}, expected {distances[vertex]}"
            )
        for target, raw_base, raw_weight in DIJKSTRA_UPDATE_PATTERN.findall(body):
            edge = (vertex, target)
            used_edges.add(edge)
            if edge not in weights:
                errors.append(f"relaxes undeclared directed edge {vertex}→{target}")
                continue
            if int(raw_base) != selected_distance:
                errors.append(
                    f"relaxation {vertex}→{target} starts at {raw_base}, expected {selected_distance}"
                )
            if int(raw_weight) != weights[edge]:
                errors.append(
                    f"relaxation {vertex}→{target} uses weight {raw_weight}, expected {weights[edge]}"
                )

    if len(selected_vertices) != len(vertices) or set(selected_vertices) != vertices:
        errors.append("selection trace must finalize every declared vertex exactly once")
    missing_edges = set(weights) - used_edges
    if missing_edges:
        rendered = ", ".join(
            f"{start}→{end}" for start, end in sorted(missing_edges)
        )
        errors.append(f"selection trace omits outgoing edges: {rendered}")

    final_marker = answer.rfind("最终：")
    if final_marker < 0:
        errors.append("missing final distance line")
        return errors
    final_distances = {
        vertex: int(raw_distance)
        for vertex, raw_distance in DIJKSTRA_FINAL_PATTERN.findall(
            answer[final_marker:]
        )
    }
    expected_distances = {
        vertex: int(distance) for vertex, distance in distances.items()
    }
    if final_distances != expected_distances:
        errors.append(
            f"final distances {final_distances} do not match {expected_distances}"
        )
    return errors


class LessonContentFactsTest(unittest.TestCase):
    def setUp(self):
        self.experiences = load_json(EXPERIENCES_PATH)
        self.knowledge_items = load_json(KNOWLEDGE_PATH)
        self.activity = find_activity(
            self.experiences,
            "cs101",
            "AVL树与红黑树",
            "cs101-AVL树与红黑树-2",
        )
        self.knowledge = find_unique(
            self.knowledge_items,
            "cs101_k20 knowledge chunk",
            lambda item: item.get("id") == "cs101_k20",
        )

    def test_red_black_repair_restores_black_root_after_upward_fix(self):
        root_recolor = "循环结束后将根节点重新着色为黑色，完成修复"
        ordered_steps = [
            self.activity["options"][index]
            for index in self.activity["answerIndexes"]
        ]

        self.assertIn("根为黑", self.knowledge["text"])
        self.assertEqual(root_recolor, ordered_steps[-1])
        self.assertEqual("C → B → E → A → D → F", self.activity["answer"])
        self.assertIn("违反知识切片 cs101_k20 的\"根为黑\"性质", self.activity["feedback"])

    def test_dijkstra_contract_rejects_reversed_relaxation_fixture(self):
        activity = find_activity(
            self.experiences,
            "cs101",
            "最短路径算法",
            "cs101-最短路径算法-1",
        )
        wrong_answer = (
            "1. 选 S(0)：dist[A]=min(∞,0+10)=10, dist[B]=min(∞,0+3)=3。S={S}\n"
            "2. 选 B(3)：dist[A]=min(10,3+4)=7, dist[C]=min(∞,3+2)=5。S={S,B}\n"
            "3. 选 C(5)：dist[A]=min(7,5+1)=6。S={S,B,C}\n"
            "4. 选 A(6)：A 无出边。S={S,B,C,A}\n"
            "5. 最终：S=0, B=3, C=5, A=6"
        )
        fixture = {**activity, "answer": wrong_answer}

        errors = dijkstra_contract_errors(fixture)

        self.assertIn("relaxes undeclared directed edge C→A", errors)
        self.assertTrue(any(error.startswith("selected A at 6") for error in errors))
        self.assertTrue(any(error.startswith("final distances") for error in errors))

    def test_dijkstra_contract_accepts_generated_activity(self):
        activity = find_activity(
            self.experiences,
            "cs101",
            "最短路径算法",
            "cs101-最短路径算法-1",
        )

        self.assertEqual([], dijkstra_contract_errors(activity))
        self.assertIn("最终：S=0, B=3, C=5, A=7", activity["answer"])
        self.assertIn("知识切片 cs101_k27", activity["feedback"])

    def test_red_black_root_step_is_kept_in_the_source_spec(self):
        spec = CS101_SPEC_PATH.read_text(encoding="utf-8")

        self.assertIn(
            '- F. 循环结束后将根节点重新着色为黑色，完成修复',
            spec,
        )
        self.assertIn("- **正确顺序**：C → B → E → A → D → F", spec)

    def test_journal_recovery_orders_crash_before_replay_and_reclaim(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "文件系统",
            "cs102-文件系统-2",
        )
        knowledge = find_unique(
            self.knowledge_items,
            "cs102_k28 knowledge chunk",
            lambda item: item.get("id") == "cs102_k28",
        )
        ordered_steps = [
            activity["options"][index]
            for index in activity["answerIndexes"]
        ]

        self.assertIn("元数据修改先写入日志区域再应用到实际位置", knowledge["text"])
        self.assertIn("日志已提交、尚未 checkpoint 时系统崩溃", activity["prompt"])
        self.assertEqual("B → D → E → C → A → F", activity["answer"])
        self.assertIn("系统崩溃", ordered_steps[3])
        self.assertIn("重放到磁盘实际位置", ordered_steps[4])
        self.assertIn("允许回收对应日志空间", ordered_steps[5])

        spec = CS102_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn("- **正确顺序**：B → D → E → C → A → F", spec)

    def test_udp_encapsulation_uses_protocol_specific_datagram_names(self):
        activity = find_activity(
            self.experiences,
            "cs103",
            "OSI与TCP/IP模型",
            "cs103-OSI与TCP/IP模型-2",
        )
        knowledge = find_unique(
            self.knowledge_items,
            "cs103_k03 knowledge chunk",
            lambda item: item.get("id") == "cs103_k03",
        )

        self.assertIn("添加TCP/UDP首部", knowledge["text"])
        self.assertIn("添加UDP首部", activity["content"])
        self.assertEqual(
            "Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
            activity["answer"],
        )
        self.assertNotIn("DNS使用UDP而非TCP", activity["feedback"])
        self.assertIn("同时支持UDP与TCP", activity["feedback"])
        self.assertIn("RFC 7766", activity["source"])

        spec = CS103_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn(
            "- **答案**：Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
            spec,
        )

    def test_tcp_reno_fast_recovery_inflates_then_deflates_cwnd(self):
        experience = find_unique(
            self.experiences,
            "cs103/TCP流量控制与拥塞控制 experience",
            lambda item: item.get("courseId") == "cs103"
            and item.get("topic") == "TCP流量控制与拥塞控制",
        )
        trace = find_unique(
            experience["activities"],
            "cs103-TCP流量控制与拥塞控制-1 activity",
            lambda item: item.get("id") == "cs103-TCP流量控制与拥塞控制-1",
        )
        ordering = find_unique(
            experience["activities"],
            "cs103-TCP流量控制与拥塞控制-2 activity",
            lambda item: item.get("id") == "cs103-TCP流量控制与拥塞控制-2",
        )
        ordered_steps = [
            ordering["options"][index]
            for index in ordering["answerIndexes"]
        ]

        self.assertIn("cwnd=ssthresh+3 MSS=12 MSS", trace["content"])
        self.assertIn("cwnd=9 MSS", trace["content"])
        self.assertEqual("cwnd=10 MSS，ssthresh=9 MSS", trace["answer"])
        self.assertIn("ssthresh+3 MSS", ordered_steps[2])
        self.assertIn("新ACK到达后，cwnd回落到ssthresh", ordered_steps[3])
        self.assertIn("ssthresh+3 MSS=15 MSS", experience["workedExampleSteps"][2])

        web_source = WEB_CS103_KNOWLEDGE_PATH.read_text(encoding="utf-8")
        for chunk_id in ("cs103_k22", "cs103_k23"):
            chunk = find_unique(
                self.knowledge_items,
                f"{chunk_id} knowledge chunk",
                lambda item, expected=chunk_id: item.get("id") == expected,
            )
            expected_web_fields = (
                f'id: "{chunk_id}",\n'
                f'    text: "{chunk["text"]}",\n'
                f'    source: "{chunk["source"]}"'
            )
            self.assertEqual("RFC 5681", chunk["source"])
            self.assertIn(expected_web_fields, web_source)

        spec = CS103_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn("把cwnd临时设为ssthresh+3 MSS", spec)
        self.assertIn("确认重传数据的新ACK到达时，cwnd回落到ssthresh", spec)


if __name__ == "__main__":
    unittest.main()
