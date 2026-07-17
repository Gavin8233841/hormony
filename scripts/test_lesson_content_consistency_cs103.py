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
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"

TOPIC_HEADING = re.compile(r"^## Topic \d+: (?P<topic>.+)$", re.MULTILINE)
ACTIVITY_HEADING = re.compile(
    r"^### 主动练习 (?P<index>\d+)（[^）]+）$",
    re.MULTILINE,
)


def extract_topic(source, topic):
    matches = list(TOPIC_HEADING.finditer(source))
    selected = [match for match in matches if match.group("topic").strip() == topic]
    if len(selected) != 1:
        raise AssertionError(f"expected one Topic section for {topic!r}, got {len(selected)}")
    match = selected[0]
    position = matches.index(match)
    end = matches[position + 1].start() if position + 1 < len(matches) else len(source)
    return source[match.start():end]


def extract_activity(topic_section, index):
    matches = list(ACTIVITY_HEADING.finditer(topic_section))
    selected = [match for match in matches if int(match.group("index")) == index]
    if len(selected) != 1:
        raise AssertionError(f"expected one activity {index}, got {len(selected)}")
    match = selected[0]
    position = matches.index(match)
    end = matches[position + 1].start() if position + 1 < len(matches) else len(topic_section)
    return topic_section[match.start():end]


def missing_or_forbidden_errors(source, required, forbidden):
    errors = []
    for value in required:
        if value not in source:
            errors.append(f"missing required text: {value}")
    for value in forbidden:
        if value in source:
            errors.append(f"forbidden legacy text: {value}")
    return errors


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


PDU_REQUIRED = (
    "操作1后：PDU从 Message 变为 UDP Datagram（UDP用户数据报）",
    "操作2后：PDU从 UDP Datagram 变为 IP Datagram（IP数据报）",
    "操作3后：PDU从 IP Datagram 变为 Frame（数据帧）",
    "操作4后：PDU从 Frame 变为 Bits（比特流）",
    "Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
    "TCP形成TCP Segment，UDP形成UDP Datagram；网络层再封装为IP Datagram",
    "不能把DNS概括为“只使用UDP”",
    "RFC 7766要求通用DNS实现同时支持UDP与TCP",
    "RFC 7766（DNS over TCP Requirements）",
)
PDU_FORBIDDEN = (
    "Message → Segment → Datagram → Frame → Bit",
    "DNS使用UDP而非TCP",
    "传输层PDU虽为报文段但承载的是UDP报文",
)

RENO_REQUIRED = (
    "cwnd与FlightSize均为24 MSS时收到第3个重复ACK",
    "cwnd暂时膨胀为ssthresh+3 MSS=15 MSS",
    "确认重传段的新ACK到达时，将cwnd回落到ssthresh=12 MSS",
    "FlightSize=18 MSS，收到第3个重复ACK",
    "cwnd=ssthresh+3 MSS=12 MSS",
    "收到确认重传段的新ACK后将cwnd回落到ssthresh=9 MSS",
    "操作3后：cwnd=12 MSS, ssthresh=9 MSS",
    "操作4收到新ACK后：cwnd=9 MSS, ssthresh=9 MSS",
    "cwnd=10 MSS，ssthresh=9 MSS",
    "按FlightSize计算ssthresh，重传丢失段，并将cwnd设为ssthresh+3 MSS进入快恢复",
    "确认重传段的新ACK到达后，cwnd回落到ssthresh，退出快恢复并继续拥塞避免",
    "RFC 5681第3.2节（Fast Retransmit/Fast Recovery）",
)
RENO_FORBIDDEN = (
    "cwnd=ssthresh=9",
    "cwnd也设为ssthresh值（9）",
    "cwnd设为ssthresh值（快恢复）",
    "cwnd=ssthresh=12（快恢复",
    "快恢复后，cwnd以线性方式继续增长探测网络带宽",
)

UDP_TRACE_REQUIRED = (
    "cs103_k26（RFC 9000/9002 校正）",
    "标准QUIC在UDP之上提供多路复用、可靠交付与拥塞控制",
    "丢失信息通过新帧重发，不把FEC作为标准核心恢复机制",
    "D1进入网络后发生延迟",
    "D3先于延迟的D1到达",
    "接收方缓存 = [D3]（后发送的D3先到达）",
    "接收方缓存 = [D3, D1]（先发送的D1后到达，D2缺失）",
    "实际到达顺序为D3→D1，与发送顺序D1→D2→D3不同",
    "接收方缓存为 [D3, D1]，D2 丢失且不会由 UDP 重传",
    "标准QUIC通过多路复用、确认与丢失检测、在新帧中重发信息以及拥塞控制提供可靠传输",
    "不把FEC定义为核心恢复机制",
    "RFC 9000第2节、第13.3节",
    "RFC 9002第3节、第7节",
)
UDP_TRACE_FORBIDDEN = (
    "D1正常到达接收方",
    "D3经过不同路径先到达",
    "接收方缓存 = [D1]（正常到达）",
    "接收方缓存 = [D1, D3]",
    "到达顺序为D1→D3（乱序）",
    "接收方缓存为 [D1, D3]",
    "实现了可靠传输和前向纠错",
)
UDP_TRACE_LEGACY_FIXTURE = """
- cs103_k26: UDP适用于对实时性要求高、可容忍丢包的应用场景
### 主动练习 2（状态推演）
  1. D1正常到达接收方 → 接收方收到D1，缓存中有[D1]
  2. D2在网络中因拥塞被丢弃
  3. D3经过不同路径先到达 → 接收方缓存中有[D1, D3]
  - 操作1后：接收方缓存 = [D1]（正常到达）
  - 操作3后：接收方缓存 = [D1, D3]
- **最终状态**：到达顺序为D1→D3（乱序）
- **答案**：接收方缓存为 [D1, D3]，D2 丢失且不会由 UDP 重传
- **反馈**：QUIC协议在UDP之上实现了可靠传输和前向纠错
"""
QUIC_KNOWLEDGE_REQUIRED = (
    "可由UDP之上的协议提供",
    "QUIC在UDP之上提供多路复用、可靠交付和拥塞控制",
    "丢失包中的信息按需放入新帧发送",
    "RFC 9000/9002不把FEC定义为核心恢复机制",
    "QUIC已成为HTTP/3的传输基础",
)
QUIC_KNOWLEDGE_FORBIDDEN = (
    "由应用层自行实现，如QUIC",
    "前向纠错（FEC）",
)
QUIC_KNOWLEDGE_SOURCE = "计算机网络：自顶向下方法；RFC 9000/9002"


class Cs103LessonContentConsistencyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SPEC_PATH.read_text(encoding="utf-8")

    def test_source_parser_finds_all_generated_cs103_activities(self):
        topics = list(TOPIC_HEADING.finditer(self.source))
        activity_count = sum(
            len(ACTIVITY_HEADING.findall(
                self.source[
                    match.start():topics[index + 1].start()
                    if index + 1 < len(topics)
                    else len(self.source)
                ]
            ))
            for index, match in enumerate(topics)
        )

        self.assertEqual(9, len(topics))
        self.assertEqual(18, activity_count)

    def test_udp_pdu_and_dns_transport_contract_accepts_current_source(self):
        topic = extract_topic(self.source, "OSI与TCP/IP模型")
        activity = extract_activity(topic, 2)

        self.assertEqual(
            [],
            missing_or_forbidden_errors(activity, PDU_REQUIRED, PDU_FORBIDDEN),
        )

    def test_udp_pdu_and_dns_transport_contract_rejects_legacy_wording(self):
        topic = extract_topic(self.source, "OSI与TCP/IP模型")
        activity = extract_activity(topic, 2)
        legacy = activity.replace(
            "Message → UDP Datagram → IP Datagram → Frame → Bits；最终为 Bits（比特流）",
            "Message → Segment → Datagram → Frame → Bit；最终为 Bit（比特流）",
        ).replace(
            "题面已明确本次查询添加UDP首部，因此本题选择UDP，但不能把DNS概括为“只使用UDP”：RFC 7766要求通用DNS实现同时支持UDP与TCP。",
            "DNS使用UDP而非TCP，因此传输层PDU虽为报文段但承载的是UDP报文。",
        )

        self.assertNotEqual(activity, legacy)
        errors = missing_or_forbidden_errors(legacy, PDU_REQUIRED, PDU_FORBIDDEN)
        self.assertTrue(any("Message → UDP Datagram" in error for error in errors))
        self.assertIn("forbidden legacy text: DNS使用UDP而非TCP", errors)

    def test_tcp_reno_fast_recovery_contract_accepts_current_source(self):
        topic = extract_topic(self.source, "TCP流量控制与拥塞控制")

        self.assertEqual(
            [],
            missing_or_forbidden_errors(topic, RENO_REQUIRED, RENO_FORBIDDEN),
        )

    def test_tcp_reno_fast_recovery_contract_rejects_legacy_wording(self):
        topic = extract_topic(self.source, "TCP流量控制与拥塞控制")
        legacy = topic.replace(
            "cwnd=ssthresh+3 MSS=12 MSS",
            "cwnd=ssthresh=9 MSS",
        ).replace(
            "收到确认重传段的新ACK后将cwnd回落到ssthresh=9 MSS；再继续拥塞避免1个RTT，",
            "继续拥塞避免1个RTT，",
        ).replace(
            "按FlightSize计算ssthresh，重传丢失段，并将cwnd设为ssthresh+3 MSS进入快恢复",
            "ssthresh设为当前cwnd的一半，cwnd设为ssthresh值（快恢复）",
        ).replace(
            "确认重传段的新ACK到达后，cwnd回落到ssthresh，退出快恢复并继续拥塞避免",
            "快恢复后，cwnd以线性方式继续增长探测网络带宽",
        )

        self.assertNotEqual(topic, legacy)
        errors = missing_or_forbidden_errors(legacy, RENO_REQUIRED, RENO_FORBIDDEN)
        self.assertIn("forbidden legacy text: cwnd=ssthresh=9", errors)
        self.assertIn(
            "forbidden legacy text: cwnd设为ssthresh值（快恢复）",
            errors,
        )
        self.assertIn(
            "forbidden legacy text: 快恢复后，cwnd以线性方式继续增长探测网络带宽",
            errors,
        )

    def test_udp_reordering_and_quic_recovery_contract_accepts_current_source(self):
        topic = extract_topic(self.source, "UDP协议")

        self.assertEqual(
            [],
            missing_or_forbidden_errors(
                topic,
                UDP_TRACE_REQUIRED,
                UDP_TRACE_FORBIDDEN,
            ),
        )

    def test_generated_udp_trace_preserves_reordering_and_rfc_feedback(self):
        experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))
        matches = [
            activity
            for experience in experiences
            if experience.get("courseId") == "cs103"
            and experience.get("topic") == "UDP协议"
            for activity in experience.get("activities", [])
            if activity.get("id") == "cs103-UDP协议-2"
        ]
        self.assertEqual(1, len(matches))
        activity = matches[0]

        self.assertIn("D1进入网络后发生延迟", activity["content"])
        self.assertIn("D3先于延迟的D1到达", activity["content"])
        self.assertIn("接收方缓存 = [D3, D1]", activity["content"])
        self.assertEqual(
            "接收方缓存为 [D3, D1]，D2 丢失且不会由 UDP 重传",
            activity["answer"],
        )
        self.assertIn("在新帧中重发信息", activity["feedback"])
        self.assertIn("不把FEC定义为核心恢复机制", activity["feedback"])
        self.assertIn("RFC 9000第2节、第13.3节", activity["source"])
        self.assertIn("RFC 9002第3节、第7节", activity["source"])
        self.assertNotIn("接收方缓存 = [D1, D3]", activity["content"])
        self.assertNotIn("前向纠错", activity["feedback"])

    def test_udp_reordering_and_quic_recovery_contract_rejects_legacy_wording(self):
        errors = missing_or_forbidden_errors(
            UDP_TRACE_LEGACY_FIXTURE,
            UDP_TRACE_REQUIRED,
            UDP_TRACE_FORBIDDEN,
        )

        self.assertIn("forbidden legacy text: D1正常到达接收方", errors)
        self.assertIn("forbidden legacy text: D3经过不同路径先到达", errors)
        self.assertIn("forbidden legacy text: 接收方缓存为 [D1, D3]", errors)
        self.assertIn(
            "forbidden legacy text: 实现了可靠传输和前向纠错",
            errors,
        )

    def test_udp_quic_knowledge_is_synced_and_uses_rfc_recovery(self):
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        matches = [item for item in chunks if item.get("id") == "cs103_k26"]
        self.assertEqual(1, len(matches))
        chunk = matches[0]
        web_text, web_source = extract_web_chunk(
            WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8"),
            "cs103_k26",
        )

        self.assertEqual(chunk["text"], web_text)
        self.assertEqual(QUIC_KNOWLEDGE_SOURCE, chunk["source"])
        self.assertEqual(chunk["source"], web_source)
        self.assertEqual(
            [],
            missing_or_forbidden_errors(
                chunk["text"],
                QUIC_KNOWLEDGE_REQUIRED,
                QUIC_KNOWLEDGE_FORBIDDEN,
            ),
        )

    def test_udp_quic_knowledge_contract_rejects_fec_legacy_fixture(self):
        legacy = (
            "当应用需要可靠传输时，由应用层自行实现，如QUIC协议在UDP之上"
            "实现了可靠传输、多路复用和前向纠错（FEC），已成为HTTP/3的传输基础。"
        )

        errors = missing_or_forbidden_errors(
            legacy,
            QUIC_KNOWLEDGE_REQUIRED,
            QUIC_KNOWLEDGE_FORBIDDEN,
        )
        self.assertIn("forbidden legacy text: 由应用层自行实现，如QUIC", errors)
        self.assertIn("forbidden legacy text: 前向纠错（FEC）", errors)


if __name__ == "__main__":
    unittest.main()
