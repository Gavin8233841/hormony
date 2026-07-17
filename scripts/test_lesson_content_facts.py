import heapq
import json
import os
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
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
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


PIPE_MESSAGE_PATTERN = re.compile(r'char\s+msg\[\]\s*=\s*"([^"]+)";')
PIPE_EXPECTED_STATES = {
    "written_data": ("data", b"hello parent\0"),
    "empty_with_writer": ("would_block", b""),
    "all_writers_closed": ("eof", b""),
}


def read_pipe_state(read_fd):
    try:
        data = os.read(read_fd, 64)
    except BlockingIOError:
        return "would_block", b""
    if data == b"":
        return "eof", data
    return "data", data


def observe_pipe_eof_states(message):
    read_fd = None
    write_fd = None
    try:
        read_fd, write_fd = os.pipe()
        os.set_blocking(read_fd, False)
        os.write(write_fd, message)

        written_data = read_pipe_state(read_fd)
        empty_with_writer = read_pipe_state(read_fd)

        os.close(write_fd)
        write_fd = None
        all_writers_closed = read_pipe_state(read_fd)
        return {
            "written_data": written_data,
            "empty_with_writer": empty_with_writer,
            "all_writers_closed": all_writers_closed,
        }
    finally:
        if read_fd is not None:
            os.close(read_fd)
        if write_fd is not None:
            os.close(write_fd)


def pipe_state_contract_errors(observed_states):
    errors = []
    for phase, expected in PIPE_EXPECTED_STATES.items():
        observed = observed_states.get(phase)
        if observed != expected:
            errors.append(f"{phase}: expected {expected!r}, observed {observed!r}")
    return errors


def pipe_eof_contract_errors(activity):
    errors = []
    message_matches = PIPE_MESSAGE_PATTERN.findall(activity.get("content", ""))
    if len(message_matches) != 1:
        return [f"expected exactly one pipe message, got {len(message_matches)}"]

    prompt = activity.get("prompt", "")
    feedback = activity.get("feedback", "")
    if "子进程写入消息，父进程读取消息" not in prompt:
        errors.append("prompt must establish child-write/parent-read direction")
    if activity.get("answer") != "write(fd[1], msg, sizeof(msg))":
        errors.append("answer must write the complete message through fd[1]")
    if "当前这次 read 仍会读取管道中已有的消息" not in feedback:
        errors.append("feedback must say queued data is readable while a writer is open")
    if "数据耗尽后继续 read 会等待，因为仍有写端打开" not in feedback:
        errors.append("feedback must say an empty pipe with a writer would block")
    if "所有写端关闭后 read 才返回 0（EOF）" not in feedback:
        errors.append("feedback must say closing every writer produces EOF")
    if "缓冲区读空且仍有写端时 read 等待" not in feedback:
        errors.append("feedback must qualify empty-pipe blocking with an open writer")

    message = message_matches[0].encode("utf-8") + b"\0"
    observed_states = observe_pipe_eof_states(message)
    errors.extend(pipe_state_contract_errors(observed_states))
    return errors


SEGMENT_TABLE_ROW_PATTERN = re.compile(
    r"^段号\s+(\d+)：段基址\s*=\s*(-?\d+)，段限长\s*=\s*(\d+)\s*$",
    re.MULTILINE,
)
SEGMENT_LOGICAL_ADDRESS_PATTERN = re.compile(
    r"^逻辑地址：\s*\n段号\s*=\s*(\d+)，段内偏移\s*=\s*(-?\d+)\s*$",
    re.MULTILINE,
)
SEGMENTED_OFFSET_PATTERN = re.compile(
    r"P × 页大小 \+ D = (\d+) × (\d+) \+ (\d+) = (\d+)"
)
SEGMENTED_LIMIT_PATTERN = re.compile(
    r"段限长\s*>\s*(\d+)\s*(?:时|则)地址合法"
)
CS102_KNOWLEDGE_ID_PATTERN = re.compile(r"cs102_k\d{2}")


def parse_segment_activity(activity):
    table = {}
    errors = []
    for raw_segment, raw_base, raw_limit in SEGMENT_TABLE_ROW_PATTERN.findall(
        activity.get("content", "")
    ):
        segment = int(raw_segment)
        if segment in table:
            errors.append(f"duplicate segment table row {segment}")
            continue
        table[segment] = {
            "base": int(raw_base),
            "limit": int(raw_limit),
        }

    logical_matches = SEGMENT_LOGICAL_ADDRESS_PATTERN.findall(
        activity.get("content", "")
    )
    if not table:
        errors.append("segment table must contain at least one row")
    if len(logical_matches) != 1:
        errors.append(
            f"expected exactly one logical address, got {len(logical_matches)}"
        )
        return table, None, None, errors
    segment, offset = (int(value) for value in logical_matches[0])
    return table, segment, offset, errors


def translate_segment_address(table, segment, offset):
    entry = table.get(segment)
    if entry is None or not 0 <= offset < entry["limit"]:
        return {"valid": False, "physical_address": None}
    return {
        "valid": True,
        "physical_address": entry["base"] + offset,
    }


def segment_address_contract_errors(activity, knowledge_items):
    table, segment, offset, errors = parse_segment_activity(activity)
    if segment is None or offset is None:
        return errors

    result = translate_segment_address(table, segment, offset)
    if not result["valid"]:
        errors.append("the generated logical address must be within its segment limit")
    else:
        expected_answer = (
            f"物理地址 = {result['physical_address']}，地址合法（未越界）"
        )
        if activity.get("answer") != expected_answer:
            errors.append(
                f"answer {activity.get('answer')!r} does not match {expected_answer!r}"
            )

    feedback = activity.get("feedback", "")
    if "若段内偏移大于或等于段限长则触发越界异常" not in feedback:
        errors.append("feedback must reject an offset equal to the segment limit")

    knowledge_by_id = {item.get("id"): item for item in knowledge_items}
    source_ids = set(
        CS102_KNOWLEDGE_ID_PATTERN.findall(activity.get("source", ""))
    )
    feedback_ids = set(CS102_KNOWLEDGE_ID_PATTERN.findall(feedback))
    if "cs102_k20" not in feedback_ids:
        errors.append("feedback must cite cs102_k20 for segment base and length")
    if not feedback_ids.issubset(source_ids):
        errors.append("every feedback knowledge citation must appear in source")
    for knowledge_id in source_ids:
        knowledge = knowledge_by_id.get(knowledge_id)
        if knowledge is None:
            errors.append(f"source references missing knowledge chunk {knowledge_id}")
            continue
        if knowledge.get("courseId") != "cs102":
            errors.append(f"{knowledge_id} must belong to cs102")
        if knowledge.get("topic") != "分段与段页式":
            errors.append(f"{knowledge_id} must belong to 分段与段页式")
    return errors


def segment_worked_example_contract_errors(experience):
    steps = [
        step
        for step in experience.get("workedExampleSteps", [])
        if "P × 页大小 + D" in step
    ]
    if len(steps) != 1:
        return [f"expected exactly one segmented offset step, got {len(steps)}"]

    step = steps[0]
    matches = SEGMENTED_OFFSET_PATTERN.findall(step)
    if len(matches) != 1:
        return [f"expected one segmented offset calculation, got {len(matches)}"]
    page, page_size, displacement, rendered_offset = (
        int(value) for value in matches[0]
    )
    offset = page * page_size + displacement
    errors = []
    if offset != rendered_offset:
        errors.append(
            f"rendered offset {rendered_offset} does not match calculated {offset}"
        )
    limit_matches = [int(value) for value in SEGMENTED_LIMIT_PATTERN.findall(step)]
    if limit_matches != [offset]:
        errors.append("worked example must require segment limit greater than offset")
    return errors


SOCKET_STEP_KEYS = ["A", "B", "C", "D", "E", "F", "G"]
SOCKET_REQUIRED_OPTIONS = {
    "A": "服务器的 accept() 从待处理连接队列取出该连接，并返回新套接字",
    "G": "客户端发起的连接到达已监听套接字，并进入待 accept 的连接队列",
}
SOCKET_PROMPT_EVENT_SCOPE = "服务器端可观察事件"
SOCKET_FEEDBACK_CALL_SCOPE = "connect() 调用的起始时刻不参与排序"
SOCKET_POSIX_SOURCE = "POSIX.1-2024 listen()/connect()/accept()"
SOCKET_DEPENDENCIES = [
    ("B", "C"),
    ("C", "E"),
    ("E", "G"),
    ("G", "A"),
    ("A", "F"),
    ("F", "D"),
]


def socket_step_contract_errors(activity):
    errors = []
    if SOCKET_PROMPT_EVENT_SCOPE not in activity.get("prompt", ""):
        errors.append("Socket prompt must scope the order to server-observable events")
    if SOCKET_FEEDBACK_CALL_SCOPE not in activity.get("feedback", ""):
        errors.append("Socket feedback must exclude connect() call start time")
    if SOCKET_POSIX_SOURCE not in activity.get("source", ""):
        errors.append("Socket source must cite the POSIX listen/connect/accept contract")

    options = activity.get("options", [])
    answer_indexes = activity.get("answerIndexes", [])
    if "知识切片 cs102_k48" not in activity.get("source", ""):
        errors.append("Socket activity source must cite cs102_k48")
    if len(options) != len(SOCKET_STEP_KEYS):
        return [
            f"expected {len(SOCKET_STEP_KEYS)} Socket options, got {len(options)}"
        ]
    if len(set(options)) != len(options):
        errors.append("Socket options must not contain duplicates")

    option_by_key = dict(zip(SOCKET_STEP_KEYS, options))
    for key, expected in SOCKET_REQUIRED_OPTIONS.items():
        if option_by_key.get(key) != expected:
            errors.append(
                f"Socket option {key} is {option_by_key.get(key)!r}, expected {expected!r}"
            )

    valid_indexes = set(range(len(options)))
    if (
        len(answer_indexes) != len(options)
        or set(answer_indexes) != valid_indexes
        or len(set(answer_indexes)) != len(answer_indexes)
    ):
        errors.append("answerIndexes must be a complete permutation without duplicates")
        return errors

    ordered_keys = [SOCKET_STEP_KEYS[index] for index in answer_indexes]
    rendered_answer = " → ".join(ordered_keys)
    if activity.get("answer") != rendered_answer:
        errors.append(
            f"answer {activity.get('answer')!r} does not match indexes {rendered_answer!r}"
        )

    positions = {key: index for index, key in enumerate(ordered_keys)}
    for before, after in SOCKET_DEPENDENCIES:
        if positions[before] >= positions[after]:
            errors.append(f"Socket dependency requires {before} before {after}")
    return errors


MLFQ_STEP_KEYS = ["A", "B", "C", "D", "E"]
MLFQ_EXPECTED_OPTIONS = {
    "A": "进程在 Q2（最低优先级队列，时间片最长）中执行",
    "B": "新进程进入最高优先级队列 Q0（时间片最短）",
    "C": "Q0 时间片用完，进程未完成，被降级到 Q1（时间片更长）",
    "D": "定期执行优先级提升（priority boost），将所有进程移回 Q0",
    "E": "Q1 时间片用完，进程仍未完成，被降级到 Q2",
}
MLFQ_DEPENDENCIES = [
    ("B", "C"),
    ("C", "E"),
    ("E", "A"),
    ("A", "D"),
]
MLFQ_BOOST_ASSUMPTION = "本轮优先级提升发生在该进程已进入 Q2 并执行之后"


def mlfq_step_contract_errors(activity, knowledge_items):
    errors = []
    if MLFQ_BOOST_ASSUMPTION not in activity.get("prompt", ""):
        errors.append("prompt must place this priority boost after Q2 execution")

    options = activity.get("options", [])
    answer_indexes = activity.get("answerIndexes", [])
    if len(options) != len(MLFQ_STEP_KEYS):
        return [
            *errors,
            f"expected {len(MLFQ_STEP_KEYS)} MLFQ options, got {len(options)}",
        ]
    if len(set(options)) != len(options):
        errors.append("MLFQ options must not contain duplicates")
    option_by_key = dict(zip(MLFQ_STEP_KEYS, options))
    for key, expected in MLFQ_EXPECTED_OPTIONS.items():
        if option_by_key.get(key) != expected:
            errors.append(
                f"MLFQ option {key} is {option_by_key.get(key)!r}, expected {expected!r}"
            )

    valid_indexes = set(range(len(options)))
    if (
        len(answer_indexes) != len(options)
        or set(answer_indexes) != valid_indexes
        or len(set(answer_indexes)) != len(answer_indexes)
    ):
        errors.append("answerIndexes must be a complete permutation without duplicates")
        return errors

    ordered_keys = [MLFQ_STEP_KEYS[index] for index in answer_indexes]
    rendered_answer = " → ".join(ordered_keys)
    if activity.get("answer") != rendered_answer:
        errors.append(
            f"answer {activity.get('answer')!r} does not match indexes {rendered_answer!r}"
        )
    positions = {key: index for index, key in enumerate(ordered_keys)}
    for before, after in MLFQ_DEPENDENCIES:
        if positions[before] >= positions[after]:
            errors.append(f"MLFQ dependency requires {before} before {after}")

    source_ids = set(
        CS102_KNOWLEDGE_ID_PATTERN.findall(activity.get("source", ""))
    )
    if source_ids != {"cs102_k09"}:
        errors.append("MLFQ source must reference exactly cs102_k09")
    if "cs102_k09" not in activity.get("feedback", ""):
        errors.append("MLFQ feedback must cite cs102_k09")
    knowledge = next(
        (item for item in knowledge_items if item.get("id") == "cs102_k09"),
        None,
    )
    if knowledge is None:
        errors.append("knowledge chunk cs102_k09 must exist")
    elif (
        knowledge.get("courseId") != "cs102"
        or knowledge.get("topic") != "CPU调度算法"
        or knowledge.get("source") != "操作系统概念"
    ):
        errors.append("knowledge chunk cs102_k09 metadata must remain exact")
    return errors


class LessonContentFactsTest(unittest.TestCase):
    def setUp(self):
        self.experiences = load_json(EXPERIENCES_PATH)
        self.knowledge_items = load_json(KNOWLEDGE_PATH)
        self.quizzes = load_json(QUIZZES_PATH)
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

    def test_full_buffer_deadlock_blocks_consumer_after_full_wait(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "同步与互斥",
            "cs102-同步与互斥-1",
        )
        knowledge = find_unique(
            self.knowledge_items,
            "cs102_k42 knowledge chunk",
            lambda item: item.get("id") == "cs102_k42",
        )
        semaphores = {"mutex": 1, "empty": 0, "full": 2}

        def wait(name):
            if semaphores[name] == 0:
                return False
            semaphores[name] -= 1
            return True

        self.assertTrue(wait("mutex"))
        self.assertFalse(wait("empty"))
        self.assertTrue(wait("full"))
        self.assertFalse(wait("mutex"))

        self.assertIn("消费者先P(full)、P(mutex)", knowledge["text"])
        self.assertLess(
            activity["content"].index("P(mutex)"),
            activity["content"].index("P(empty)"),
        )
        self.assertIn("消费者可先通过 P(full)", activity["answer"])
        self.assertIn("随后会阻塞在 P(mutex)", activity["answer"])
        self.assertIn("知识切片 cs102_k34、cs102_k42", activity["source"])

        spec = CS102_SPEC_PATH.read_text(encoding="utf-8")
        self.assertIn("消费者可先通过 P(full)", spec)

    def test_pipe_eof_contract_rejects_static_blocking_myth_fixture(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "进程间通信",
            "cs102-进程间通信-1",
        )
        wrong_states = {
            "written_data": ("would_block", b""),
            "empty_with_writer": ("eof", b""),
            "all_writers_closed": ("would_block", b""),
        }

        errors = pipe_state_contract_errors(wrong_states)

        self.assertTrue(any(error.startswith("written_data:") for error in errors))
        self.assertTrue(
            any(error.startswith("empty_with_writer:") for error in errors)
        )
        self.assertTrue(
            any(error.startswith("all_writers_closed:") for error in errors)
        )

    def test_pipe_eof_contract_accepts_generated_activity_and_os_semantics(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "进程间通信",
            "cs102-进程间通信-1",
        )
        self.assertEqual(
            [],
            pipe_eof_contract_errors(activity),
        )

    def test_segment_limit_contract_accepts_generated_content_and_sources(self):
        experience = find_unique(
            self.experiences,
            "cs102/分段与段页式 experience",
            lambda item: item.get("courseId") == "cs102"
            and item.get("topic") == "分段与段页式",
        )
        activity = find_activity(
            self.experiences,
            "cs102",
            "分段与段页式",
            "cs102-分段与段页式-2",
        )
        quiz = find_unique(
            self.quizzes,
            "cs102_q52 quiz",
            lambda item: item.get("courseId") == "cs102"
            and item.get("topic") == "分段与段页式"
            and item.get("id") == "cs102_q52",
        )

        table, segment, offset, parse_errors = parse_segment_activity(activity)
        self.assertEqual([], parse_errors)
        self.assertEqual(
            {"valid": True, "physical_address": 5100},
            translate_segment_address(table, segment, offset),
        )
        self.assertEqual(
            [],
            segment_address_contract_errors(activity, self.knowledge_items),
        )
        self.assertEqual(
            [],
            segment_worked_example_contract_errors(experience),
        )
        self.assertIn(
            "段内偏移必须严格小于段限长，大于或等于段限长即越界",
            quiz["explanation"],
        )

    def test_segment_limit_contract_rejects_equal_limit_fixtures(self):
        experience = find_unique(
            self.experiences,
            "cs102/分段与段页式 experience",
            lambda item: item.get("courseId") == "cs102"
            and item.get("topic") == "分段与段页式",
        )
        activity = find_activity(
            self.experiences,
            "cs102",
            "分段与段页式",
            "cs102-分段与段页式-2",
        )
        table, segment, _, parse_errors = parse_segment_activity(activity)
        self.assertEqual([], parse_errors)
        limit = table[segment]["limit"]

        self.assertEqual(
            {"valid": False, "physical_address": None},
            translate_segment_address(table, segment, limit),
        )

        wrong_activity = {
            **activity,
            "feedback": activity["feedback"].replace(
                "大于或等于段限长",
                "超过段限长",
            ),
        }
        activity_errors = segment_address_contract_errors(
            wrong_activity,
            self.knowledge_items,
        )
        self.assertIn(
            "feedback must reject an offset equal to the segment limit",
            activity_errors,
        )

        wrong_experience = {
            **experience,
            "workedExampleSteps": [
                step.replace("段限长 > 8202", "段限长 >= 8202")
                for step in experience["workedExampleSteps"]
            ],
        }
        self.assertIn(
            "worked example must require segment limit greater than offset",
            segment_worked_example_contract_errors(wrong_experience),
        )

    def test_socket_step_contract_accepts_generated_dependency_order(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "进程间通信",
            "cs102-进程间通信-2",
        )

        self.assertEqual([], socket_step_contract_errors(activity))
        self.assertEqual(
            ["B", "C", "E", "G", "A", "F", "D"],
            [SOCKET_STEP_KEYS[index] for index in activity["answerIndexes"]],
        )
        self.assertEqual("B → C → E → G → A → F → D", activity["answer"])

    def test_socket_step_contract_rejects_dequeue_before_pending_connection(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "进程间通信",
            "cs102-进程间通信-2",
        )
        wrong_activity = {
            **activity,
            "answerIndexes": [1, 2, 4, 0, 6, 5, 3],
            "answer": "B → C → E → A → G → F → D",
        }

        errors = socket_step_contract_errors(wrong_activity)

        self.assertEqual(
            ["Socket dependency requires G before A"],
            errors,
        )

    def test_socket_step_contract_rejects_connect_call_start_option_fixture(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "进程间通信",
            "cs102-进程间通信-2",
        )
        old_option = "客户端调用 connect() 向服务器发起连接请求"
        wrong_options = list(activity["options"])
        wrong_options[6] = old_option
        wrong_activity = {
            **activity,
            "options": wrong_options,
        }

        self.assertEqual(
            [
                f"Socket option G is {old_option!r}, "
                f"expected {SOCKET_REQUIRED_OPTIONS['G']!r}"
            ],
            socket_step_contract_errors(wrong_activity),
        )

    def test_mlfq_step_contract_accepts_generated_dependency_order(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "CPU调度算法",
            "cs102-CPU调度算法-2",
        )

        self.assertEqual(
            [],
            mlfq_step_contract_errors(activity, self.knowledge_items),
        )
        self.assertEqual(
            ["B", "C", "E", "A", "D"],
            [MLFQ_STEP_KEYS[index] for index in activity["answerIndexes"]],
        )
        self.assertEqual("B → C → E → A → D", activity["answer"])

    def test_mlfq_step_contract_rejects_ambiguous_and_early_boost_fixtures(self):
        activity = find_activity(
            self.experiences,
            "cs102",
            "CPU调度算法",
            "cs102-CPU调度算法-2",
        )
        old_prompt_activity = {
            **activity,
            "prompt": activity["prompt"].replace(
                f"假设{MLFQ_BOOST_ASSUMPTION}，",
                "",
            ),
        }
        early_boost_activity = {
            **activity,
            "answerIndexes": [1, 2, 4, 3, 0],
            "answer": "B → C → E → D → A",
        }

        self.assertEqual(
            ["prompt must place this priority boost after Q2 execution"],
            mlfq_step_contract_errors(
                old_prompt_activity,
                self.knowledge_items,
            ),
        )
        self.assertEqual(
            ["MLFQ dependency requires A before D"],
            mlfq_step_contract_errors(
                early_boost_activity,
                self.knowledge_items,
            ),
        )

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
