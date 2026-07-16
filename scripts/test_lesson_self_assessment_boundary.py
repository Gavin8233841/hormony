import re
import unittest
from pathlib import Path

from scripts.test_knowledge_navigation_contract import compact, extract_method


ROOT = Path(__file__).resolve().parents[1]
LESSON_PAGE = ROOT / "apps/harmonyos/entry/src/main/ets/pages/Lesson.ets"
LOCAL_REPOSITORY = (
    ROOT
    / "apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets"
)


class LessonSelfAssessmentBoundaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lesson_source = LESSON_PAGE.read_text(encoding="utf-8")
        cls.repository_source = LOCAL_REPOSITORY.read_text(encoding="utf-8")

    def test_self_assessment_event_has_provenance_without_objective_fields(self):
        self_assess = compact(
            extract_method(self.lesson_source, "selfAssess")
        )
        persist = compact(
            extract_method(self.lesson_source, "persistActivityEvidence")
        )

        self.assertIn(
            "this.markActivityAttempted(activity, covered, true);",
            self_assess,
        )
        self_start = persist.find("if (selfAssessed) {")
        objective_start = persist.find("} else {", self_start)
        append_start = persist.find(
            "LocalLearningRepository.appendStudyEvent(event)",
            objective_start,
        )
        self.assertGreaterEqual(self_start, 0)
        self.assertGreater(objective_start, self_start)
        self.assertGreater(append_start, objective_start)

        self_branch = persist[self_start:objective_start]
        self.assertIn("type: 'lesson_activity'", self_branch)
        self.assertIn("source: 'lesson_self_assessment'", self_branch)
        self.assertIn("taskId: activity.id", self_branch)
        for field in ("accuracy:", "totalQuestions:", "correctCount:"):
            self.assertNotIn(field, self_branch)

    def test_objective_interaction_event_keeps_exact_scoring_fields(self):
        persist = compact(
            extract_method(self.lesson_source, "persistActivityEvidence")
        )
        self_start = persist.find("if (selfAssessed) {")
        objective_start = persist.find("} else {", self_start)
        append_start = persist.find(
            "LocalLearningRepository.appendStudyEvent(event)",
            objective_start,
        )
        self.assertGreaterEqual(objective_start, 0)
        self.assertGreater(append_start, objective_start)

        objective_branch = persist[objective_start:append_start]
        self.assertIn("type: 'lesson_activity'", objective_branch)
        self.assertIn("source: 'lesson_interactive'", objective_branch)
        self.assertIn("accuracy: correct ? 1 : 0", objective_branch)
        self.assertIn("totalQuestions: 1", objective_branch)
        self.assertIn("correctCount: correct ? 1 : 0", objective_branch)

    @unittest.expectedFailure
    def test_tag_insight_reducer_requires_complete_objective_evidence(self):
        # WS02 owns this reducer. Keep the desired cross-workstream contract
        # executable until its repository change lands, without hiding the gap.
        insights = compact(
            extract_method(self.repository_source, "getTagInsights")
        )
        event_loop = insights.find(
            "const events = await LocalLearningRepository.getStudyEvents()"
        )
        return_start = insights.find("return insights.sort", event_loop)
        self.assertGreaterEqual(event_loop, 0)
        self.assertGreater(return_start, event_loop)
        event_reducer = insights[event_loop:return_start]

        self.assertRegex(
            event_reducer,
            re.compile(
                r"if \(event\.type !== 'lesson_activity' \|\| "
                r"event\.source !== 'lesson_interactive' \|\| "
                r"event\.totalQuestions === undefined \|\| "
                r"event\.correctCount === undefined \|\| "
                r"event\.accuracy === undefined\) continue;"
            ),
        )
        self.assertIn(
            "const totalQuestions = event.totalQuestions;",
            event_reducer,
        )
        self.assertIn(
            "const correctQuestions = event.correctCount;",
            event_reducer,
        )
        self.assertNotIn("event.totalQuestions ??", event_reducer)
        self.assertNotIn("event.correctCount ??", event_reducer)

    def test_other_objective_reducers_do_not_consume_lesson_activity_events(self):
        profile = compact(
            extract_method(self.repository_source, "getProfile")
        )
        mastery = compact(
            extract_method(self.repository_source, "applyResultToMastery")
        )
        courses = compact(
            extract_method(self.repository_source, "getCourses")
        )

        self.assertIn("totalQuestions += result.totalQuestions", profile)
        self.assertIn("correctQuestions += result.correctCount", profile)
        event_loop = profile.find(
            "const events = await LocalLearningRepository.getStudyEvents()"
        )
        profile_result = profile.find("profile.stats =", event_loop)
        self.assertGreaterEqual(event_loop, 0)
        self.assertGreater(profile_result, event_loop)
        profile_events = profile[event_loop:profile_result]
        self.assertNotIn("event.totalQuestions", profile_events)
        self.assertNotIn("event.correctCount", profile_events)
        self.assertNotIn("event.accuracy", profile_events)

        self.assertRegex(
            self.repository_source,
            re.compile(
                r"applyResultToMastery\(mastery: TopicMastery\[\], "
                r"result: QuizResult\): void"
            ),
        )
        self.assertIn("item.totalQuestions += result.totalQuestions", mastery)
        self.assertIn("item.correctQuestions += result.correctCount", mastery)
        self.assertNotIn("StudyEvent", mastery)
        self.assertNotIn("lesson_activity", mastery)

        self.assertIn(
            "event.type !== 'lesson_completed' && "
            "event.type !== 'quiz_mastered'",
            courses,
        )
        self.assertNotIn("event.type === 'lesson_activity'", courses)

    def test_active_learning_achievement_is_participation_not_objective_mastery(self):
        achievements = compact(
            extract_method(self.repository_source, "getAchievements")
        )

        self.assertIn(
            "const lessonActivities = LocalLearningRepository.uniqueEvents("
            "events, 'lesson_activity', true)",
            achievements,
        )
        self.assertIn(
            "'active_learning_3', '主动学习', '完成 3 个课程互动练习', "
            "lessonActivities.length, 3",
            achievements,
        )
        self.assertIn(
            "const masteredTopics = LocalLearningRepository.uniqueEvents("
            "events, 'quiz_mastered', false)",
            achievements,
        )
        self.assertIn(
            "'mastery_3', '掌握新知', '掌握 3 个知识点', "
            "masteredTopics.length, 3",
            achievements,
        )
        self.assertNotIn("lessonActivities.length", compact(
            achievements[
                achievements.find("'mastery_3'"):
                achievements.find("'mastery_3'") + 160
            ]
        ))


if __name__ == "__main__":
    unittest.main()
