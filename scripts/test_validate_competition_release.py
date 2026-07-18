import importlib.util
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("validate-competition-release.py")
SPEC = importlib.util.spec_from_file_location(
    "validate_competition_release",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def fixed_arguments() -> list[str]:
    return [
        "--pdf-path",
        "C:/release/01-works.pdf",
        "--video-path",
        "C:/release/02-demo.mp4",
        "--bundle-path",
        "C:/release/03-source.zip",
        "--team-name",
        "HongXueTeam",
        "--work-name",
        "HongXueBan",
        "--pdfinfo-path",
        "C:/tools/pdfinfo.exe",
        "--ffprobe-path",
        "C:/tools/ffprobe.exe",
        "--stage-timeout-seconds",
        "37",
        "--tool-timeout-seconds",
        "19",
    ]


FIXED_HEAD = "a" * 40


def successful_process(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")


def official_process(
    return_code: int = 0,
    reason_codes: tuple[str, ...] = (),
) -> subprocess.CompletedProcess[bytes]:
    status = "passed" if return_code == 0 else "failed"
    payload = json.dumps(
        {"status": status, "reasonCodes": list(reason_codes)},
        separators=(",", ":"),
    ).encode("utf-8")
    return subprocess.CompletedProcess(
        ["official"],
        return_code,
        stdout=payload,
        stderr=b"",
    )


def clean_repository_probes() -> list[object]:
    snapshot = MODULE.RepositorySnapshot(FIXED_HEAD, False)
    return [
        MODULE.RepositoryProbe(snapshot, "ready", None),
        MODULE.RepositoryProbe(snapshot, "ready", None),
    ]


class CompetitionReleasePreflightTests(unittest.TestCase):
    def test_stage_order_and_exact_argument_arrays_are_fixed(self) -> None:
        args = MODULE.parse_args(fixed_arguments())

        with mock.patch.object(MODULE, "official_input_issues", return_value=()):
            stages = MODULE.build_stage_specs(args)

        self.assertEqual(
            (
                "release-dependencies",
                "competition-evidence",
                "competition-content",
                "official-deliverables",
            ),
            tuple(stage.name for stage in stages),
        )
        self.assertEqual(
            (sys.executable, "-B", str(MODULE.DEPENDENCY_GATE_PATH)),
            stages[0].command,
        )
        self.assertEqual(
            (sys.executable, "-B", str(MODULE.EVIDENCE_GATE_PATH)),
            stages[1].command,
        )
        self.assertEqual(
            (
                sys.executable,
                "-B",
                str(MODULE.CONTENT_GATE_PATH),
                "--require-notice-ready",
            ),
            stages[2].command,
        )
        self.assertEqual(
            (
                sys.executable,
                "-B",
                str(MODULE.OFFICIAL_GATE_PATH),
                "--pdf-path",
                str(args.pdf_path),
                "--video-path",
                str(args.video_path),
                "--bundle-path",
                str(args.bundle_path),
                "--team-name",
                args.team_name,
                "--work-name",
                args.work_name,
                "--pdfinfo-path",
                str(args.pdfinfo_path),
                "--ffprobe-path",
                str(args.ffprobe_path),
                "--tool-timeout-seconds",
                "19",
                "--summary-json",
            ),
            stages[3].command,
        )
        self.assertFalse(stages[0].capture_summary)
        self.assertTrue(stages[3].capture_summary)

    def test_stage_runner_uses_no_shell_fixed_root_and_suppressed_output(self) -> None:
        command = (sys.executable, "-B", str(MODULE.CONTENT_GATE_PATH))
        stage = MODULE.StageSpec("competition-content", command, (), False)
        completed = successful_process(list(command))

        with mock.patch.object(MODULE.subprocess, "run", return_value=completed) as runner:
            result = MODULE.run_stage(stage, 23.5)

        self.assertEqual(
            MODULE.StageResult("competition-content", "passed", 0, (), (), None),
            result,
        )
        self.assertEqual(list(command), runner.call_args.args[0])
        kwargs = runner.call_args.kwargs
        self.assertEqual(MODULE.ROOT, kwargs["cwd"])
        self.assertEqual(23.5, kwargs["timeout"])
        self.assertIs(False, kwargs["shell"])
        self.assertIs(False, kwargs["check"])
        self.assertIs(subprocess.DEVNULL, kwargs["stdin"])
        self.assertIs(subprocess.DEVNULL, kwargs["stdout"])
        self.assertIs(subprocess.DEVNULL, kwargs["stderr"])
        self.assertEqual("1", kwargs["env"]["PYTHONDONTWRITEBYTECODE"])
        self.assertEqual("1", kwargs["env"]["PYTHONUTF8"])

    def test_fixed_success_runs_all_stages_and_reports_pass(self) -> None:
        output = io.StringIO()
        completed = [
            successful_process(["dependencies"]),
            successful_process(["evidence"]),
            successful_process(["content"]),
            official_process(),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ) as runner, mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(0, exit_code)
        self.assertEqual(4, runner.call_count)
        self.assertEqual(4, rendered.count("status=passed"))
        self.assertIn(
            "passed=4; failed=0; timeout=0; launch-error=0",
            rendered,
        )
        self.assertIn("ALL CHECKS PASSED", rendered)

    def test_nonzero_stage_does_not_stop_later_checks_or_echo_output(self) -> None:
        secret = "MODEL_API_KEY=fixed-sensitive-value"
        output = io.StringIO()
        completed = [
            successful_process(["dependencies"]),
            subprocess.CompletedProcess(
                ["evidence"],
                7,
                stdout=secret.encode("utf-8"),
                stderr=secret.encode("utf-8"),
            ),
            successful_process(["content"]),
            official_process(),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ) as runner, mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(1, exit_code)
        self.assertEqual(4, runner.call_count)
        self.assertIn(
            "stage=competition-evidence; status=failed; exit=7",
            rendered,
        )
        self.assertIn("passed=3; failed=1; timeout=0; launch-error=0", rendered)
        self.assertNotIn(secret, rendered)

    def test_timeout_and_launch_error_are_structured_without_secret_echo(self) -> None:
        secret = "AUTHORIZATION=fixed-sensitive-value"
        output = io.StringIO()
        effects = [
            subprocess.TimeoutExpired(
                [secret],
                37,
                output=secret.encode("utf-8"),
                stderr=secret.encode("utf-8"),
            ),
            FileNotFoundError(secret),
            successful_process(["content"]),
            official_process(),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=effects,
        ) as runner, mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(1, exit_code)
        self.assertEqual(4, runner.call_count)
        self.assertIn("stage=release-dependencies; status=timeout", rendered)
        self.assertIn(
            "stage=competition-evidence; status=launch-error; errorType=FileNotFoundError",
            rendered,
        )
        self.assertIn("passed=2; failed=0; timeout=1; launch-error=1", rendered)
        self.assertNotIn(secret, rendered)

    def test_missing_media_and_tools_fail_without_launching_official_stage(self) -> None:
        output = io.StringIO()
        completed = [
            successful_process(["dependencies"]),
            successful_process(["evidence"]),
            successful_process(["content"]),
        ]
        issues = ("PDF", "MP4", "ZIP", "pdfinfo", "ffprobe")

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=issues), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ) as runner, mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(1, exit_code)
        self.assertEqual(3, runner.call_count)
        self.assertIn(
            "stage=official-deliverables; status=failed; invalidInputs=PDF,MP4,ZIP,pdfinfo,ffprobe",
            rendered,
        )
        self.assertNotIn("C:/release", rendered)
        self.assertNotIn("C:\\release", rendered)

    def test_repository_probe_reads_exact_head_and_full_dirty_state(self) -> None:
        head = subprocess.CompletedProcess(
            ["git"],
            0,
            stdout=(FIXED_HEAD + "\n").encode("ascii"),
            stderr=b"",
        )
        clean = subprocess.CompletedProcess(["git"], 0, stdout=b"", stderr=b"")

        with mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=[head, clean],
        ) as runner:
            probe = MODULE.read_repository_state(11.0)

        self.assertEqual(
            MODULE.RepositoryProbe(
                MODULE.RepositorySnapshot(FIXED_HEAD, False),
                "ready",
                None,
            ),
            probe,
        )
        self.assertEqual(
            [MODULE.GIT_COMMAND, "rev-parse", "--verify", "HEAD"],
            runner.call_args_list[0].args[0],
        )
        self.assertEqual(
            [
                MODULE.GIT_COMMAND,
                "status",
                "--porcelain=v1",
                "-z",
                "--untracked-files=all",
            ],
            runner.call_args_list[1].args[0],
        )
        for call in runner.call_args_list:
            self.assertEqual(MODULE.ROOT, call.kwargs["cwd"])
            self.assertEqual(11.0, call.kwargs["timeout"])
            self.assertIs(subprocess.PIPE, call.kwargs["stdout"])
            self.assertIs(subprocess.DEVNULL, call.kwargs["stderr"])
            self.assertIs(False, call.kwargs["shell"])

    def test_dirty_repository_fails_before_any_release_stage(self) -> None:
        output = io.StringIO()
        dirty = MODULE.RepositoryProbe(
            MODULE.RepositorySnapshot(FIXED_HEAD, True),
            "ready",
            None,
        )

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            return_value=dirty,
        ), mock.patch.object(MODULE.subprocess, "run") as runner, mock.patch(
            "sys.stdout",
            output,
        ):
            exit_code = MODULE.main(fixed_arguments())

        self.assertEqual(1, exit_code)
        runner.assert_not_called()
        self.assertIn("repository-state; status=dirty", output.getvalue())
        self.assertNotIn("stage=release-dependencies", output.getvalue())

    def test_head_change_during_stages_fails_same_version_binding(self) -> None:
        output = io.StringIO()
        before = MODULE.RepositoryProbe(
            MODULE.RepositorySnapshot("a" * 40, False),
            "ready",
            None,
        )
        after = MODULE.RepositoryProbe(
            MODULE.RepositorySnapshot("b" * 40, False),
            "ready",
            None,
        )
        completed = [
            successful_process(["dependencies"]),
            successful_process(["evidence"]),
            successful_process(["content"]),
            official_process(),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=[before, after],
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ), mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        self.assertEqual(1, exit_code)
        self.assertIn("repository-stability; status=head-changed", output.getvalue())
        self.assertIn("SOME CHECKS FAILED", output.getvalue())

    def test_official_reason_codes_are_reported_without_child_output(self) -> None:
        secret = "MODEL_API_KEY=fixed-sensitive-value"
        reason_codes = (
            "mp4.media-invalid",
            "pdfinfo.nonzero",
            "pdfinfo.timeout",
            "pdfinfo.unavailable",
        )
        output = io.StringIO()
        completed = [
            successful_process(["dependencies"]),
            successful_process(["evidence"]),
            successful_process(["content"]),
            subprocess.CompletedProcess(
                ["official"],
                1,
                stdout=json.dumps(
                    {"status": "failed", "reasonCodes": list(reason_codes)}
                ).encode("utf-8"),
                stderr=secret.encode("utf-8"),
            ),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ), mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(1, exit_code)
        self.assertIn("reasonCodes=" + ",".join(reason_codes), rendered)
        self.assertNotIn(secret, rendered)

    def test_invalid_official_report_fails_closed_without_echo(self) -> None:
        secret = "AUTHORIZATION=fixed-sensitive-value"
        output = io.StringIO()
        completed = [
            successful_process(["dependencies"]),
            successful_process(["evidence"]),
            successful_process(["content"]),
            subprocess.CompletedProcess(
                ["official"],
                1,
                stdout=secret.encode("utf-8"),
                stderr=secret.encode("utf-8"),
            ),
        ]

        with mock.patch.object(
            MODULE,
            "read_repository_state",
            side_effect=clean_repository_probes(),
        ), mock.patch.object(MODULE, "official_input_issues", return_value=()), mock.patch.object(
            MODULE.subprocess,
            "run",
            side_effect=completed,
        ), mock.patch("sys.stdout", output):
            exit_code = MODULE.main(fixed_arguments())

        rendered = output.getvalue()
        self.assertEqual(1, exit_code)
        self.assertIn("reasonCodes=official.report-invalid", rendered)
        self.assertNotIn(secret, rendered)

    def test_input_precheck_uses_regular_files_and_absolute_tool_paths(self) -> None:
        args = MODULE.parse_args(fixed_arguments())

        with mock.patch.object(Path, "is_symlink", return_value=False), mock.patch.object(
            Path,
            "is_file",
            return_value=False,
        ):
            issues = MODULE.official_input_issues(args)

        self.assertEqual(("PDF", "MP4", "ZIP", "pdfinfo", "ffprobe"), issues)

    def test_dynamic_import_disables_bytecode_writes(self) -> None:
        self.assertTrue(MODULE.sys.dont_write_bytecode)


if __name__ == "__main__":
    unittest.main()
