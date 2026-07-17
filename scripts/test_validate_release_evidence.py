import importlib.util
import hashlib
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
ARTIFACT_CONTENT = b"fixed schema evidence; not product runtime evidence"


def record(record_id: str, level: str = "未验证") -> dict[str, object]:
    return {
        "id": record_id,
        "claim": f"{record_id} 发布事实",
        "level": level,
        "recordedAt": RECORDED_AT,
        "command": None,
        "exitCode": None,
        "environment": {},
        "artifacts": [],
        "businessChecks": [],
        "notes": "固定输入保持未验证，不代表产品流程通过",
    }


def environment_for_command() -> dict[str, object]:
    return {
        "os": "Windows 11",
        "tool": "python",
        "toolVersion": "3.12",
    }


def environment_for_online() -> dict[str, object]:
    return {
        "deploymentVersion": "deployment-20260717",
        "requests": [
            {
                "id": request_id,
                "method": MODULE.WEB_REQUEST_METHODS_AND_PATHS[request_id][0],
                "endpoint": (
                    "https://service.example.invalid"
                    + MODULE.WEB_REQUEST_METHODS_AND_PATHS[request_id][1]
                ),
                "httpStatus": 200,
            }
            for request_id in sorted(MODULE.WEB_ONLINE_REQUEST_IDS)
        ],
    }


def artifact(
    path: str,
    kind: str,
    content: bytes = ARTIFACT_CONTENT,
) -> dict[str, object]:
    return {
        "path": path,
        "kind": kind,
        "bytes": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
    }


def business_check(check_id: str, actual: object | None = None) -> dict[str, object]:
    if actual is None:
        if check_id == "health.status":
            actual = "ready"
        elif check_id == "health.model":
            actual = "exact-model-id"
        elif check_id == "health.deployment":
            actual = "deployment-20260717"
        elif check_id == "chat.body":
            actual = 128
        elif check_id == "chat.citations-as-returned":
            actual = 2
        elif check_id == "plan.task-count":
            actual = 3
        else:
            actual = True
    return {
        "id": check_id,
        "passed": True,
        "actual": actual,
    }


def valid_document() -> dict[str, object]:
    return {
        "schemaVersion": MODULE.SCHEMA_VERSION,
        "sourceCommit": SOURCE_COMMIT,
        "hapSha256": HAP_SHA256,
        "records": [record(record_id) for record_id in sorted(MODULE.REQUIRED_RECORD_IDS)],
        "limitations": ["固定输入不证明模拟器、真机、线上或门户上传通过"],
    }


def online_web_document() -> tuple[dict[str, object], dict[str, bytes]]:
    document = valid_document()
    records = document["records"]
    assert isinstance(records, list)
    web = next(item for item in records if item["id"] == "web-validation")
    artifact_path = "evidence/web-online.log"
    web["level"] = "线上通过"
    web["command"] = ["node", "scripts/test-chat.mjs"]
    web["exitCode"] = 0
    web["environment"] = environment_for_online()
    web["artifacts"] = [artifact(artifact_path, "log")]
    web["businessChecks"] = [
        business_check(check_id) for check_id in sorted(MODULE.WEB_ONLINE_CHECK_IDS)
    ]
    return document, {artifact_path: ARTIFACT_CONTENT}


def encoded(document: dict[str, object]) -> bytes:
    return json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )


class ReleaseEvidenceGateTests(unittest.TestCase):
    def check(
        self,
        document: dict[str, object],
        available_artifacts: dict[str, bytes] | None = None,
    ) -> tuple[MODULE.EvidenceIndexMetrics, list[str]]:
        return MODULE.validate_release_evidence(
            encoded(document),
            SOURCE_COMMIT,
            HAP_SHA256,
            available_artifacts,
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
        document["schemaVersion"] = 1
        document["extra"] = True

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("schemaVersion 必须为 2", output)
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
        web["command"] = ["pnpm", "lint"]
        web["exitCode"] = 1
        web["environment"] = environment_for_command()
        web["artifacts"] = [artifact("evidence/web-lint.txt", "diagnostic")]
        harmony["level"] = "构建通过"
        harmony["command"] = ["hvigorw", "assembleHap", "--no-daemon"]
        harmony["exitCode"] = 0
        harmony["environment"] = environment_for_command()

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("静态诊断通过必须记录 argv 与 exitCode=0", output)
        self.assertIn("构建通过必须记录 build 或 hap 产物", output)
        self.assertIn("HarmonyOS 构建必须记录与顶层绑定一致的 hap 产物", output)

    def test_runtime_levels_require_environment_artifacts_and_business_checks(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        demo = next(item for item in records if item["id"] == "golden-demo")
        demo["level"] = "真机通过"

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("真机通过必须记录 argv 与 exitCode=0", output)
        self.assertIn("environment 缺少字段", output)
        self.assertIn("真机通过必须记录至少一个证据文件", output)
        self.assertIn("真机通过必须记录业务字段或流程检查", output)
        self.assertIn("真机通过必须记录 UI 树、截图、视频或日志", output)

    def test_unverified_record_cannot_carry_passing_evidence(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        record_item = records[0]
        record_item["command"] = [
            "python",
            "-B",
            "scripts/validate-competition-content.py",
        ]
        record_item["exitCode"] = 0
        record_item["artifacts"] = [artifact("evidence/report.txt", "diagnostic")]
        record_item["businessChecks"] = [business_check("structure.pass")]

        _, errors = self.check(document)

        self.assertTrue(any("未验证状态不得夹带通过证据" in error for error in errors))

    def test_v1_free_text_runtime_evidence_is_rejected(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        web = next(item for item in records if item["id"] == "web-validation")
        web["level"] = "线上通过"
        web["command"] = "curl endpoint"
        web["exitCode"] = 0
        web["environment"] = "HTTP 200"
        web["artifacts"] = ["output"]
        web["businessChecks"] = ["ok"]

        _, errors = self.check(document)
        output = "\n".join(errors)

        self.assertIn("command 必须为 argv 字符串数组或 null", output)
        self.assertIn("environment 必须为对象", output)
        self.assertIn("artifacts[0] 必须为对象", output)
        self.assertIn("businessChecks[0] 必须为对象", output)

    def test_online_web_requires_exact_requests_checks_and_bound_artifact(self) -> None:
        document, available_artifacts = online_web_document()

        metrics, errors = self.check(document, available_artifacts)

        self.assertEqual([], errors)
        self.assertEqual(1, metrics.verified_records)
        self.assertEqual(6, metrics.unverified_records)

        _, no_resolver_errors = self.check(document)
        self.assertTrue(any("无实际字节 resolver" in error for error in no_resolver_errors))

        invalid = deepcopy(document)
        records = invalid["records"]
        assert isinstance(records, list)
        web = next(item for item in records if item["id"] == "web-validation")
        environment = web["environment"]
        assert isinstance(environment, dict)
        requests = environment["requests"]
        assert isinstance(requests, list)
        requests[:] = [request for request in requests if request["id"] != "quiz"]
        health_request = next(request for request in requests if request["id"] == "health")
        health_request["method"] = "POST"
        chat_request = next(request for request in requests if request["id"] == "chat")
        chat_request["httpStatus"] = 204
        plan_request = next(request for request in requests if request["id"] == "plan")
        plan_request["endpoint"] = "https://other.example.invalid/api/plan"
        checks = web["businessChecks"]
        assert isinstance(checks, list)
        checks[:] = [check for check in checks if check["id"] != "quiz.grading-shape"]
        next(check for check in checks if check["id"] == "chat.done")["actual"] = "true"
        next(check for check in checks if check["id"] == "health.deployment")[
            "actual"
        ] = "different-deployment"

        _, invalid_errors = self.check(
            invalid,
            {"evidence/web-online.log": b"different artifact bytes"},
        )
        output = "\n".join(invalid_errors)

        self.assertIn("必须为 GET /api/health", output)
        self.assertIn("requests 必须使用同一 HTTPS origin", output)
        self.assertIn("Web 线上四类请求必须全部为 HTTP 200", output)
        self.assertIn("缺少固定请求证据: quiz", output)
        self.assertIn("缺少固定业务检查: quiz.grading-shape", output)
        self.assertIn("chat.done", output)
        self.assertIn("actual 必须为 true", output)
        self.assertIn("health.deployment 必须等于 deploymentVersion", output)
        self.assertIn("sha256 与实际发布包条目不一致", output)

    def test_device_environment_uses_structured_resolution(self) -> None:
        document = valid_document()
        records = document["records"]
        assert isinstance(records, list)
        demo = next(item for item in records if item["id"] == "golden-demo")
        artifact_path = "evidence/device-ui-tree.json"
        demo["level"] = "真机通过"
        demo["command"] = ["hdc", "shell", "uitest", "dumpLayout"]
        demo["exitCode"] = 0
        demo["environment"] = {
            "device": "fixed-device-id",
            "systemVersion": "HarmonyOS 5.0.0",
            "orientation": "portrait",
            "resolution": {"widthPx": 1260, "heightPx": 2720},
        }
        demo["artifacts"] = [artifact(artifact_path, "ui-tree")]
        demo["businessChecks"] = [business_check("demo.flow-complete")]

        _, errors = self.check(document, {artifact_path: ARTIFACT_CONTENT})
        self.assertEqual([], errors)

        invalid = deepcopy(document)
        invalid_records = invalid["records"]
        assert isinstance(invalid_records, list)
        invalid_demo = next(
            item for item in invalid_records if item["id"] == "golden-demo"
        )
        invalid_environment = invalid_demo["environment"]
        assert isinstance(invalid_environment, dict)
        invalid_environment["resolution"] = "1260x2720"

        _, invalid_errors = self.check(invalid, {artifact_path: ARTIFACT_CONTENT})
        self.assertTrue(any("resolution 必须为对象" in error for error in invalid_errors))

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
