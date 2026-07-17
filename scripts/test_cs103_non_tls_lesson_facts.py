"""Executable RFC contracts for non-TLS CS103 lesson activities.

Verified primary references:
- RFC 5681 Sections 3.1 and 4.2:
  https://www.rfc-editor.org/rfc/rfc5681.html#section-3.1
  https://www.rfc-editor.org/rfc/rfc5681.html#section-4.2
  Slow start grows cwnd per ACK that acknowledges new data. Receivers may use
  delayed ACKs, so exact doubling per RTT needs an explicit ACK-schedule premise.
- RFC 2328 Sections 7.2, 10.1, and 16:
  https://www.rfc-editor.org/rfc/rfc2328.html#section-7.2
  https://www.rfc-editor.org/rfc/rfc2328.html#section-10.1
  https://www.rfc-editor.org/rfc/rfc2328.html#section-16
  An adjacency participates in flooding as soon as Database Exchange begins;
  flooding is not a phase that necessarily starts after database synchronization.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"

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
    selected_topics = [
        index
        for index, match in enumerate(topics)
        if match.group(1).strip() == topic
    ]
    if len(selected_topics) != 1:
        raise AssertionError(
            f"expected exactly one {topic} topic, got {len(selected_topics)}"
        )

    topic_index = selected_topics[0]
    topic_start = topics[topic_index].start()
    topic_end = (
        topics[topic_index + 1].start()
        if topic_index + 1 < len(topics)
        else len(source)
    )
    topic_section = source[topic_start:topic_end]

    activities = list(ACTIVITY_PATTERN.finditer(topic_section))
    selected_activities = [
        index
        for index, match in enumerate(activities)
        if int(match.group(1)) == number
    ]
    if len(selected_activities) != 1:
        raise AssertionError(
            f"expected exactly one {topic} activity {number}, "
            f"got {len(selected_activities)}"
        )

    activity_index = selected_activities[0]
    activity_start = activities[activity_index].end()
    activity_end = (
        activities[activity_index + 1].start()
        if activity_index + 1 < len(activities)
        else len(topic_section)
    )
    return parse_fields(topic_section[activity_start:activity_end])


def extract_web_chunk(source, chunk_id):
    pattern = re.compile(
        r'\{\s*id: "' + re.escape(chunk_id)
        + r'",\s*text: ("(?:\\.|[^"\\])*")'
        + r',\s*source: ("(?:\\.|[^"\\])*")',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web knowledge chunk for {chunk_id!r}, got {len(matches)}"
        )
    text_literal, source_literal = matches[0]
    return json.loads(text_literal), json.loads(source_literal)


def find_json_item(items, item_id):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(f"expected one item for {item_id!r}, got {len(matches)}")
    return matches[0]


RENO_ACK_PREMISE = (
    "本题固定确认与离散更新规则：每个满尺寸报文段都由一个确认新数据的ACK"
    "单独确认，不使用延迟ACK；慢启动每轮按ACK增长，拥塞避免每完成一轮窗口"
    "数据后将cwnd增加1 MSS"
)
RENO_RFC_EXPLANATION = (
    "RFC 5681第3.1节按确认新数据的ACK增加cwnd；第4.2节允许延迟ACK，"
    "因此每RTT翻倍不是无条件保证"
)
RENO_SOURCE = (
    "RFC 5681第3.1节（Slow Start and Congestion Avoidance）、"
    "第3.2节（Fast Retransmit/Fast Recovery）、"
    "第4.2节（Generating Acknowledgments）"
)


def reno_ack_schedule_contract_errors(fields):
    errors = []
    prompt = fields.get("题目", "")
    feedback = fields.get("反馈", "")
    source = fields.get("来源", "")

    if RENO_ACK_PREMISE not in prompt:
        errors.append("prompt must fix the per-segment ACK schedule")
    if RENO_RFC_EXPLANATION not in feedback:
        errors.append("feedback must distinguish ACK-driven growth from an RTT guarantee")
    if RENO_SOURCE not in source:
        errors.append("source must cite RFC 5681 Sections 3.1 and 4.2")
    return errors


def slow_start_after_ack_count(cwnd_mss, ack_count):
    """Apply RFC 5681's at-most-one-SMSS increase for each new-data ACK."""
    if cwnd_mss < 1 or ack_count < 0:
        raise ValueError("cwnd must be positive and ACK count must be non-negative")
    return cwnd_mss + ack_count


OSPF_PROMPT_SCOPE = (
    "题设假定拓扑在本轮同步期间保持稳定，并明确等待相邻路由器达到Full后"
    "再执行一次路由计算"
)
OSPF_REQUIRED_OPTIONS = {
    "A": "进入ExStart，协商主从关系和初始DD序列号",
    "B": "Hello协议发现邻居并确认双向通信",
    "C": (
        "进入Exchange并交换DBD摘要；邻接从Database Exchange开始即参与"
        "LSA泛洪"
    ),
    "D": (
        "Exchange中建立请求列表并可发送LSR；未清空则进入Loading继续请求，"
        "接收LSU直至列表清空后到达Full"
    ),
    "E": "按题设等待Full后，以当前区域LSDB为输入运行Dijkstra并生成路由表",
}
OSPF_ORDER = ["B", "A", "C", "D", "E"]
OSPF_FEEDBACK_OVERLAP = "泛洪不是“LSDB完整同步之后才开始”的独立后续阶段"
OSPF_SOURCE = (
    "RFC 2328第7.2节（The Synchronization of Databases）、"
    "第10.1节（Neighbor states）、"
    "第16节（Calculation of the routing table）"
)

KNOWLEDGE_CONTRACTS = {
    "cs103_k20": {
        "source": "计算机网络：自顶向下方法；RFC 5681第3.1节、第4.2节",
        "required": (
            "每个累计确认新数据的ACK增加cwnd",
            "每个ACK至多增加1 SMSS",
            "接收方使用延迟ACK时，精确RTT序列会不同",
            "翻倍不是脱离确认策略的时钟保证",
            "ssthresh按FlightSize的一半计算",
        ),
        "forbidden": (
            "每收到一个ACK，cwnd加1，使得每经过一个RTT，cwnd翻倍",
            "ssthresh设为当前cwnd的一半",
        ),
    },
    "cs103_k21": {
        "source": "计算机网络：自顶向下方法；RFC 5681第3.1节、第3.2节",
        "required": (
            "ACK驱动的近似线性过程",
            "cwnd += SMSS*SMSS/cwnd",
            "精确变化仍取决于ACK到达和实现的字节计数",
            "ssthresh同样基于FlightSize",
            "cwnd暂时设为ssthresh+3 SMSS",
        ),
        "forbidden": (
            "每个RTT增加1个MSS（即每收到一个ACK",
            "ssthresh设为cwnd的一半但cwnd不重置为1",
        ),
    },
    "cs103_k42": {
        "source": (
            "计算机网络：自顶向下方法；RFC 2328第7.2节、第10.1节、"
            "第16节"
        ),
        "required": (
            "邻接从Database Exchange开始就参与LSA泛洪",
            "Exchange形成需要补齐的LSA请求列表并可发送LSR",
            "列表未清空时进入Loading继续请求",
            "接收LSU直至清空后到达Full",
            "以区域链路状态数据库（LSDB）为输入运行Dijkstra算法",
        ),
        "forbidden": (
            "完成LSDB的完整同步后再泛洪",
            "邻接只有到达Full后才参与LSA泛洪",
        ),
    },
}

QUIZ_CONTRACTS = {
    "cs103_q35": {
        "question": "发送方持续有数据且ACK正常返回时，TCP慢开始阶段cwnd的典型增长形态是？",
        "option": "B. ACK驱动的指数增长；逐段确认时一轮可近似翻倍",
        "required": (
            "慢开始按累计确认新数据的ACK增加cwnd",
            "RFC 5681允许延迟ACK",
            "不能把翻倍写成与ACK无关的时钟规则",
        ),
        "forbidden": "每经过一个 RTT 翻倍（指数增长）",
    },
    "cs103_q36": {
        "required": (
            "按FlightSize计算ssthresh",
            "cwnd暂时设为ssthresh+3 SMSS进入快恢复",
            "确认重传数据的新ACK到达后，cwnd才回落到ssthresh",
        ),
        "forbidden": "cwnd 设为 ssthresh 后线性增长",
    },
    "cs103_q37": {
        "option": "A. 出现拥塞信号后，将窗口控制量缩减到约一半",
        "required": (
            "ssthresh按FlightSize的一半计算",
            "第3个重复ACK进入快恢复时cwnd暂时为ssthresh+3 SMSS",
            "不能把所有路径都简化为立即把当前cwnd直接减半",
        ),
        "forbidden": "乘性减指检测到拥塞时将 cwnd 减半",
    },
}


def ospf_exchange_contract_errors(fields):
    errors = []
    prompt = fields.get("题目", "")
    options = dict(OPTION_PATTERN.findall(fields.get("打乱步骤", "")))
    answer = fields.get("正确顺序", "")
    feedback = fields.get("反馈", "")
    source = fields.get("来源", "")

    if OSPF_PROMPT_SCOPE not in prompt:
        errors.append("prompt must freeze topology and explicitly defer SPF until Full")
    if set(options) != set(OSPF_REQUIRED_OPTIONS):
        errors.append("OSPF options must contain each key A-E exactly once")
    else:
        for key, expected in OSPF_REQUIRED_OPTIONS.items():
            if options[key] != expected:
                errors.append(
                    f"OSPF option {key} is {options[key]!r}, expected {expected!r}"
                )
    expected_answer = " → ".join(OSPF_ORDER)
    if answer != expected_answer:
        errors.append(
            f"OSPF answer is {answer!r}, expected {expected_answer!r}"
        )
    if OSPF_FEEDBACK_OVERLAP not in feedback:
        errors.append("feedback must reject post-synchronization-only flooding")
    if OSPF_SOURCE not in source:
        errors.append("source must cite RFC 2328 Sections 7.2, 10.1, and 16")
    return errors


def fixed_reno_fixture():
    return {
        "题目": (
            f"{RENO_ACK_PREMISE}。一个TCP Reno连接从cwnd=1 MSS开始，"
            "请推演窗口变化"
        ),
        "反馈": RENO_RFC_EXPLANATION,
        "来源": f"{RENO_SOURCE}；知识切片 cs103_k20",
    }


def fixed_ospf_fixture():
    options = "\n".join(
        f"  - {key}. {OSPF_REQUIRED_OPTIONS[key]}" for key in "ABCDE"
    )
    return {
        "题目": f"{OSPF_PROMPT_SCOPE}。请排列事件",
        "打乱步骤": options,
        "正确顺序": " → ".join(OSPF_ORDER),
        "反馈": OSPF_FEEDBACK_OVERLAP,
        "来源": f"{OSPF_SOURCE}；知识切片 cs103_k42",
    }


class Cs103NonTlsLessonFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = SPEC_PATH.read_text(encoding="utf-8")
        cls.reno_trace = extract_activity(
            source,
            "TCP流量控制与拥塞控制",
            1,
        )
        cls.reno_order = extract_activity(
            source,
            "TCP流量控制与拥塞控制",
            2,
        )
        cls.ospf_order = extract_activity(source, "路由算法与协议", 2)

    def test_reno_activities_fix_the_ack_schedule_for_exact_rtt_growth(self):
        for fields in (self.reno_trace, self.reno_order):
            with self.subTest(activity=fields.get("类型")):
                self.assertEqual([], reno_ack_schedule_contract_errors(fields))

    def test_reno_contract_accepts_fixed_ack_fixture(self):
        self.assertEqual(
            [],
            reno_ack_schedule_contract_errors(fixed_reno_fixture()),
        )

    def test_reno_contract_rejects_unqualified_rtt_doubling_fixture(self):
        legacy = {
            "题目": "TCP Reno的cwnd从1开始，每经过一个RTT翻倍",
            "反馈": "慢启动阶段每个RTT都会将cwnd精确翻倍",
            "来源": "RFC 5681第3.2节",
        }

        self.assertEqual(
            [
                "prompt must fix the per-segment ACK schedule",
                "feedback must distinguish ACK-driven growth from an RTT guarantee",
                "source must cite RFC 5681 Sections 3.1 and 4.2",
            ],
            reno_ack_schedule_contract_errors(legacy),
        )

    def test_delayed_ack_fixed_input_disproves_unconditional_doubling(self):
        after_first_rtt = slow_start_after_ack_count(cwnd_mss=1, ack_count=1)
        after_second_rtt = slow_start_after_ack_count(
            cwnd_mss=after_first_rtt,
            ack_count=1,
        )

        self.assertEqual(2, after_first_rtt)
        self.assertEqual(3, after_second_rtt)
        self.assertNotEqual(4, after_second_rtt)

    def test_ospf_activity_does_not_order_flooding_after_full_sync(self):
        self.assertEqual([], ospf_exchange_contract_errors(self.ospf_order))

    def test_ospf_contract_accepts_exchange_flooding_fixture(self):
        self.assertEqual([], ospf_exchange_contract_errors(fixed_ospf_fixture()))

    def test_ospf_contract_rejects_post_sync_flooding_fixture(self):
        wrong = fixed_ospf_fixture()
        wrong["打乱步骤"] = wrong["打乱步骤"].replace(
            OSPF_REQUIRED_OPTIONS["C"],
            "交换DBD摘要，完成数据库描述",
        ).replace(
            OSPF_REQUIRED_OPTIONS["D"],
            "通过LSR/LSU完成LSDB同步后，再开始泛洪LSA",
        )
        wrong["正确顺序"] = "B → A → D → C → E"
        wrong["反馈"] = "LSDB完整同步后才开始全区域泛洪"

        errors = ospf_exchange_contract_errors(wrong)

        self.assertTrue(any("OSPF option C" in error for error in errors))
        self.assertTrue(any("OSPF option D" in error for error in errors))
        self.assertIn(
            "OSPF answer is 'B → A → D → C → E', "
            "expected 'B → A → C → D → E'",
            errors,
        )
        self.assertIn(
            "feedback must reject post-synchronization-only flooding",
            errors,
        )

    def test_reno_and_ospf_knowledge_is_synced_with_rfc_boundaries(self):
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        web_source = WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8")

        for chunk_id, contract in KNOWLEDGE_CONTRACTS.items():
            chunk = find_json_item(chunks, chunk_id)
            web_text, web_chunk_source = extract_web_chunk(web_source, chunk_id)
            self.assertEqual(web_text, chunk["text"], chunk_id)
            self.assertEqual(contract["source"], chunk["source"], chunk_id)
            self.assertEqual(web_chunk_source, chunk["source"], chunk_id)
            for required in contract["required"]:
                self.assertIn(required, chunk["text"], chunk_id)
            for forbidden in contract["forbidden"]:
                self.assertNotIn(forbidden, chunk["text"], chunk_id)

    def test_same_tag_quizzes_preserve_ack_and_recovery_boundaries(self):
        questions = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))

        for question_id, contract in QUIZ_CONTRACTS.items():
            question = find_json_item(questions, question_id)
            if "question" in contract:
                self.assertEqual(contract["question"], question["question"], question_id)
            if "option" in contract:
                self.assertIn(contract["option"], question["options"], question_id)
            for required in contract["required"]:
                self.assertIn(required, question["explanation"], question_id)
            self.assertNotIn(contract["forbidden"], question["explanation"], question_id)

    def test_generated_activities_preserve_fixed_reno_and_ospf_models(self):
        experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))
        activities = {
            activity["id"]: activity
            for experience in experiences
            if experience.get("courseId") == "cs103"
            for activity in experience.get("activities", [])
        }

        for activity_id in (
            "cs103-TCP流量控制与拥塞控制-1",
            "cs103-TCP流量控制与拥塞控制-2",
        ):
            activity = activities[activity_id]
            fields = {
                "题目": activity["prompt"],
                "反馈": activity["feedback"],
                "来源": activity["source"],
            }
            self.assertEqual([], reno_ack_schedule_contract_errors(fields), activity_id)

        ospf = activities["cs103-路由算法与协议-2"]
        self.assertIn(OSPF_PROMPT_SCOPE, ospf["prompt"])
        self.assertEqual(
            [OSPF_REQUIRED_OPTIONS[key] for key in "ABCDE"],
            ospf["options"],
        )
        self.assertEqual([1, 0, 2, 3, 4], ospf["answerIndexes"])
        self.assertEqual("B → A → C → D → E", ospf["answer"])
        self.assertIn(OSPF_FEEDBACK_OVERLAP, ospf["feedback"])
        self.assertIn(OSPF_SOURCE, ospf["source"])


if __name__ == "__main__":
    unittest.main()
