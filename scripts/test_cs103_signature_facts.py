"""Executable contracts for CS103 digital-signature teaching facts.

Verified primary references:
- NIST FIPS 186-5, Digital Signature Standard:
  https://csrc.nist.gov/pubs/fips/186-5/final
  The standard defines algorithms that generate and verify digital signatures;
  signatures detect unauthorized changes and authenticate the signatory.
- RFC 8017 Sections 8.1.1 and 8.1.2:
  https://www.rfc-editor.org/rfc/rfc8017.html#section-8.1.1
  https://www.rfc-editor.org/rfc/rfc8017.html#section-8.1.2
  RSASSA-PSS applies an encoding plus the RSA signature primitive when signing,
  and the RSA verification primitive plus EMSA-PSS consistency verification
  when verifying. Verification returns a valid/invalid result; it is not a
  generic "public-key decrypts the signature to recover the digest" workflow.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"
WEB_QUIZZES_PATH = ROOT / "apps/web/src/lib/data/quizzes.ts"
RAW_KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
RAW_QUIZZES_PATH = (
    ROOT / "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
)

STRING_LITERAL = r'"(?:\\.|[^"\\])*"'

REQUIRED_SIGNATURE_MODEL = (
    "明确的签名方案",
    "RSA-PSS或ECDSA",
    "原消息",
    "方案内部处理",
    "已可信绑定签名者身份的公钥",
    "对应验证算法",
    "返回有效或无效",
    "不是把摘要当普通密文加密后再由公钥解密",
)

REJECTED_SIGNATURE_MODEL = (
    "数字签名利用非对称加密的逆运用",
    "签名方用私钥对消息的哈希值进行加密",
    "验证方用公钥解密签名",
    "数字签名使用发送方私钥对消息摘要加密",
    "接收方用发送方公钥解密签名，恢复出摘要值",
    "发送方用自己的私钥对摘要加密，生成数字签名",
    "数字签名则反过来",
    "签名者无法否认签过名",
)

SIGNATURE_PROMPT = (
    "接收方已通过有效证书路径或可信配置取得公钥，并确认该公钥与声称的签名者"
    "身份绑定。以下是数字签名的生成与验证过程，请将打乱的步骤排列为正确的执行顺序"
)
SIGNATURE_OPTIONS = {
    "A": "接收方检查算法标识和参数符合本地策略，并选择对应验证算法",
    "B": "发送方选择明确的签名方案（如RSA-PSS或ECDSA）及约定参数",
    "C": "接收方以已可信绑定签名者身份的公钥、原消息、签名和约定参数调用验证算法，得到有效或无效结果",
    "D": "发送方以私钥、原消息和约定参数调用签名算法；方案内部完成哈希与编码，输出数字签名",
    "E": "接收方取得原消息和数字签名，并从协议上下文取得约定的算法标识和参数",
}
SIGNATURE_ORDER = ("B", "D", "E", "A", "C")


def compact(value):
    return re.sub(r"\s+", "", value)


def signature_contract_errors(value):
    normalized = compact(value)
    errors = []
    for required in REQUIRED_SIGNATURE_MODEL:
        if compact(required) not in normalized:
            errors.append(f"missing required fact: {required}")
    for rejected in REJECTED_SIGNATURE_MODEL:
        if compact(rejected) in normalized:
            errors.append(f"contains rejected fact: {rejected}")
    return errors


def extract_web_knowledge(source, knowledge_id):
    pattern = re.compile(
        r'\{\s*id:\s*"'
        + re.escape(knowledge_id)
        + r'",\s*text:\s*('
        + STRING_LITERAL
        + r'),\s*source:\s*('
        + STRING_LITERAL
        + r'),\s*courseId:\s*"cs103",\s*topic:\s*"网络安全基础",\s*\}',
        re.DOTALL,
    )
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise AssertionError(
            f"expected one Web knowledge item for {knowledge_id!r}, got {len(matches)}"
        )
    text_literal, source_literal = matches[0]
    return {
        "id": knowledge_id,
        "text": json.loads(text_literal),
        "source": json.loads(source_literal),
        "courseId": "cs103",
        "topic": "网络安全基础",
    }


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
    return {
        "id": question_id,
        "question": json.loads(stem_literal),
        "options": [
            json.loads(value) for value in re.findall(STRING_LITERAL, options_source)
        ],
        "answer": json.loads(answer_literal),
        "explanation": json.loads(explanation_literal),
    }


def find_unique(items, item_id):
    matches = [item for item in items if item.get("id") == item_id]
    if len(matches) != 1:
        raise AssertionError(f"expected one item for {item_id!r}, got {len(matches)}")
    return matches[0]


def extract_topic_section(spec, topic_heading):
    heading = re.search(
        rf"^## Topic \d+: {re.escape(topic_heading)}$", spec, re.MULTILINE
    )
    if heading is None:
        raise AssertionError(f"missing topic section {topic_heading!r}")
    next_heading = re.search(r"^## (?:Topic \d+:|附录)", spec[heading.end() :], re.MULTILINE)
    end = heading.end() + next_heading.start() if next_heading is not None else len(spec)
    return spec[heading.start() : end]


def parse_signature_activity(topic):
    block_match = re.search(
        r"^### 主动练习 1（步骤排序）\s*$\n(?P<body>[\s\S]*?)(?=^### 主动练习 2)",
        topic,
        re.MULTILINE,
    )
    if block_match is None:
        raise AssertionError("missing Topic 10 signature step-order activity")
    block = block_match.group("body")
    prompt_match = re.search(r"^- \*\*题目\*\*：(.+)$", block, re.MULTILINE)
    answer_match = re.search(
        r"^- \*\*正确顺序\*\*：(.+)$", block, re.MULTILINE
    )
    if prompt_match is None or answer_match is None:
        raise AssertionError("signature activity is missing its prompt or answer")
    option_entries = tuple(
        (match.group("label"), match.group("text"))
        for match in re.finditer(
            r"^  - (?P<label>[A-Z])\. (?P<text>.+)$", block, re.MULTILINE
        )
    )
    return {
        "prompt": prompt_match.group(1),
        "option_entries": option_entries,
        "options": dict(option_entries),
        "answer_labels": tuple(
            label.strip() for label in answer_match.group(1).split("→")
        ),
    }


def signature_activity_contract_errors(activity):
    errors = []
    if activity["prompt"] != SIGNATURE_PROMPT:
        errors.append("signature activity prompt must establish trusted key binding")

    labels = tuple(label for label, _ in activity["option_entries"])
    if labels != tuple(SIGNATURE_OPTIONS):
        errors.append(f"signature options must be unique A-E, got {labels}")
    for label, expected_text in SIGNATURE_OPTIONS.items():
        if activity["options"].get(label) != expected_text:
            errors.append(f"signature option {label} does not match its fact contract")
    if activity["answer_labels"] != SIGNATURE_ORDER:
        errors.append(
            f"signature answer must be {' → '.join(SIGNATURE_ORDER)}, "
            f"got {' → '.join(activity['answer_labels'])}"
        )

    operations = {
        "A": "check_policy",
        "B": "select_scheme",
        "C": "verify",
        "D": "sign",
        "E": "receive",
    }
    events = []
    for label in activity["answer_labels"]:
        text = activity["options"].get(label, "")
        event = {"id": label, "operation": operations.get(label, "unknown")}
        if label in ("C", "D"):
            event["input"] = "message" if "原消息" in text else "digest"
        events.append(event)
    trusted_key_bound = (
        "有效证书路径或可信配置" in activity["prompt"]
        and "公钥与声称的签名者身份绑定" in activity["prompt"]
        and "已可信绑定签名者身份的公钥" in activity["options"].get("C", "")
    )
    errors.extend(run_signature_flow(tuple(events), trusted_key_bound))
    return errors


def run_signature_flow(events, trusted_key_bound):
    state = {
        "scheme_selected": False,
        "signature_created": False,
        "payload_received": False,
        "policy_checked": False,
        "verification_attempted": False,
    }
    errors = []
    event_ids = tuple(event.get("id") for event in events)
    if event_ids != SIGNATURE_ORDER:
        errors.append(
            f"signature events must be {' → '.join(SIGNATURE_ORDER)}, "
            f"got {' → '.join(str(event_id) for event_id in event_ids)}"
        )
    for event in events:
        operation = event["operation"]
        if operation == "select_scheme":
            state["scheme_selected"] = True
        elif operation == "sign":
            if not state["scheme_selected"]:
                errors.append("signing requires a selected scheme")
            if event.get("input") != "message":
                errors.append("RFC 8017 signing input must be the original message M")
            state["signature_created"] = True
        elif operation == "receive":
            if not state["signature_created"]:
                errors.append("receiving a signature requires prior signing")
            state["payload_received"] = True
        elif operation == "check_policy":
            if not state["payload_received"]:
                errors.append("policy checking requires the received algorithm context")
            state["policy_checked"] = True
        elif operation == "verify":
            if not state["policy_checked"]:
                errors.append("verification requires algorithm policy checking")
            if not trusted_key_bound:
                errors.append("identity authentication requires a trusted bound public key")
            if event.get("input") != "message":
                errors.append("RFC 8017 verification input must be the original message M")
            state["verification_attempted"] = True
        else:
            errors.append(f"unknown operation: {operation}")
    for state_name, reached in state.items():
        if not reached:
            errors.append(f"incomplete signature flow: {state_name}")
    return errors


class Cs103SignatureFactsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = SPEC_PATH.read_text(encoding="utf-8")
        cls.web_knowledge_source = WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8")
        cls.web_quizzes_source = WEB_QUIZZES_PATH.read_text(encoding="utf-8")
        cls.raw_knowledge = json.loads(RAW_KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.raw_quizzes = json.loads(RAW_QUIZZES_PATH.read_text(encoding="utf-8"))

    def test_contract_accepts_defined_verification_and_rejects_legacy_models(self):
        correct = (
            "发送方调用明确的签名方案，例如RSA-PSS或ECDSA，以私钥、原消息和"
            "参数执行签名，方案内部处理原消息（例如哈希与编码）。接收方调用"
            "对应验证算法，以已可信绑定签名者身份的公钥、原消息、签名和参数为输入，返回"
            "有效或无效。这不是把摘要当普通密文加密后再由公钥解密。"
        )
        self.assertEqual([], signature_contract_errors(correct))

        legacy_fixtures = (
            "数字签名利用非对称加密的逆运用。签名方用私钥对消息的哈希值进行加密，"
            "验证方用公钥解密签名。",
            "数字签名使用发送方私钥对消息摘要加密，接收方用发送方公钥验证。",
            "接收方用发送方公钥解密签名，恢复出摘要值；"
            "发送方用自己的私钥对摘要加密，生成数字签名。",
        )
        for fixture in legacy_fixtures:
            with self.subTest(fixture=fixture):
                rejected = [
                    error
                    for error in signature_contract_errors(fixture)
                    if error.startswith("contains rejected fact:")
                ]
                self.assertTrue(rejected)

    def test_flow_rejects_prehash_interfaces_and_unbound_public_keys(self):
        correct_events = (
            {"id": "B", "operation": "select_scheme"},
            {"id": "D", "operation": "sign", "input": "message"},
            {"id": "E", "operation": "receive"},
            {"id": "A", "operation": "check_policy"},
            {"id": "C", "operation": "verify", "input": "message"},
        )
        self.assertEqual([], run_signature_flow(correct_events, trusted_key_bound=True))

        prehash_events = tuple(
            {**event, "input": "digest"}
            if event["operation"] in ("sign", "verify")
            else event
            for event in correct_events
        )
        self.assertEqual(
            [
                "RFC 8017 signing input must be the original message M",
                "RFC 8017 verification input must be the original message M",
            ],
            run_signature_flow(prehash_events, trusted_key_bound=True),
        )
        self.assertEqual(
            ["identity authentication requires a trusted bound public key"],
            run_signature_flow(correct_events, trusted_key_bound=False),
        )
        verify_before_policy = (
            correct_events[0],
            correct_events[1],
            correct_events[2],
            correct_events[4],
            correct_events[3],
        )
        self.assertIn(
            "verification requires algorithm policy checking",
            run_signature_flow(verify_before_policy, trusted_key_bound=True),
        )
        duplicate_verify = (*correct_events, correct_events[-1])
        self.assertIn(
            "signature events must be B → D → E → A → C, got B → D → E → A → C → C",
            run_signature_flow(duplicate_verify, trusted_key_bound=True),
        )

    def test_web_and_raw_knowledge_and_quiz_share_the_correct_model(self):
        web_knowledge = extract_web_knowledge(
            self.web_knowledge_source, "cs103_k46"
        )
        raw_knowledge = find_unique(self.raw_knowledge, "cs103_k46")
        self.assertEqual(web_knowledge, raw_knowledge)
        self.assertIn("NIST FIPS 186-5", web_knowledge["source"])
        self.assertIn("RFC 8017第8.1.1节、第8.1.2节", web_knowledge["source"])

        web_quiz = extract_web_choice(self.web_quizzes_source, "cs103_q52")
        raw_quiz = find_unique(self.raw_quizzes, "cs103_q52")
        for key in ("question", "options", "answer", "explanation"):
            self.assertEqual(web_quiz[key], raw_quiz[key])
        self.assertEqual("cs103", raw_quiz["courseId"])
        self.assertEqual("网络安全基础", raw_quiz["topic"])

        live_models = {
            "knowledge": web_knowledge["text"],
            "quiz": "\n".join(
                [web_quiz["question"], *web_quiz["options"], web_quiz["explanation"]]
            ),
        }
        for surface, live_model in live_models.items():
            with self.subTest(surface=surface):
                self.assertEqual([], signature_contract_errors(live_model))

    def test_active_learning_spec_uses_sign_and_verify_algorithms(self):
        topic = extract_topic_section(self.spec, "网络安全基础")
        activity = parse_signature_activity(topic)
        self.assertEqual([], signature_activity_contract_errors(activity))
        self.assertIn("RFC 8017第8.1.1节、第8.1.2节", topic)
        self.assertEqual([], signature_contract_errors(topic))

        unbound_options = dict(activity["options"])
        unbound_options["C"] = (
            "接收方以攻击者提供的未绑定公钥调用验证算法；备忘："
            + SIGNATURE_OPTIONS["C"]
        )
        unbound_activity = {**activity, "options": unbound_options}
        self.assertIn(
            "signature option C does not match its fact contract",
            signature_activity_contract_errors(unbound_activity),
        )

        duplicate_answer = {
            **activity,
            "answer_labels": (*SIGNATURE_ORDER, "C"),
        }
        duplicate_errors = signature_activity_contract_errors(duplicate_answer)
        self.assertTrue(
            any(error.startswith("signature answer must be") for error in duplicate_errors)
        )
        self.assertTrue(
            any(error.startswith("signature events must be") for error in duplicate_errors)
        )


if __name__ == "__main__":
    unittest.main()
