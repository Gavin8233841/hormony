import hashlib
import importlib.util
import io
import json
import subprocess
import unittest
from decimal import Decimal
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("validate-official-deliverables.py")
SPEC = importlib.util.spec_from_file_location(
    "validate_official_deliverables",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def ffprobe_output(
    duration: str,
    codec_types: list[str],
    format_name: str = "mov,mp4,m4a,3gp,3g2,mj2",
) -> bytes:
    return json.dumps(
        {
            "streams": [{"codec_type": codec_type} for codec_type in codec_types],
            "format": {"duration": duration, "format_name": format_name},
        }
    ).encode("utf-8")


class OfficialDeliverablesGateTests(unittest.TestCase):
    def test_safe_reason_codes_distinguish_tool_and_media_failures(self) -> None:
        errors = [
            "pdfinfo工具不可用",
            "pdfinfo工具执行超时",
            "pdfinfo工具返回非零退出码: 7",
            "MP4 至少需要一个视频流",
        ]

        self.assertEqual(
            (
                "mp4.media-invalid",
                "pdfinfo.nonzero",
                "pdfinfo.timeout",
                "pdfinfo.unavailable",
            ),
            MODULE.failure_reason_codes(errors),
        )

    def test_summary_json_contains_only_stable_reason_codes(self) -> None:
        secret = "MODEL_API_KEY=fixed-sensitive-value"
        output = io.StringIO()
        arguments = [
            "--pdf-path",
            secret + ".pdf",
            "--video-path",
            secret + ".mp4",
            "--bundle-path",
            secret + ".zip",
            "--team-name",
            "team",
            "--work-name",
            "work",
            "--pdfinfo-path",
            "C:/tools/pdfinfo.exe",
            "--ffprobe-path",
            "C:/tools/ffprobe.exe",
            "--summary-json",
        ]

        with mock.patch.object(
            MODULE,
            "validate_official_deliverables",
            return_value=([], ["ffprobe工具执行超时"]),
        ), mock.patch("sys.stdout", output):
            exit_code = MODULE.main(arguments)

        document = json.loads(output.getvalue())
        self.assertEqual(1, exit_code)
        self.assertEqual(
            {"status": "failed", "reasonCodes": ["ffprobe.timeout"]},
            document,
        )
        self.assertNotIn(secret, output.getvalue())

    def test_exact_filenames_and_wrong_names_or_suffixes(self) -> None:
        expected = MODULE.expected_filenames("鸿学队", "鸿学伴")

        self.assertEqual(
            (
                "01-作品说明文档+鸿学队.pdf",
                "02-演示视频+鸿学队.mp4",
                "03-鸿学伴+鸿学队.zip",
            ),
            expected,
        )
        with mock.patch.object(Path, "is_symlink", return_value=False), mock.patch.object(
            Path, "is_file", return_value=True
        ):
            errors = MODULE.artifact_path_errors(
                Path("01-作品说明文档+鸿学队.PDF"),
                expected[0],
                ".pdf",
                "PDF",
            )
        self.assertIn("PDF后缀必须精确为 .pdf", errors)
        self.assertIn("PDF文件名不符合正式命名合同", errors)

    def test_symlink_is_rejected_without_displaying_path(self) -> None:
        secret_path = Path("MODEL_API_KEY=do-not-print.pdf")
        with mock.patch.object(Path, "is_symlink", return_value=True), mock.patch.object(
            Path, "is_file", return_value=True
        ):
            errors = MODULE.artifact_path_errors(
                secret_path,
                secret_path.name,
                ".pdf",
                "PDF",
            )

        output = "\n".join(errors)
        self.assertIn("拒绝符号链接", output)
        self.assertNotIn("do-not-print", output)

    def test_hash_stream_uses_fixed_input_without_media_files(self) -> None:
        content = b"fixed-input-for-streaming-sha256"

        byte_count, digest = MODULE.hash_stream(io.BytesIO(content), chunk_bytes=3)

        self.assertEqual(len(content), byte_count)
        self.assertEqual(hashlib.sha256(content).hexdigest(), digest)
        with self.assertRaises(ValueError):
            MODULE.hash_stream(io.BytesIO(content), chunk_bytes=0)

    def test_pdf_page_boundary_is_20_and_21_fails(self) -> None:
        probe_1, errors_1 = MODULE.parse_pdfinfo_output(
            b"Pages: 1\nEncrypted: no\n"
        )
        probe_20, errors_20 = MODULE.parse_pdfinfo_output(
            b"Pages:          20\nEncrypted:      no\n"
        )
        probe_21, errors_21 = MODULE.parse_pdfinfo_output(
            b"Pages: 21\r\nEncrypted: no\r\n"
        )

        self.assertEqual(MODULE.PdfProbe(1, False), probe_1)
        self.assertEqual([], errors_1)
        self.assertEqual(MODULE.PdfProbe(20, False), probe_20)
        self.assertEqual([], errors_20)
        self.assertEqual(MODULE.PdfProbe(21, False), probe_21)
        self.assertIn("PDF 整份页数超过内部硬门禁 20 页", errors_21)

    def test_encrypted_pdf_is_rejected(self) -> None:
        probe, errors = MODULE.parse_pdfinfo_output(
            b"Pages: 20\nEncrypted: yes (print:yes copy:no)\n"
        )

        self.assertEqual(MODULE.PdfProbe(20, True), probe)
        self.assertIn("PDF 不得加密", errors)

    def test_pdfinfo_malformed_output_is_rejected(self) -> None:
        missing_pages, missing_errors = MODULE.parse_pdfinfo_output(b"Title: secret\n")
        duplicate_pages, duplicate_errors = MODULE.parse_pdfinfo_output(
            b"Pages: 20\nPages: 20\nEncrypted: no\n"
        )
        zero_pages, zero_errors = MODULE.parse_pdfinfo_output(
            b"Pages: 0\nEncrypted: no\n"
        )
        probe_without_encryption, encryption_errors = MODULE.parse_pdfinfo_output(
            b"Pages: 20\n"
        )
        duplicate_encryption, duplicate_encryption_errors = MODULE.parse_pdfinfo_output(
            b"Pages: 20\nEncrypted: no\nEncrypted: no\n"
        )

        self.assertIsNone(missing_pages)
        self.assertIsNone(duplicate_pages)
        self.assertIsNone(zero_pages)
        self.assertEqual(MODULE.PdfProbe(20, None), probe_without_encryption)
        self.assertEqual(MODULE.PdfProbe(20, None), duplicate_encryption)
        self.assertTrue(missing_errors)
        self.assertTrue(duplicate_errors)
        self.assertTrue(zero_errors)
        self.assertIn(
            "pdfinfo 输出缺少唯一有效 Encrypted 字段", encryption_errors
        )
        self.assertIn(
            "pdfinfo 输出缺少唯一有效 Encrypted 字段",
            duplicate_encryption_errors,
        )

    def test_video_duration_boundary_and_video_stream_requirement(self) -> None:
        below, below_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("299.999", ["video", "audio"])
        )
        equal, equal_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("300", ["video"])
        )
        above, above_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("300.001", ["video"])
        )
        no_video, no_video_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("10", ["audio"])
        )
        wrong_format, wrong_format_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("10", ["video"], "mov,xmp4")
        )
        zero, zero_errors = MODULE.parse_ffprobe_output(
            ffprobe_output("0", ["video"])
        )

        self.assertEqual(
            MODULE.VideoProbe(
                Decimal("299.999"),
                1,
                ("mov", "mp4", "m4a", "3gp", "3g2", "mj2"),
            ),
            below,
        )
        self.assertEqual([], below_errors)
        self.assertEqual(Decimal("300"), equal.duration_seconds)
        self.assertEqual([], equal_errors)
        self.assertEqual(Decimal("300.001"), above.duration_seconds)
        self.assertIn("MP4 时长不得超过 300 秒", above_errors)
        self.assertEqual(0, no_video.video_stream_count)
        self.assertIn("MP4 至少需要一个视频流", no_video_errors)
        self.assertEqual(("mov", "xmp4"), wrong_format.format_names)
        self.assertIn(
            "ffprobe format_name 必须包含精确的 mp4 token", wrong_format_errors
        )
        self.assertIsNone(zero)
        self.assertIn("MP4 时长必须是大于 0 的有限数值", zero_errors)

    def test_ffprobe_malformed_outputs_are_rejected(self) -> None:
        cases = (
            b"not-json",
            b"\xff",
            b"[]",
            b'{"streams":[],"format":{}}',
            b'{"streams":[null],"format":{"duration":"1","format_name":"mp4"}}',
            b'{"streams":[],"format":{"duration":"NaN","format_name":"mp4"}}',
        )

        for output in cases:
            with self.subTest(output=output[:12]):
                probe, errors = MODULE.parse_ffprobe_output(output)
                self.assertIsNone(probe)
                self.assertTrue(errors)

    def test_renamed_non_mp4_container_is_rejected(self) -> None:
        probe, errors = MODULE.parse_ffprobe_output(
            ffprobe_output("42", ["video"], "matroska,webm")
        )

        self.assertEqual(("matroska", "webm"), probe.format_names)
        self.assertIn(
            "ffprobe format_name 必须包含精确的 mp4 token",
            errors,
        )

    def test_tool_path_must_be_absolute_existing_regular_file(self) -> None:
        with mock.patch.object(Path, "is_symlink", return_value=False), mock.patch.object(
            Path, "is_file", return_value=False
        ):
            relative_errors = MODULE.tool_path_errors(Path("pdfinfo"), "pdfinfo")
            missing_errors = MODULE.tool_path_errors(
                Path("C:/tools/missing-pdfinfo.exe"), "pdfinfo"
            )

        self.assertIn("pdfinfo工具路径必须是绝对路径", relative_errors)
        self.assertIn("pdfinfo工具路径必须指向现有普通文件", relative_errors)
        self.assertNotIn("必须是绝对路径", "\n".join(missing_errors))
        self.assertIn("pdfinfo工具路径必须指向现有普通文件", missing_errors)

        with mock.patch.object(Path, "is_symlink", return_value=True), mock.patch.object(
            Path, "is_file", return_value=True
        ):
            symlink_errors = MODULE.tool_path_errors(
                Path("C:/tools/pdfinfo.exe"),
                "pdfinfo",
            )
        self.assertIn("pdfinfo工具拒绝符号链接", symlink_errors)

    def test_tool_missing_nonzero_timeout_and_output_do_not_leak(self) -> None:
        secret = b"MODEL_API_KEY=do-not-print"
        completed = subprocess.CompletedProcess(
            ["tool"],
            7,
            stdout=secret,
            stderr=secret,
        )
        scenarios = (
            FileNotFoundError(),
            subprocess.TimeoutExpired(["tool"], 1, output=secret, stderr=secret),
            completed,
        )

        for scenario in scenarios:
            with self.subTest(scenario=type(scenario).__name__), mock.patch.object(
                MODULE,
                "tool_path_errors",
                return_value=[],
            ), mock.patch.object(
                MODULE.subprocess,
                "run",
                side_effect=scenario if isinstance(scenario, BaseException) else None,
                return_value=None if isinstance(scenario, BaseException) else scenario,
            ):
                output, errors = MODULE.run_tool(
                    Path("C:/tools/tool.exe"), ["sensitive-path"], "probe", 1
                )
            self.assertIsNone(output)
            rendered = "\n".join(errors)
            self.assertNotIn(secret.decode("ascii"), rendered)
            self.assertNotIn("sensitive-path", rendered)

    def test_tool_uses_argument_array_timeout_and_c_locale(self) -> None:
        completed = subprocess.CompletedProcess(["pdfinfo"], 0, stdout=b"Pages: 1\n", stderr=b"")
        with mock.patch.object(MODULE, "tool_path_errors", return_value=[]), mock.patch.object(
            MODULE.subprocess, "run", return_value=completed
        ) as runner:
            output, errors = MODULE.run_tool(
                Path("C:/Program Files/pdfinfo.exe"),
                ["artifact.pdf"],
                "pdfinfo",
                3.5,
            )

        self.assertEqual(b"Pages: 1\n", output)
        self.assertEqual([], errors)
        kwargs = runner.call_args.kwargs
        self.assertEqual(
            [str(Path("C:/Program Files/pdfinfo.exe")), "artifact.pdf"],
            runner.call_args.args[0],
        )
        self.assertEqual(3.5, kwargs["timeout"])
        self.assertEqual("C", kwargs["env"]["LC_ALL"])
        self.assertEqual("C", kwargs["env"]["LANG"])
        self.assertIs(False, kwargs["shell"])

    def test_tool_output_limit_is_a_structured_failure(self) -> None:
        completed = subprocess.CompletedProcess(
            ["tool"],
            0,
            stdout=b"X" * (MODULE.MAX_TOOL_OUTPUT_BYTES + 1),
            stderr=b"",
        )
        with mock.patch.object(MODULE, "tool_path_errors", return_value=[]), mock.patch.object(
            MODULE.subprocess,
            "run",
            return_value=completed,
        ):
            output, errors = MODULE.run_tool(
                Path("C:/tools/tool.exe"),
                ["artifact"],
                "probe",
                1,
            )

        self.assertIsNone(output)
        self.assertEqual(["probe工具输出超过内部解析上限"], errors)

    def test_name_fields_reject_path_and_control_characters(self) -> None:
        for value in ("team/name", "team\\name", "team\x00name", "team\nname"):
            with self.subTest(value=repr(value)):
                self.assertTrue(MODULE._name_errors(value, "team-name"))

    def test_dynamic_import_disables_bytecode_writes(self) -> None:
        self.assertTrue(MODULE.sys.dont_write_bytecode)

    def test_release_gate_failure_is_generic_and_captured(self) -> None:
        secret = "MODEL_API_KEY=do-not-print"

        def failing_gate(_arguments: list[str]) -> int:
            print(secret)
            return 1

        outer = io.StringIO()
        with mock.patch.object(MODULE.RELEASE_GATE, "main", side_effect=failing_gate), mock.patch(
            "sys.stdout", outer
        ) as stdout:
            errors = MODULE.run_release_bundle_gate(Path("secret.zip"))

        rendered = "\n".join(errors) + outer.getvalue()
        self.assertIn("ZIP 未通过 validate-release-bundle.py，exit=1", rendered)
        self.assertNotIn(secret, rendered)

    def test_complete_validation_reuses_release_gate_and_reports_metrics(self) -> None:
        pdf = Path("01-作品说明文档+鸿学队.pdf")
        video = Path("02-演示视频+鸿学队.mp4")
        bundle = Path("03-鸿学伴+鸿学队.zip")
        hashes = {
            pdf: (101, "1" * 64),
            video: (202, "2" * 64),
            bundle: (303, "3" * 64),
        }
        with mock.patch.object(MODULE, "artifact_path_errors", return_value=[]), mock.patch.object(
            MODULE, "probe_pdf", return_value=(MODULE.PdfProbe(20, False), [])
        ), mock.patch.object(
            MODULE,
            "probe_video",
            return_value=(
                MODULE.VideoProbe(Decimal("299.999"), 1, ("mov", "mp4")),
                [],
            ),
        ), mock.patch.object(
            MODULE, "hash_file", side_effect=lambda path: hashes[path]
        ), mock.patch.object(
            MODULE, "run_release_bundle_gate", return_value=[]
        ) as release_gate:
            evidence, errors = MODULE.validate_official_deliverables(
                pdf,
                video,
                bundle,
                "鸿学队",
                "鸿学伴",
                Path("C:/tools/pdfinfo.exe"),
                Path("C:/tools/ffprobe.exe"),
            )

        self.assertEqual([], errors)
        self.assertEqual(["PDF", "MP4", "ZIP"], [item.label for item in evidence])
        self.assertEqual("pages=20; encrypted=no", evidence[0].details)
        self.assertEqual(
            "duration=299.999s; videoStreams=1; format=mov,mp4",
            evidence[1].details,
        )
        self.assertEqual("releaseBundleGate=passed", evidence[2].details)
        release_gate.assert_called_once_with(bundle, Path("C:/tools/ffprobe.exe"))

    def test_failed_video_format_evidence_reports_detected_container(self) -> None:
        pdf = Path("01-作品说明文档+鸿学队.pdf")
        video = Path("02-演示视频+鸿学队.mp4")
        bundle = Path("03-鸿学伴+鸿学队.zip")
        with mock.patch.object(MODULE, "artifact_path_errors", return_value=[]), mock.patch.object(
            MODULE,
            "probe_pdf",
            return_value=(MODULE.PdfProbe(1, False), []),
        ), mock.patch.object(
            MODULE,
            "probe_video",
            return_value=(
                MODULE.VideoProbe(Decimal("42"), 1, ("matroska", "webm")),
                ["ffprobe format_name 必须包含精确的 mp4 token"],
            ),
        ), mock.patch.object(
            MODULE,
            "hash_file",
            return_value=(1, "0" * 64),
        ), mock.patch.object(MODULE, "run_release_bundle_gate", return_value=[]):
            evidence, errors = MODULE.validate_official_deliverables(
                pdf,
                video,
                bundle,
                "鸿学队",
                "鸿学伴",
                Path("C:/tools/pdfinfo.exe"),
                Path("C:/tools/ffprobe.exe"),
            )

        video_evidence = next(item for item in evidence if item.label == "MP4")
        self.assertIn("ffprobe format_name 必须包含精确的 mp4 token", errors)
        self.assertEqual(
            "duration=42s; videoStreams=1; format=matroska,webm",
            video_evidence.details,
        )


if __name__ == "__main__":
    unittest.main()
