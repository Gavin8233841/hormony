"""Executable fact contracts for the CS102 deadlock and condition lessons.

Verified references:
- Operating System Concepts, 10th ed., official Chapter 8 slides 11 and 33:
  https://www.os-book.com/OS10/slide-dir/PPTX-dir/ch8.pptx
  A wait-for graph cycle proves deadlock in the explicitly single-instance model;
  a resource-allocation graph cycle with several instances only signals possibility.
- POSIX.1-2024 pthread_cond_wait():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_cond_wait.html
  Waiting atomically releases the mutex; return owns it again; the Boolean
  predicate must be re-evaluated because wakeup does not establish its value.
- POSIX.1-2024 pthread_cond_signal()/pthread_cond_broadcast():
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_cond_broadcast.html
  Woken threads contend to reacquire the mutex; holding it while signaling is
  required when predictable scheduling behavior is needed.
"""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"

TOPIC_PATTERN = re.compile(r"^## Topic \d+: (.+)$", re.MULTILINE)
ACTIVITY_PATTERN = re.compile(
    r"^### 主动练习 (\d+)（[^）]+）\s*$",
    re.MULTILINE,
)
FIELD_PATTERN = re.compile(r"^- \*\*([^*]+)\*\*：\s*(.*)$")
OPTION_PATTERN = re.compile(r"^\s*-\s*([A-Z])\.\s+(.+)$", re.MULTILINE)


def parse_fields(section):
    fields = {}
    current = None
    for line in section.splitlines():
        match = FIELD_PATTERN.match(line)
        if match:
            current = match.group(1)
            fields[current] = [match.group(2)]
        elif current is not None:
            fields[current].append(line)
    return {key: "\n".join(value).strip() for key, value in fields.items()}


def extract_activity(source, topic, number):
    topics = list(TOPIC_PATTERN.finditer(source))
    topic_indexes = [
        index
        for index, match in enumerate(topics)
        if match.group(1).strip() == topic
    ]
    if len(topic_indexes) != 1:
        raise AssertionError(
            f"expected exactly one {topic} topic, got {len(topic_indexes)}"
        )
    topic_index = topic_indexes[0]
    start = topics[topic_index].start()
    if topic_index + 1 < len(topics):
        end = topics[topic_index + 1].start()
    else:
        end = source.index("\n## 附录", start)
    topic_section = source[start:end]

    activities = list(ACTIVITY_PATTERN.finditer(topic_section))
    activity_indexes = [
        index
        for index, match in enumerate(activities)
        if int(match.group(1)) == number
    ]
    if len(activity_indexes) != 1:
        raise AssertionError(
            f"expected exactly one {topic} activity {number}, "
            f"got {len(activity_indexes)}"
        )
    activity_index = activity_indexes[0]
    activity_start = activities[activity_index].end()
    activity_end = (
        activities[activity_index + 1].start()
        if activity_index + 1 < len(activities)
        else len(topic_section)
    )
    return parse_fields(topic_section[activity_start:activity_end])


def cycle_conclusion(single_instance_per_resource):
    return "deadlock" if single_instance_per_resource else "possible_deadlock"


def wait_for_graph_contract_errors(fields):
    errors = []
    prompt = fields.get("题目", "")
    code = fields.get("代码", "")
    answer = fields.get("答案", "")
    feedback = fields.get("反馈", "")
    source = fields.get("来源", "")

    if "进程等待图（wait-for graph）" not in prompt:
        errors.append("prompt must identify the process-only wait-for graph")
    if "资源分配图" in prompt:
        errors.append("a process-only adjacency matrix is not a resource-allocation graph")
    if "graph[i][j]=1 表示进程 i 等待进程 j 持有的资源" not in code:
        errors.append("graph edge must mean process i waits for process j")
    if answer != "填空1 为 `rec_stack`；填空2 为 `rec_stack[i]`":
        errors.append("DFS answer must preserve the current recursion stack")
    if "知识切片 cs102_k34、cs102_k38" not in source:
        errors.append("wait-for graph source must include cs102_k34 and cs102_k38")

    single_instance = (
        "每类资源仅有一个实例的系统中的进程等待图（wait-for graph）" in prompt
    )
    if single_instance:
        if "在该模型下，有环即存在死锁" not in prompt:
            errors.append("single-instance prompt must state the cycle conclusion")
        if (
            "每类资源仅有一个实例的 wait-for 模型中，环是死锁的充要条件"
            not in feedback
        ):
            errors.append("single-instance wait-for cycle must be necessary and sufficient")
    else:
        errors.append("prompt must explicitly limit the wait-for graph to single instances")
        if (
            "有环即存在死锁" in prompt
            or "有环则一定死锁" in feedback
            or "环是死锁的充要条件" in feedback
        ):
            errors.append(
                "cycle is sufficient only under an explicit single-instance model"
            )
    if "若每类资源可有多个实例" not in feedback:
        errors.append("feedback must distinguish the multiple-instance model")
    if not all(term in feedback for term in ("Available", "Allocation", "Request")):
        errors.append("multiple-instance detection must name its required state")
    if "不能把通用资源分配图中的任意环直接判为死锁" not in feedback:
        errors.append("feedback must reject the generic resource-allocation shortcut")
    return errors


CONDITION_OPTIONS = {
    "A": "线程被唤醒后重新获取互斥锁",
    "B": "线程获取互斥锁",
    "C": "线程再次检查条件是否满足（防止虚假唤醒）",
    "D": "条件不满足，线程调用 wait 操作（自动释放互斥锁并阻塞）",
    "E": "另一线程获取同一互斥锁，修改共享状态，调用 signal/broadcast 后释放锁",
    "F": "线程在持有锁的状态下检查条件",
    "G": "条件满足，线程执行后续逻辑并最终释放互斥锁",
}
CONDITION_ORDER = ["B", "F", "D", "E", "A", "C", "G"]


def parse_options(value):
    matches = OPTION_PATTERN.findall(value)
    return {key: text.strip() for key, text in matches}


def parse_order(value):
    return re.findall(r"[A-Z]", value.split("（", 1)[0])


def execute_condition_order(order):
    owner = None
    predicate = False
    waiter_blocked = False
    signaled = False
    errors = []
    for step in order:
        if step == "B":
            if owner is not None:
                errors.append("B: mutex must initially be available")
            owner = "waiter"
        elif step == "F":
            if owner != "waiter":
                errors.append("F: waiter must own mutex while checking predicate")
        elif step == "D":
            if owner != "waiter" or predicate:
                errors.append("D: waiter may wait only while owning mutex and predicate false")
            owner = None
            waiter_blocked = True
        elif step == "E":
            if owner is not None or not waiter_blocked:
                errors.append("E: signaler needs mutex released by the blocked waiter")
            owner = "signaler"
            predicate = True
            signaled = True
            owner = None
        elif step == "A":
            if owner is not None or not waiter_blocked or not signaled:
                errors.append("A: waiter reacquires only after wakeup and mutex release")
            owner = "waiter"
            waiter_blocked = False
        elif step == "C":
            if owner != "waiter":
                errors.append("C: waiter must reacquire mutex before rechecking predicate")
            if not predicate:
                errors.append("C: predicate must be evaluated, not inferred from wakeup")
        elif step == "G":
            if owner != "waiter" or not predicate:
                errors.append("G: waiter proceeds under mutex only when predicate is true")
            owner = None
        else:
            errors.append(f"unknown condition-variable step {step}")
    if owner is not None:
        errors.append("condition-variable flow must finish with mutex released")
    return errors


def condition_variable_contract_errors(fields):
    errors = []
    prompt = fields.get("题目", "")
    if (
        "本题约定修改共享状态的线程持有同一互斥锁，"
        "在 signal/broadcast 后再释放锁"
    ) not in prompt:
        errors.append("prompt must scope the exercise to the locked signaling trace")

    options = parse_options(fields.get("打乱步骤", ""))
    order = parse_order(fields.get("正确顺序", ""))
    if options != CONDITION_OPTIONS:
        errors.append("condition-variable options must preserve mutex and predicate semantics")
    if len(order) != len(CONDITION_OPTIONS) or set(order) != set(CONDITION_OPTIONS):
        errors.append("condition-variable order must be a complete unique permutation")
        return errors
    errors.extend(execute_condition_order(order))

    feedback = fields.get("反馈", "")
    if "wait 操作原子释放锁并阻塞" not in feedback:
        errors.append("feedback must preserve atomic wait release-and-block semantics")
    if "等待线程被解除阻塞后仍需重新获取该互斥锁" not in feedback:
        errors.append("feedback must require mutex reacquisition after wakeup")
    if "随后再次检查条件以处理虚假唤醒" not in feedback:
        errors.append("feedback must require predicate recheck after wakeup")
    if "POSIX 允许 signal/broadcast 的调用者不持有等待者关联的互斥锁" not in feedback:
        errors.append("feedback must preserve POSIX unlocked-signaling allowance")
    if "要求可预测调度时应持锁" not in feedback:
        errors.append("feedback must preserve the predictable-scheduling mutex rule")

    source = fields.get("来源", "")
    if "POSIX.1-2024 pthread_cond_wait()/pthread_cond_signal()" not in source:
        errors.append("condition-variable source must cite POSIX.1-2024")
    if "知识切片 cs102_k41" not in source:
        errors.append("condition-variable source must include cs102_k41")
    return errors


class Cs102ConcurrencyLessonFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = SPEC_PATH.read_text(encoding="utf-8")
        cls.deadlock = extract_activity(source, "死锁", 2)
        cls.condition = extract_activity(source, "同步与互斥", 2)

    def test_cycle_conclusion_changes_with_resource_instance_model(self):
        self.assertEqual("deadlock", cycle_conclusion(True))
        self.assertEqual("possible_deadlock", cycle_conclusion(False))

    def test_current_wait_for_graph_wording_scopes_cycle_to_single_instances(self):
        self.assertEqual([], wait_for_graph_contract_errors(self.deadlock))

    def test_old_graph_name_and_unqualified_cycle_claim_are_rejected(self):
        wrong_graph = {
            **self.deadlock,
            "题目": self.deadlock["题目"].replace(
                "进程等待图（wait-for graph）",
                "资源分配图",
            ),
        }
        wrong_cycle = {
            **self.deadlock,
            "题目": self.deadlock["题目"]
            .replace("每类资源仅有一个实例的系统中的", "")
            .replace("；在该模型下，有环即存在死锁", ""),
            "反馈": self.deadlock["反馈"].replace(
                "在本题明确的每类资源仅有一个实例的 wait-for 模型中，"
                "环是死锁的充要条件",
                "有环则一定死锁",
            ),
        }

        graph_errors = wait_for_graph_contract_errors(wrong_graph)
        self.assertIn(
            "prompt must identify the process-only wait-for graph",
            graph_errors,
        )
        self.assertIn(
            "a process-only adjacency matrix is not a resource-allocation graph",
            graph_errors,
        )
        self.assertIn(
            "cycle is sufficient only under an explicit single-instance model",
            wait_for_graph_contract_errors(wrong_cycle),
        )

    def test_current_condition_flow_executes_with_mutex_and_predicate_invariants(self):
        self.assertEqual([], condition_variable_contract_errors(self.condition))
        self.assertEqual(
            [],
            execute_condition_order(CONDITION_ORDER),
        )

    def test_old_unlocked_update_and_recheck_before_reacquire_are_rejected(self):
        old_option = {
            **self.condition,
            "打乱步骤": self.condition["打乱步骤"].replace(
                CONDITION_OPTIONS["E"],
                "另一线程修改共享状态后调用 signal/broadcast 唤醒等待线程",
            ),
        }
        wrong_order = {
            **self.condition,
            "正确顺序": "B → F → D → E → C → A → G",
        }

        self.assertIn(
            "condition-variable options must preserve mutex and predicate semantics",
            condition_variable_contract_errors(old_option),
        )
        self.assertIn(
            "C: waiter must reacquire mutex before rechecking predicate",
            condition_variable_contract_errors(wrong_order),
        )


if __name__ == "__main__":
    unittest.main()
