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
    "第3.2节（Fast Retransmit/Fast Recovery）",
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

TLS_EARLY_DATA_REQUIRED = (
    "TLS 1.3完整握手仍是1-RTT",
    "客户端与服务器已共享PSK",
    "恢复握手才允许客户端在首个flight附带0-RTT early data",
    "其余握手仍按1-RTT的PSK恢复流程继续",
    "0-RTT数据没有跨连接防重放保证",
    "不能表述为“握手0 RTT完成”",
    "RFC 8446第2.3节（0-RTT Data）",
)
TLS_EARLY_DATA_FORBIDDEN = (
    "TLS 1.3简化了这一过程为1-RTT甚至0-RTT",
    "TLS 1.3握手可在0 RTT完成",
    "0-RTT握手完成",
)
TLS_EARLY_DATA_LEGACY_FIXTURE = """
- **反馈**：TLS 1.3简化了这一过程为1-RTT甚至0-RTT。
- **来源**：RFC 5246（TLS 1.2）；知识切片 cs103_k32
"""

TLS_TRUST_ANCHOR_REQUIRED = (
    "构建到本地独立配置根CA信任锚的证书路径",
    "信任来自本地配置而非根证书自签名",
    "服务器发送的证书列表包含终端证书（shop.example.com）和中间CA证书，但省略根CA证书",
    "本地信任库已独立配置对应根CA作为信任锚",
    "本地信任锚中的根CA公钥验证中间CA证书签名",
    "信任锚的自签名不作为证书路径的一部分验证",
    "终端证书和中间CA证书均在有效期内",
    "信任并非来自服务器发送根证书或验证根证书自签名",
    "证书路径到本地信任锚、域名、有效期和吊销状态均通过",
    "第4.4.2节允许服务器证书列表省略对端已持有的信任锚",
    "第4.2.3节明确自签证书或信任锚的签名不参与路径验证",
    "RFC 8446第4.4.2节（Certificate）、第4.2.3节（Signature Algorithms）",
)
TLS_TRUST_ANCHOR_FORBIDDEN = (
    "服务器返回的证书链包含：终端证书（shop.example.com）→ 中间CA证书 → 根CA证书",
    "客户端收到3级证书链",
    "验证根CA证书 → 根CA证书是自签名的",
    "所有证书均在有效期内",
    "根CA证书是自签名的，且已预装在本地信任库中（信任锚），验证通过",
)
TLS_TRUST_ANCHOR_LEGACY_FIXTURE = """
- **题目**：服务器返回的证书链包含：终端证书（shop.example.com）→ 中间CA证书 → 根CA证书
- **初始状态**：客户端收到3级证书链，本地信任库中预装有根CA证书
  3. 验证根CA证书 → 根CA证书是自签名的，且已预装在本地信任库中（信任锚），验证通过
  5. 检查有效期和吊销状态 → 所有证书均在有效期内
- **反馈**：根CA自签名且预装在系统或浏览器中，不需要在网络中传输
"""

TLS_TOPIC_REQUIRED = (
    "TLS 1.3完整握手以1-RTT完成密钥协商",
    "根CA信任锚由客户端独立配置并可从服务器证书链省略",
    "支持（EC）DHE、PSK-only及PSK与（EC）DHE组合三类密钥交换模式",
    "TLS 1.3并非强制所有模式具备前向安全性",
    "采用ECDHE等临时密钥交换时",
    "PSK-only或0-RTT早期数据不能直接套用这个结论",
)
TLS_TOPIC_FORBIDDEN = (
    "TLS 1.3强制使用ECDHE和DHE，弃用RSA密钥交换",
    "TLS 1.3强制要求前向安全性",
    "核对照片是否是你本人（域名匹配SAN/CN）",
)

TLS_KNOWLEDGE_CONTRACTS = {
    "cs103_k32": {
        "source": "计算机网络：自顶向下方法；RFC 8446第2.3节",
        "required": (
            "TLS 1.3的完整握手以1-RTT完成密钥协商",
            "双方共享PSK且服务器允许early data",
            "附加在1-RTT的PSK恢复握手上",
            "不表示握手在服务器响应前完成",
            "没有跨连接防重放保证",
        ),
        "forbidden": (
            "TLS 1.3简化了握手为1-RTT甚至0-RTT",
            "TLS 1.3握手可在0 RTT完成",
        ),
    },
    "cs103_k33": {
        "source": (
            "计算机网络：自顶向下方法；RFC 8446第4.4.2节、"
            "第4.2.3节；RFC 5280"
        ),
        "required": (
            "信任锚由客户端操作系统或浏览器独立配置",
            "可从服务器证书链中省略",
            "自签名证书或信任锚的签名不作为认证路径的一部分验证",
            "信任来自本地配置的锚",
        ),
        "forbidden": (
            "信任来自根证书自签名",
            "服务器必须发送根CA证书",
        ),
    },
    "cs103_k34": {
        "source": "计算机网络：自顶向下方法；RFC 8446第2节",
        "required": (
            "TLS 1.3移除了RSA密钥传输，但RSA仍可用于证书签名",
            "（EC）DHE、PSK-only和PSK与（EC）DHE组合",
            "PSK-only模式本身不提供由临时密钥交换带来的前向安全性",
        ),
        "forbidden": (
            "TLS 1.3完全移除了RSA密钥交换",
            "强制使用具备前向安全性的ECDHE和DHE",
            "TLS 1.3仅支持ECDHE和DHE",
        ),
    },
    "cs103_k35": {
        "source": "计算机网络：自顶向下方法；RFC 8446第2节、第2.3节",
        "required": (
            "TLS 1.3并非强制所有模式都具备前向安全性",
            "PSK-only模式本身不提供由临时密钥交换带来的前向安全性",
            "0-RTT早期数据仅由PSK派生密钥保护",
            "不具备前向安全性且没有跨连接防重放保证",
        ),
        "forbidden": (
            "TLS 1.3强制要求前向安全性",
            "仅支持ECDHE和DHE密钥交换",
        ),
    },
}

TLS_KNOWLEDGE_LEGACY_FIXTURES = {
    "cs103_k32": "TLS 1.3简化了握手为1-RTT甚至0-RTT。",
    "cs103_k33": "服务器必须发送根CA证书，信任来自根证书自签名。",
    "cs103_k34": (
        "TLS 1.3完全移除了RSA密钥交换，"
        "强制使用具备前向安全性的ECDHE和DHE。"
    ),
    "cs103_k35": "TLS 1.3强制要求前向安全性，仅支持ECDHE和DHE密钥交换。",
}


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

        self.assertEqual(10, len(topics))
        self.assertEqual(20, activity_count)

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
            "收到确认重传段的新ACK后将cwnd回落到ssthresh=9 MSS；再按题设完成1轮拥塞避免，",
            "按题设继续1轮拥塞避免，",
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

    def test_tls_early_data_contract_accepts_psk_first_flight_semantics(self):
        topic = extract_topic(self.source, "HTTPS与TLS")
        activity = extract_activity(topic, 1)

        self.assertEqual(
            [],
            missing_or_forbidden_errors(
                activity,
                TLS_EARLY_DATA_REQUIRED,
                TLS_EARLY_DATA_FORBIDDEN,
            ),
        )

    def test_tls_early_data_contract_rejects_zero_rtt_handshake_fixture(self):
        errors = missing_or_forbidden_errors(
            TLS_EARLY_DATA_LEGACY_FIXTURE,
            TLS_EARLY_DATA_REQUIRED,
            TLS_EARLY_DATA_FORBIDDEN,
        )

        self.assertIn(
            "forbidden legacy text: TLS 1.3简化了这一过程为1-RTT甚至0-RTT",
            errors,
        )
        self.assertTrue(
            any("0-RTT数据没有跨连接防重放保证" in error for error in errors)
        )

    def test_tls_trust_anchor_contract_accepts_local_anchor_path(self):
        topic = extract_topic(self.source, "HTTPS与TLS")

        self.assertEqual(
            [],
            missing_or_forbidden_errors(
                topic,
                TLS_TRUST_ANCHOR_REQUIRED,
                TLS_TRUST_ANCHOR_FORBIDDEN,
            ),
        )

    def test_tls_trust_anchor_contract_rejects_server_root_fixture(self):
        errors = missing_or_forbidden_errors(
            TLS_TRUST_ANCHOR_LEGACY_FIXTURE,
            TLS_TRUST_ANCHOR_REQUIRED,
            TLS_TRUST_ANCHOR_FORBIDDEN,
        )

        self.assertIn(
            "forbidden legacy text: 客户端收到3级证书链",
            errors,
        )
        self.assertIn(
            "forbidden legacy text: 验证根CA证书 → 根CA证书是自签名的",
            errors,
        )
        self.assertTrue(
            any("信任锚的自签名不作为证书路径的一部分验证" in error for error in errors)
        )

    def test_tls_topic_summary_preserves_mode_and_trust_boundaries(self):
        topic = extract_topic(self.source, "HTTPS与TLS")

        self.assertEqual(
            [],
            missing_or_forbidden_errors(
                topic,
                TLS_TOPIC_REQUIRED,
                TLS_TOPIC_FORBIDDEN,
            ),
        )

    def test_tls_knowledge_chunks_are_synced_and_follow_rfc8446(self):
        chunks = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        web_source = WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8")

        for chunk_id, contract in TLS_KNOWLEDGE_CONTRACTS.items():
            matches = [item for item in chunks if item.get("id") == chunk_id]
            self.assertEqual(1, len(matches), chunk_id)
            chunk = matches[0]
            web_text, web_chunk_source = extract_web_chunk(web_source, chunk_id)

            self.assertEqual(web_text, chunk["text"], chunk_id)
            self.assertEqual(contract["source"], chunk["source"], chunk_id)
            self.assertEqual(web_chunk_source, chunk["source"], chunk_id)
            self.assertEqual(
                [],
                missing_or_forbidden_errors(
                    chunk["text"],
                    contract["required"],
                    contract["forbidden"],
                ),
                chunk_id,
            )

    def test_tls_knowledge_contract_rejects_legacy_mode_claims(self):
        for chunk_id, fixture in TLS_KNOWLEDGE_LEGACY_FIXTURES.items():
            contract = TLS_KNOWLEDGE_CONTRACTS[chunk_id]
            errors = missing_or_forbidden_errors(
                fixture,
                contract["required"],
                contract["forbidden"],
            )

            self.assertTrue(
                any(error.startswith("forbidden legacy text:") for error in errors),
                chunk_id,
            )

    def test_generated_tls_activities_preserve_rfc_semantics(self):
        experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))
        matches = [
            experience
            for experience in experiences
            if experience.get("courseId") == "cs103"
            and experience.get("topic") == "HTTPS与TLS"
        ]
        self.assertEqual(1, len(matches))
        activities = {
            activity["id"]: activity
            for activity in matches[0].get("activities", [])
        }
        self.assertEqual(
            {"cs103-HTTPS与TLS-1", "cs103-HTTPS与TLS-2"},
            set(activities),
        )

        ordering = activities["cs103-HTTPS与TLS-1"]
        self.assertEqual([1, 0, 3, 2], ordering["answerIndexes"])
        self.assertEqual("B → A → D → C", ordering["answer"])
        self.assertIn("0-RTT early data", ordering["feedback"])
        self.assertIn("不能表述为“握手0 RTT完成”", ordering["feedback"])
        self.assertIn("RFC 8446第2.3节", ordering["source"])

        trace = activities["cs103-HTTPS与TLS-2"]
        self.assertIn("服务器发送的证书列表包含终端证书", trace["prompt"])
        self.assertIn("但省略根CA证书", trace["prompt"])
        self.assertIn("本地信任锚中的根CA公钥", trace["content"])
        self.assertIn("信任锚的自签名不作为证书路径的一部分验证", trace["content"])
        self.assertEqual(
            "证书路径到本地信任锚、域名、有效期和吊销状态均通过，"
            "客户端继续密钥交换",
            trace["answer"],
        )
        self.assertIn("信任来源是客户端对信任锚的独立配置", trace["feedback"])
        self.assertIn("RFC 8446第4.4.2节", trace["source"])
        self.assertIn("第4.2.3节", trace["source"])


if __name__ == "__main__":
    unittest.main()
