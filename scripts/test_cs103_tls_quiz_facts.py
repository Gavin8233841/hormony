"""Executable RFC contracts for the CS103 TLS quiz explanations.

Verified primary references:
- RFC 8446 Sections 2 and 4.2.8:
  https://www.rfc-editor.org/rfc/rfc8446.html#section-2
  https://www.rfc-editor.org/rfc/rfc8446.html#section-4.2.8
  TLS 1.3 supports (EC)DHE, PSK-only, and PSK with (EC)DHE. KeyShare
  carries ephemeral key-exchange values; application traffic uses derived
  symmetric traffic keys. PSK-only and 0-RTT do not provide forward secrecy.
- RFC 8446 Sections 4.4.2 and 4.4.3:
  https://www.rfc-editor.org/rfc/rfc8446.html#section-4.4.2
  https://www.rfc-editor.org/rfc/rfc8446.html#section-4.4.3
  Certificate messages are omitted with PSK authentication, and a sender can
  omit a trust anchor already held by its peer. CertificateVerify proves
  possession of the private key corresponding to the authenticated certificate.
- RFC 5280 Section 6.1.1:
  https://www.rfc-editor.org/rfc/rfc5280.html#section-6.1.1
  Certification path validation takes independently trusted anchor information
  as an input; a root certificate's self-signature is not the source of trust.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
QUIZZES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)

CHOICE_IDS = (
    "cs103_q12",
    "cs103_q13",
    "cs103_q43",
    "cs103_q44",
    "cs103_q45",
)

QUIZ_CONTRACTS = {
    "cs103_q12": {
        "required": (
            "（EC）DHE密钥协商或PSK",
            "派生应用流量使用的对称密钥",
            "ECDHE不是“非对称加密”",
        ),
        "forbidden": (
            "TLS握手使用非对称加密（如RSA/ECDHE）安全协商出对称会话密钥",
            "非对称加密计算成本高仅用于握手阶段",
        ),
    },
    "cs103_q13": {
        "required": (
            "证书路径终止于客户端本地独立配置的信任锚",
            "验证CertificateVerify签名",
            "证明服务器持有终端证书公钥对应的私钥",
        ),
        "forbidden": (
            "客户端验证CA签名（使用CA公钥）确认证书真实性，从而信任证书中的服务器公钥",
        ),
    },
    "cs103_q43": {
        "required": (
            "完整握手以1-RTT完成",
            "0-RTT只是在PSK恢复握手首个flight中发送earlydata",
            "PSK-only握手可以省略Certificate和CertificateVerify消息",
        ),
        "forbidden": (
            "还支持0-RTT恢复模式",
            "数字证书在TLS1.3中仍然必需",
        ),
    },
    "cs103_q44": {
        "required": (
            "信任来自客户端对信任锚的本地配置，而非根证书自签名",
            "服务器可以省略客户端已持有的信任锚",
        ),
        "forbidden": (
            "自签名且预装在操作系统或浏览器信任库中",
            "根CA证书是自签名的，预装在操作系统或浏览器的信任库中，作为信任锚点",
        ),
    },
    "cs103_q45": {
        "required": (
            "临时（EC）DHE",
            "PSK-only模式本身不提供前向安全性",
            "0-RTT早期数据不具备前向安全性",
        ),
        "forbidden": (
            "前向保密通过每次连接使用临时密钥交换（如ECDHE）生成独立的会话密钥，会话密钥不会被保存",
        ),
    },
    "cs103_q14": {
        "required": (
            "证书公钥用于验证CertificateVerify签名",
            "证明服务器持有对应私钥",
            "TLS1.3通常通过KeyShare中的（EC）DHE公钥完成密钥协商",
        ),
        "forbidden": (
            "验证通过后使用证书中的公钥进行密钥交换",
            "通过验证后使用证书公钥加密协商信息",
        ),
    },
}

LEGACY_QUIZ_FIXTURES = {
    "cs103_q12": (
        "TLS 握手使用非对称加密（如 RSA/ECDHE）安全协商出对称会话密钥，"
        "之后的应用数据使用该对称密钥加密传输。非对称加密计算成本高仅用于"
        "握手阶段，对称加密速度快用于大量数据传输。这种混合加密机制兼顾了"
        "安全性和性能。"
    ),
    "cs103_q13": (
        "HTTPS 中服务器向客户端发送数字证书，证书包含服务器公钥并由受信任的"
        " CA 签名。客户端验证 CA 签名（使用 CA 公钥）确认证书真实性，从而信任"
        "证书中的服务器公钥。这防止了中间人攻击，确保客户端连接到真实服务器。"
    ),
    "cs103_q43": (
        "TLS 1.3 将基本握手从 2-RTT 减少到 1-RTT，降低了连接建立延迟，还支持 "
        "0-RTT 恢复模式。TLS 1.3 删除了不安全的算法（如 RSA 密钥交换、CBC 模式），"
        "仅保留 AEAD 加密。数字证书在 TLS 1.3 中仍然必需，用于身份验证。"
    ),
    "cs103_q44": (
        "B. 自签名且预装在操作系统或浏览器信任库中。根 CA 证书是自签名的，"
        "预装在操作系统或浏览器的信任库中，作为信任锚点。根 CA 证书不需要在"
        "网络中传输，客户端直接从本地信任库获取并验证。"
    ),
    "cs103_q45": (
        "前向保密通过每次连接使用临时密钥交换（如 ECDHE）生成独立的会话密钥，"
        "会话密钥不会被保存。即使服务器长期私钥日后泄露，攻击者也无法解密此前"
        "捕获的加密流量。"
    ),
    "cs103_q14": (
        "验证通过后使用证书中的公钥进行密钥交换，确保通信方身份可信。"
        "通过验证后使用证书公钥加密协商信息防止中间人攻击。"
    ),
}

STRING_LITERAL = r'"(?:\\.|[^"\\])*"'


def compact(value):
    return re.sub(r"\s+", "", value)


def semantic_contract_errors(value, contract):
    normalized = compact(value)
    errors = []
    for required in contract["required"]:
        if compact(required) not in normalized:
            errors.append(f"missing required fact: {required}")
    for forbidden in contract["forbidden"]:
        if compact(forbidden) in normalized:
            errors.append(f"contains rejected fact: {forbidden}")
    return errors


def extract_web_choice(source, question_id):
    pattern = re.compile(
        r'\{\s*id:\s*"'
        + re.escape(question_id)
        + r'",\s*type:\s*"choice",\s*stem:\s*('
        + STRING_LITERAL
        + r'),\s*options:\s*\[(.*?)\],\s*answer:\s*('
        + STRING_LITERAL
        + r'),\s*explanation:\s*('
        + STRING_LITERAL
        + r'),\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web choice question for {question_id!r}, got {len(matches)}"
        )
    stem_literal, options_source, answer_literal, explanation_literal = matches[0]
    option_literals = re.findall(STRING_LITERAL, options_source)
    return {
        "id": question_id,
        "question": json.loads(stem_literal),
        "options": [json.loads(value) for value in option_literals],
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def extract_web_short(source, question_id):
    pattern = re.compile(
        r'\{\s*id:\s*"'
        + re.escape(question_id)
        + r'",\s*type:\s*"short",\s*stem:\s*('
        + STRING_LITERAL
        + r'),\s*answer:\s*('
        + STRING_LITERAL
        + r'),\s*explanation:\s*('
        + STRING_LITERAL
        + r'),\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web short question for {question_id!r}, got {len(matches)}"
        )
    stem_literal, answer_literal, explanation_literal = matches[0]
    return {
        "id": question_id,
        "question": json.loads(stem_literal),
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def find_unique(items, question_id):
    matches = [item for item in items if item.get("id") == question_id]
    if len(matches) != 1:
        raise AssertionError(
            f"expected one raw quiz question for {question_id!r}, got {len(matches)}"
        )
    return matches[0]


class Cs103TlsQuizFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.web_source = WEB_QUIZZES_PATH.read_text(encoding="utf-8")
        cls.raw_quizzes = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))

    def test_choice_questions_are_exactly_synced_from_web_source(self):
        for question_id in CHOICE_IDS:
            with self.subTest(question_id=question_id):
                web = extract_web_choice(self.web_source, question_id)
                raw = find_unique(self.raw_quizzes, question_id)
                self.assertEqual("cs103", raw["courseId"])
                self.assertEqual("HTTPS与TLS", raw["topic"])
                self.assertEqual(web["question"], raw["question"])
                self.assertEqual(web["options"], raw["options"])
                self.assertEqual(web["answer"], raw["answer"])
                self.assertEqual(web["explanation"], raw["explanation"])

    def test_live_tls_quizzes_preserve_rfc8446_boundaries(self):
        for question_id in CHOICE_IDS:
            with self.subTest(question_id=question_id):
                question = extract_web_choice(self.web_source, question_id)
                value = "\n".join(
                    [
                        question["question"],
                        *question["options"],
                        question["explanation"],
                    ]
                )
                self.assertEqual(
                    [],
                    semantic_contract_errors(value, QUIZ_CONTRACTS[question_id]),
                )

        short = extract_web_short(self.web_source, "cs103_q14")
        self.assertEqual(
            [],
            semantic_contract_errors(
                f'{short["answer"]}\n{short["explanation"]}',
                QUIZ_CONTRACTS["cs103_q14"],
            ),
        )

    def test_contract_rejects_all_six_legacy_quiz_fixtures(self):
        self.assertEqual(set(QUIZ_CONTRACTS), set(LEGACY_QUIZ_FIXTURES))
        for question_id, legacy in LEGACY_QUIZ_FIXTURES.items():
            with self.subTest(question_id=question_id):
                errors = semantic_contract_errors(
                    legacy,
                    QUIZ_CONTRACTS[question_id],
                )
                self.assertTrue(
                    any(
                        error.startswith("contains rejected fact:")
                        for error in errors
                    ),
                    errors,
                )


if __name__ == "__main__":
    unittest.main()
