"""Executable RFC contract for the CS103 DNS SOA lesson.

Verified primary references:
- RFC 1035 Section 3.3.13:
  https://www.rfc-editor.org/rfc/rfc1035.html#section-3.3.13
  The final SOA field is named MINIMUM. RFC 1035's original zone-wide
  minimum interpretation was later updated by RFC 2308.
- RFC 2308 Sections 4 and 5:
  https://www.rfc-editor.org/rfc/rfc2308.html#section-4
  https://www.rfc-editor.org/rfc/rfc2308.html#section-5
  SOA.MINIMUM is now defined only for negative caching. Missing resource
  record TTLs use the master-file ``$TTL`` directive instead. A negative
  answer's cache TTL is the smaller of SOA.MINIMUM and the SOA RR's TTL.
"""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "docs/ACTIVE-LEARNING-SPEC-CS103.md"
WEB_KNOWLEDGE_PATH = ROOT / "apps/web/src/lib/data/cs103-knowledge.ts"
KNOWLEDGE_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
)
EXPERIENCES_PATH = (
    ROOT
    / "apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json"
)

TOPIC_PATTERN = re.compile(r"^## Topic \d+: (.+)$", re.MULTILINE)
ACTIVITY_PATTERN = re.compile(
    r"^### 主动练习 (\d+)（[^）]+）\s*$",
    re.MULTILINE,
)
FIELD_PATTERN = re.compile(r"^- \*\*([^*]+)\*\*：\s*(.*)$")
DEFAULT_TTL_PATTERN = re.compile(r"^\s*\$TTL\s+(\d+)\b", re.MULTILINE)
SOA_MINIMUM_PATTERN = re.compile(
    r"^\s*(\d+)\s*\)\s*;\s*([^\r\n]+)$",
    re.MULTILINE,
)


CORRECT_ZONE_FIXTURE = """\
$TTL 3600
example.com.    IN  SOA   ns1.example.com. admin.example.com. (
                        2026010101 ; serial
                        3600       ; refresh
                        1800       ; retry
                        604800     ; expire
                        86400 )    ; negative cache TTL parameter

www             IN  A       93.184.216.34
"""

LEGACY_ZONE_FIXTURE = """\
$TTL 3600
example.com.    IN  SOA   ns1.example.com. admin.example.com. (
                        2026010101 ; serial
                        3600       ; refresh
                        1800       ; retry
                        604800     ; expire
                        86400 )    ; 默认TTL

www             IN  A       93.184.216.34
"""


def compact(value):
    return re.sub(r"\s+", "", value)


def clean_markdown_code(value):
    value = re.sub(r"^```[^\n]*\n?", "", value.strip())
    value = re.sub(r"\n```$", "", value)
    return value.strip()


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
        r'\{\s*id: "'
        + re.escape(chunk_id)
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


def find_unique(items, label, predicate):
    matches = [item for item in items if predicate(item)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one {label}, got {len(matches)}")
    return matches[0]


def parse_zone_ttl_model(zone_text):
    default_matches = DEFAULT_TTL_PATTERN.findall(zone_text)
    minimum_matches = SOA_MINIMUM_PATTERN.findall(zone_text)
    if len(default_matches) != 1:
        raise ValueError(
            f"zone must declare exactly one $TTL directive, got {len(default_matches)}"
        )
    if len(minimum_matches) != 1:
        raise ValueError(
            f"zone must declare exactly one SOA MINIMUM field, got {len(minimum_matches)}"
        )

    default_ttl = int(default_matches[0])
    soa_minimum, comment = minimum_matches[0]
    normalized_comment = compact(comment).lower()
    describes_negative_cache = (
        "negativecache" in normalized_comment
        or ("否定" in normalized_comment and "缓存" in normalized_comment)
    )
    if not describes_negative_cache or "默认ttl" in normalized_comment:
        raise ValueError(
            "SOA MINIMUM must be labeled as a negative-cache TTL parameter, "
            "not the default RR TTL"
        )

    soa_minimum_ttl = int(soa_minimum)
    return {
        "default_rr_ttl": default_ttl,
        "soa_minimum": soa_minimum_ttl,
        "negative_cache_ttl": min(default_ttl, soa_minimum_ttl),
    }


class DnsSoaMinimumContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec_source = SPEC_PATH.read_text(encoding="utf-8")
        cls.web_knowledge_source = WEB_KNOWLEDGE_PATH.read_text(encoding="utf-8")
        cls.knowledge = json.loads(KNOWLEDGE_PATH.read_text(encoding="utf-8"))
        cls.experiences = json.loads(EXPERIENCES_PATH.read_text(encoding="utf-8"))

    def test_zone_model_separates_default_and_negative_cache_ttl(self):
        self.assertEqual(
            parse_zone_ttl_model(CORRECT_ZONE_FIXTURE),
            {
                "default_rr_ttl": 3600,
                "soa_minimum": 86400,
                "negative_cache_ttl": 3600,
            },
        )
        with self.assertRaisesRegex(
            ValueError,
            "SOA MINIMUM must be labeled as a negative-cache TTL parameter",
        ):
            parse_zone_ttl_model(LEGACY_ZONE_FIXTURE)

    def test_spec_and_generated_activity_use_rfc2308_soa_semantics(self):
        fields = extract_activity(self.spec_source, "DNS系统", 2)
        spec_zone = clean_markdown_code(fields["代码"])
        experience = find_unique(
            self.experiences,
            "DNS系统 lesson experience",
            lambda item: item.get("courseId") == "cs103"
            and item.get("topic") == "DNS系统",
        )
        activity = find_unique(
            experience.get("activities", []),
            "DNS系统 code_fill activity",
            lambda item: item.get("id") == "cs103-DNS系统-2"
            and item.get("type") == "code_fill",
        )
        generated_zone = re.sub(r"^代码：\s*", "", activity["content"]).strip()

        self.assertEqual(generated_zone, spec_zone)
        self.assertEqual(
            parse_zone_ttl_model(spec_zone),
            parse_zone_ttl_model(generated_zone),
        )
        for source in (fields["来源"], activity["source"]):
            self.assertIn("RFC2308第4节", compact(source))

    def test_k39_is_identical_offline_and_cites_the_updated_semantics(self):
        web_text, web_source = extract_web_chunk(
            self.web_knowledge_source,
            "cs103_k39",
        )
        raw_chunk = find_unique(
            self.knowledge,
            "cs103_k39 raw knowledge chunk",
            lambda item: item.get("id") == "cs103_k39",
        )

        self.assertEqual(raw_chunk["text"], web_text)
        self.assertEqual(raw_chunk["source"], web_source)
        normalized_text = compact(web_text)
        self.assertIn("SOA", normalized_text)
        self.assertIn("MINIMUM", normalized_text)
        self.assertIn("否定缓存", normalized_text)
        self.assertIn("$TTL指令为未显式给出TTL的资源记录提供默认TTL", normalized_text)
        self.assertIn("不能再把MINIMUM解释为普通资源记录的默认TTL", normalized_text)
        self.assertNotIn("刷新间隔和默认TTL", normalized_text)
        self.assertIn("RFC2308第4节", compact(web_source))


if __name__ == "__main__":
    unittest.main()
