import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("validate-release-dependencies.py")
SPEC = importlib.util.spec_from_file_location(
    "validate_release_dependencies",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def current_manifest() -> str:
    return MODULE.DEFAULT_MANIFEST_PATH.read_text(encoding="utf-8")


def current_plan() -> str:
    return MODULE.DEFAULT_PLAN_PATH.read_text(encoding="utf-8")


def tracked_required_files() -> set[str]:
    return set(MODULE.REQUIRED_DIRECT_INCLUDE_PATHS)


def expected_runtime_edges() -> dict[tuple[str, str], str]:
    return dict(MODULE.EXPECTED_RUNTIME_EDGES)


def expected_test_edges() -> dict[tuple[str, str], str]:
    return dict(MODULE.EXPECTED_TEST_EDGES)


def validate(
    manifest_content: str | None = None,
    plan_content: str | None = None,
    tracked_names: set[str] | None = None,
    runtime_edges: dict[tuple[str, str], str] | None = None,
    test_edges: dict[tuple[str, str], str] | None = None,
) -> tuple[MODULE.ReleaseDependencyMetrics, list[str]]:
    return MODULE.validate_release_dependencies(
        manifest_content if manifest_content is not None else current_manifest(),
        plan_content if plan_content is not None else current_plan(),
        tracked_names if tracked_names is not None else tracked_required_files(),
        runtime_edges if runtime_edges is not None else expected_runtime_edges(),
        test_edges if test_edges is not None else expected_test_edges(),
    )


class ReleaseDependencyGateTests(unittest.TestCase):
    def test_current_manifest_and_runtime_edges_form_complete_closure(self) -> None:
        runtime_edges, runtime_errors = MODULE.collect_runtime_edges()
        test_edges, test_errors = MODULE.collect_test_edges()
        metrics, errors = validate(runtime_edges=runtime_edges, test_edges=test_edges)

        self.assertEqual([], runtime_errors)
        self.assertEqual([], test_errors)
        self.assertEqual([], errors)
        self.assertEqual(len(MODULE.REQUIRED_DIRECT_INCLUDE_PATHS), metrics.direct_files)
        self.assertEqual(7, metrics.test_files)
        self.assertEqual(11, metrics.runtime_edges)
        self.assertEqual(7, metrics.test_edges)
        self.assertEqual(7, metrics.plan_commands)
        self.assertEqual(MODULE.EXPECTED_RUNTIME_EDGES, runtime_edges)
        self.assertEqual(MODULE.EXPECTED_TEST_EDGES, test_edges)

    def test_each_gate_family_and_test_must_be_directly_included(self) -> None:
        required_examples = (
            "docs/COMPETITION-SCORE-FIRST-PLAN.md",
            "scripts/validate-competition-evidence.py",
            "scripts/validate-release-evidence.py",
            "scripts/test_validate_release_evidence.py",
            "scripts/validate-official-deliverables.py",
            "scripts/test_validate_release_dependencies.py",
            "scripts/validate-competition-release.py",
            "scripts/test_validate_competition_release.py",
        )
        for required_path in required_examples:
            with self.subTest(required_path=required_path):
                original_line = f'    "{required_path}",\n'
                self.assertIn(original_line, current_manifest())
                missing = current_manifest().replace(original_line, "", 1)
                _, errors = validate(manifest_content=missing)
                self.assertTrue(
                    any(required_path in error and "未直接纳入" in error for error in errors)
                )

    def test_runtime_dependency_edges_cannot_drift_or_disappear(self) -> None:
        wrong_edges = expected_runtime_edges()
        edge = (
            "scripts/validate-release-bundle.py",
            "EVIDENCE_GATE_PATH",
        )
        wrong_edges[edge] = "scripts/validate-competition-evidence.py"
        _, wrong_errors = validate(runtime_edges=wrong_edges)
        missing_edges = expected_runtime_edges()
        del missing_edges[edge]
        _, missing_errors = validate(runtime_edges=missing_edges)

        self.assertTrue(any("运行时依赖边不一致" in error for error in wrong_errors))
        self.assertTrue(any("缺少运行时依赖边" in error for error in missing_errors))

    def test_release_preflight_must_reference_all_four_existing_gates(self) -> None:
        expected = {
            (
                "scripts/validate-competition-release.py",
                "DEPENDENCY_GATE_PATH",
            ): "scripts/validate-release-dependencies.py",
            (
                "scripts/validate-competition-release.py",
                "EVIDENCE_GATE_PATH",
            ): "scripts/validate-competition-evidence.py",
            (
                "scripts/validate-competition-release.py",
                "CONTENT_GATE_PATH",
            ): "scripts/validate-competition-content.py",
            (
                "scripts/validate-competition-release.py",
                "OFFICIAL_GATE_PATH",
            ): "scripts/validate-official-deliverables.py",
        }

        self.assertLessEqual(expected.items(), MODULE.EXPECTED_RUNTIME_EDGES.items())

    def test_release_bundle_must_bind_competition_plan_and_release_evidence(self) -> None:
        expected = {
            (
                "scripts/validate-release-bundle.py",
                "COMPETITION_GATE_PATH",
            ): "scripts/validate-competition-evidence.py",
            (
                "scripts/validate-release-bundle.py",
                "EVIDENCE_GATE_PATH",
            ): "scripts/validate-release-evidence.py",
        }

        self.assertLessEqual(expected.items(), MODULE.EXPECTED_RUNTIME_EDGES.items())

    def test_required_file_must_be_tracked_in_git_index(self) -> None:
        tracked = tracked_required_files()
        tracked.remove("scripts/validate-release-evidence.py")

        _, errors = validate(tracked_names=tracked)

        self.assertTrue(
            any(
                "validate-release-evidence.py" in error and "未被 Git 跟踪" in error
                for error in errors
            )
        )

    def test_lesson_experience_is_not_an_individual_migration_dependency(self) -> None:
        path = next(iter(MODULE.DISALLOWED_DIRECT_CONTENT_DEPENDENCIES))
        self.assertNotIn(path, MODULE.REQUIRED_DIRECT_INCLUDE_PATHS)
        mutated = current_manifest().replace(
            '    "apps/harmonyos",\n',
            f'    "apps/harmonyos",\n    "{path}",\n',
            1,
        )

        _, errors = validate(manifest_content=mutated)

        self.assertTrue(any(path in error and "独立移植依赖" in error for error in errors))

    def test_test_edges_and_documented_commands_cannot_drift(self) -> None:
        edge = (
            "scripts/test_validate_official_deliverables.py",
            "SCRIPT_PATH",
        )
        wrong_test_edges = expected_test_edges()
        wrong_test_edges[edge] = "scripts/validate-release-bundle.py"
        _, edge_errors = validate(test_edges=wrong_test_edges)
        command = "python -B scripts/validate-official-deliverables.py"
        plan_without_command = current_plan().replace(command, "missing-command", 1)
        _, command_errors = validate(plan_content=plan_without_command)

        self.assertTrue(any("测试依赖边不一致" in error for error in edge_errors))
        self.assertTrue(
            any(command in error and "缺少正式门禁命令" in error for error in command_errors)
        )


if __name__ == "__main__":
    unittest.main()
