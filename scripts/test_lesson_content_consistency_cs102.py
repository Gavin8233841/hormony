import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS102.md"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)

TOPIC_PATTERN = re.compile(r"^## Topic \d+: (.+)$", re.MULTILINE)
ACTIVITY_PATTERN = re.compile(
    r"^### 主动练习 (\d+)（[^）]+）\s*$", re.MULTILINE
)
FIELD_PATTERN = re.compile(r"^- \*\*([^*]+)\*\*：\s*(.*)$")
CHUNK_PATTERN = re.compile(r"cs102_k\d{2}")
EXPECTED_CHUNK_SOURCES = {
    "cs102_k28": (
        "Linux kernel ext4 Journal (JBD2)；"
        "Linux kernel ext4 administration guide；"
        "Btrfs documentation Introduction"
    ),
}


def parse_fields(section: str) -> dict[str, str]:
    fields: dict[str, list[str]] = {}
    current = ""
    for line in section.splitlines():
        match = FIELD_PATTERN.match(line)
        if match:
            current = match.group(1)
            fields[current] = [match.group(2)]
        elif current:
            fields[current].append(line)
    return {key: "\n".join(value).strip() for key, value in fields.items()}


def parse_activities(source: str) -> dict[tuple[str, int], dict[str, str]]:
    topics = list(TOPIC_PATTERN.finditer(source))
    activities: dict[tuple[str, int], dict[str, str]] = {}
    for topic_index, topic_match in enumerate(topics):
        topic = topic_match.group(1).strip()
        topic_end = (
            topics[topic_index + 1].start()
            if topic_index + 1 < len(topics)
            else source.index("\n## 附录", topic_match.start())
        )
        topic_section = source[topic_match.start():topic_end]
        matches = list(ACTIVITY_PATTERN.finditer(topic_section))
        for activity_index, activity_match in enumerate(matches):
            end = (
                matches[activity_index + 1].start()
                if activity_index + 1 < len(matches)
                else len(topic_section)
            )
            number = int(activity_match.group(1))
            body = topic_section[activity_match.end():end]
            fields = parse_fields(body)
            fields["__body__"] = body
            activities[(topic, number)] = fields
    return activities


def step_keys(value: str) -> list[str]:
    return re.findall(r"\b([A-Z])\.", value)


def answer_keys(value: str) -> list[str]:
    return re.findall(r"[A-Z]", value.split("（", 1)[0])


def first_fit_prompt_contract_errors(fields: dict[str, str]) -> list[str]:
    errors: list[str] = []
    prompt = fields.get("题目", "")
    operations = fields.get("操作序列", "")
    if "分配请求序列" not in prompt:
        errors.append("first-fit prompt must describe the allocation-only request sequence")
    if "释放" in prompt and "释放" not in operations:
        errors.append("first-fit prompt claims a release that no operation performs")
    return errors


DMA_REQUIRED_COMPARISON = (
    "与需要 CPU 逐字节搬运数据的程序控制 I/O 相比，"
    "DMA 以块为单位传输，大幅减少 CPU 参与和中断开销"
)
DMA_FORBIDDEN_COMPARISON = "中断驱动 I/O 每传输一个字节中断一次"


def dma_feedback_contract_errors(
    fields: dict[str, str],
    knowledge: dict[str, str],
) -> list[str]:
    errors: list[str] = []
    feedback = fields.get("反馈", "")
    if DMA_REQUIRED_COMPARISON not in feedback:
        errors.append("DMA feedback must compare with CPU-driven programmed I/O")
    if DMA_FORBIDDEN_COMPARISON in feedback:
        errors.append("DMA feedback must not claim byte-granular interrupt-driven I/O")
    if "无需CPU逐字节参与" not in knowledge.get("text", ""):
        errors.append("cs102_k31 must retain the direct-transfer CPU boundary")
    if "传输完成后DMA控制器通过中断通知CPU" not in knowledge.get("text", ""):
        errors.append("cs102_k31 must retain the completion interrupt")
    return errors


EXPECTED_TYPES = {
    ("CPU调度算法", 1): "state_trace",
    ("CPU调度算法", 2): "step_order",
    ("内存管理基础", 1): "state_trace",
    ("内存管理基础", 2): "code_fill",
    ("分段与段页式", 1): "output_predict",
    ("分段与段页式", 2): "state_trace",
    ("文件系统", 1): "code_fill",
    ("文件系统", 2): "step_order",
    ("I/O系统与磁盘调度", 1): "state_trace",
    ("I/O系统与磁盘调度", 2): "step_order",
    ("死锁", 1): "state_trace",
    ("死锁", 2): "code_fill",
    ("同步与互斥", 1): "output_predict",
    ("同步与互斥", 2): "step_order",
    ("进程间通信", 1): "code_fill",
    ("进程间通信", 2): "step_order",
}

EXPECTED_STEP_ORDERS = {
    ("CPU调度算法", 2): ["B", "C", "E", "A", "D"],
    ("文件系统", 2): ["B", "D", "E", "C", "A", "F"],
    ("I/O系统与磁盘调度", 2): ["B", "E", "A", "C", "F", "D"],
    ("同步与互斥", 2): ["B", "F", "D", "E", "A", "C", "G"],
    ("进程间通信", 2): ["B", "C", "E", "G", "A", "F", "D"],
}

EXPECTED_DIRECT_ANSWERS = {
    ("CPU调度算法", 1): (
        "执行序列为 P1(0-2) → P2(2-4) → P3(4-5) → P1(5-7) → "
        "P2(7-8) → P1(8-9)。完成顺序为 P3 → P2 → P1。总完成时间为 "
        "9 个时间单位"
    ),
    ("内存管理基础", 1): "最终空闲分区表为 [50K, 30K, 20K]，总剩余空间 100K",
    ("内存管理基础", 2): "`remaining`",
    ("分段与段页式", 1): (
        "页号 = 1，页内偏移 = 5，物理页框号 = 7，物理地址 = "
        "7 × 4096 + 5 = 28677"
    ),
    ("分段与段页式", 2): "物理地址 = 5100，地址合法（未越界）",
    ("文件系统", 1): "`fat[current]`",
    ("I/O系统与磁盘调度", 1): (
        "磁头移动序列 = 50 → 80 → 120 → 180 → 199 → 0 → 10 → 25。"
        "总寻道距离 = 30+40+60+19+199+10+15 = 373"
    ),
    ("死锁", 1): "不安全状态！试探分配后无法找到安全序列，系统拒绝分配，P1 必须等待",
    ("死锁", 2): "填空1 为 `rec_stack`；填空2 为 `rec_stack[i]`",
    ("进程间通信", 1): "`write(fd[1], msg, sizeof(msg))`",
}


class Cs102LessonContentConsistencyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SPEC_PATH.read_text(encoding="utf-8")
        cls.activities = parse_activities(cls.source)
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.chunks = {item["id"]: item for item in chunks}

    def test_all_sixteen_generated_activities_have_exact_types(self) -> None:
        self.assertEqual(EXPECTED_TYPES, {
            key: fields.get("类型", "")
            for key, fields in self.activities.items()
        })

    def test_every_cited_chunk_exists_and_feedback_citations_are_sourced(self) -> None:
        for key, fields in self.activities.items():
            with self.subTest(activity=key):
                source_ids = set(CHUNK_PATTERN.findall(fields["来源"]))
                mentioned_ids = set()
                for field, value in fields.items():
                    if field not in {"来源", "__body__"}:
                        mentioned_ids.update(CHUNK_PATTERN.findall(value))

                self.assertTrue(source_ids)
                self.assertLessEqual(mentioned_ids, source_ids)
                for chunk_id in source_ids:
                    self.assertIn(chunk_id, self.chunks)
                    self.assertEqual("cs102", self.chunks[chunk_id]["courseId"])
                    self.assertEqual(
                        EXPECTED_CHUNK_SOURCES.get(chunk_id, "操作系统概念"),
                        self.chunks[chunk_id]["source"],
                    )

    def test_step_orders_are_complete_permutations_with_exact_dependencies(self) -> None:
        for key, expected in EXPECTED_STEP_ORDERS.items():
            fields = self.activities[key]
            options = step_keys(fields["打乱步骤"])
            actual = answer_keys(fields["正确顺序"])
            with self.subTest(activity=key):
                self.assertEqual(expected, actual)
                self.assertEqual(len(options), len(set(options)))
                self.assertEqual(set(options), set(actual))

    def test_calculated_and_code_fill_answers_remain_exact(self) -> None:
        for key, expected in EXPECTED_DIRECT_ANSWERS.items():
            with self.subTest(activity=key):
                self.assertEqual(expected, self.activities[key]["答案"])

    def test_corrected_prompts_and_feedback_express_the_proven_semantics(self) -> None:
        contracts = [
            (("CPU调度算法", 2), "题目", "提升发生在该进程已进入 Q2 并执行之后"),
            (("内存管理基础", 1), "题目", "分配请求序列"),
            (("分段与段页式", 2), "反馈", "大于或等于段限长"),
            (("文件系统", 2), "题目", "日志已提交、尚未 checkpoint 时系统崩溃"),
            (("死锁", 2), "题目", "每类资源仅有一个实例的系统中的进程等待图（wait-for graph）"),
            (("死锁", 2), "题目", "有环即存在死锁"),
            (("死锁", 2), "反馈", "环是死锁的充要条件"),
            (("死锁", 2), "反馈", "每类资源可有多个实例"),
            (("同步与互斥", 1), "答案", "消费者可先通过 P(full)"),
            (("同步与互斥", 2), "题目", "本题约定修改共享状态的线程持有同一互斥锁"),
            (("同步与互斥", 2), "打乱步骤", "调用 signal/broadcast 后释放锁"),
            (("同步与互斥", 2), "反馈", "POSIX 允许 signal/broadcast 的调用者不持有"),
            (("同步与互斥", 2), "来源", "POSIX.1-2024 pthread_cond_wait()/pthread_cond_signal()"),
            (("进程间通信", 1), "代码", "#include <stdio.h>"),
            (("进程间通信", 1), "反馈", "当前这次 read 仍会读取管道中已有的消息"),
            (("进程间通信", 2), "题目", "服务器端可观察事件的必然先后依赖"),
            (("进程间通信", 2), "打乱步骤", "accept() 从待处理连接队列取出该连接"),
            (("进程间通信", 2), "打乱步骤", "进入待 accept 的连接队列"),
        ]
        for key, field, fragment in contracts:
            with self.subTest(activity=key, field=field):
                self.assertIn(fragment, self.activities[key][field])

        self.assertNotIn(
            "每传输一个字节中断一次",
            self.activities[("I/O系统与磁盘调度", 2)]["反馈"],
        )
        self.assertNotIn(
            "父进程的 read 会一直阻塞",
            self.activities[("进程间通信", 1)]["反馈"],
        )

    def test_first_fit_prompt_matches_its_allocation_only_operations(self) -> None:
        fields = self.activities[("内存管理基础", 1)]
        self.assertEqual([], first_fit_prompt_contract_errors(fields))

        legacy = {
            **fields,
            "题目": fields["题目"].replace(
                "分配请求序列",
                "分配/释放请求序列",
            ),
        }
        self.assertEqual(
            [
                "first-fit prompt must describe the allocation-only request sequence",
                "first-fit prompt claims a release that no operation performs",
            ],
            first_fit_prompt_contract_errors(legacy),
        )

    def test_dma_feedback_uses_the_proven_cpu_transfer_boundary(self) -> None:
        fields = self.activities[("I/O系统与磁盘调度", 2)]
        knowledge = self.chunks["cs102_k31"]
        self.assertEqual([], dma_feedback_contract_errors(fields, knowledge))

        legacy = {
            **fields,
            "反馈": fields["反馈"].replace(
                DMA_REQUIRED_COMPARISON,
                "与中断驱动 I/O 每传输一个字节中断一次相比，"
                "DMA 以块为单位传输，大幅减少中断次数和 CPU 开销",
            ),
        }
        self.assertEqual(
            [
                "DMA feedback must compare with CPU-driven programmed I/O",
                "DMA feedback must not claim byte-granular interrupt-driven I/O",
            ],
            dma_feedback_contract_errors(legacy, knowledge),
        )


if __name__ == "__main__":
    unittest.main()
