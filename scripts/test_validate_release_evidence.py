import importlib.util
import json
import unittest
from copy import deepcopy
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("validate-release-evidence.py")
SPEC = importlib.util.spec_from_file_location("validate_release_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SOURCE_COMMIT = "a" * 40
HAP_SHA256 = "b" * 64
RECORDED_AT = "2026-07-17T12:00:00+08:00"


def record(record_id: str, level: str = "未验证") -> dict[str, object]:
    return {
        "id": record_id,
        "claim": f"{record_id} 发布事实",
        "level": level,
        "recordedAt": RECORDED_AT,
        "command": None,
        "exitCode": None,
        "environment": None,
        "artifacts": [],
        "businessChecks": [],
        "notes": "固定输入保持未验证，不代表产品流程通过",
    }


def valid_document() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "sourceCommit": SOURCE_COMMIT,
        "hapSha256": HAP_SHA256,
        "records": [record(record_id) for record_id in sorted(MODULE.REQUIRED_RECORD_IDS)],
        "limitations": ["固定输入不证明模拟器、真机、线上或门户上传通过"],
    }


def encoded(document: dict[str, object]) -> bytes:
    return json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )


class ReleaseEvidenceGateTests(unittest.TestCase):
    def check(self, document: dict[str, object]) -> tuple[MODULE.EvidenceIndexMetrics, list[str]]:
        return MODULE.validate_release_evidence(
            encoded(document),
            SOURCE_COMMIT,
            HAP_SHA256,
        )

    def test_minimal_honest_index_covers_all_release_surfaces(self) -> None:
        metrics, errors = self.check(valid_document())

        self.assertEqual([], errors)
        self.assertEqual(7, metrics.records)
        self.assertEqual(0, metrics.verified_records)
        self.assertEqual(7, metrics.unverified_records)

    def test_commit_hap_schema_and_exact_fields_are_bound(self) -> None:
        document = valid_document()
        document["sourceCommit"] = "c" * 40
        document["hapSha256"] = "d" * 64
        document["schemaVersion"] = 2
        document["extra"] = True

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("schemaVersion 必须为 1", output)
        self.assertIn("sourceCommit 与 release-manifest.json 不一致", output)
        self.assertIn("hapSha256 与实际 HAP 字节不一致", output)
        self.assertIn("包含未定义字段: extra", output)

    def test_required_ids_and_uniqueness_cannot_be_bypassed(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        records.pop()
        records.append(deepcopy(records[0]))

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("record id 重复", output)
        self.assertIn("缺少发布面", output)

        extra_document = valid_document()
        extra_records = extra_document["records"]
        assert isinstance(extra_records, list)
        extra_records.append(record("unexpected-surface"))

        _, extra_errors = self.check(extra_document)
        extra_output = "\n".join(extra_errors)
        self.assertIn("records 数量必须恰好为 7", extra_output)
        self.assertIn("包含未定义发布面: unexpected-surface", extra_output)

    def test_command_and_build_levels_require_success_and_artifact(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        web = next(item for item in records if item["id"] == "web-validation")
        harmony = next(item for item in records if item["id"] == "harmonyos-build")
        web["level"] = "静态诊断通过"
        web["command"] = "pnpm lint"
        web["exitCode"] = 1
        harmony["level"] = "构建通过"
        harmony["command"] = "hvigorw assembleHap --no-daemon"
        harmony["exitCode"] = 0

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("静态诊断通过必须记录命令与 exitCode=0", output)
        self.assertIn("构建通过必须记录至少一个产物证据", output)

    def test_runtime_levels_require_environment_artifacts_and_business_checks(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        demo = next(item for item in records if item["id"] == "golden-demo")
        demo["level"] = "真机通过"

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("真机通过必须记录命令与 exitCode=0", output)
        self.assertIn("真机通过必须记录明确环境", output)
        self.assertIn("真机通过必须记录至少一个证据文件", output)
        self.assertIn("真机通过必须记录业务字段或流程检查", output)

    def test_unverified_record_cannot_carry_passing_evidence(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        record_item = records[0]
        record_item["command"] = "python -B scripts/validate-competition-content.py"
        record_item["exitCode"] = 0
        record_item["environment"] = "Windows 11; Python 3"
        record_item["artifacts"] = ["静态报告"]
        record_item["businessChecks"] = ["结构通过"]

        _, errors = self.check(document)

        self.assertTrue(any("未验证状态不得夹带通过证据" in error for error in errors))

    def test_timestamp_lists_duplicate_keys_and_size_limits_are_rejected(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        records[0]["recordedAt"] = "2026-07-17T12:00:00"
        document["limitations"] = []
        _, errors = self.check(document)
        duplicate_json = (
            b'{"schemaVersion":1,"schemaVersion":1,"sourceCommit":"'
            + SOURCE_COMMIT.encode("ascii")
            + b'","hapSha256":"'
            + HAP_SHA256.encode("ascii")
            + b'","records":[],"limitations":[]}'
        )
        _, duplicate_errors = MODULE.validate_release_evidence(
            duplicate_json,
            SOURCE_COMMIT,
            HAP_SHA256,
        )
        _, size_errors = MODULE.validate_release_evidence(
            b" " * (MODULE.MAX_EVIDENCE_INDEX_BYTES + 1),
            SOURCE_COMMIT,
            HAP_SHA256,
        )

        output = "\n".join(errors + duplicate_errors + size_errors)
        self.assertIn("recordedAt 必须为含时区", output)
        self.assertIn("limitations 至少需要一项", output)
        self.assertIn("JSON 包含重复键", output)
        self.assertIn("超过内部上限", output)


if __name__ == "__main__":
    unittest.main()
