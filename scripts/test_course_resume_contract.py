import re
import unittest
from pathlib import Path

from scripts.test_knowledge_navigation_contract import compact, extract_method


ROOT = Path(__file__).resolve().parents[1]
RESUME_STATE = ROOT / "apps/harmonyos/entry/src/main/ets/pages/CourseResumeState.ets"
COURSE_PAGE = ROOT / "apps/harmonyos/entry/src/main/ets/pages/Course.ets"
COURSE_DETAIL_PAGE = ROOT / "apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets"


class CourseResumeContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resume_source = RESUME_STATE.read_text(encoding="utf-8")
        cls.course_source = COURSE_PAGE.read_text(encoding="utf-8")
        cls.detail_source = COURSE_DETAIL_PAGE.read_text(encoding="utf-8")

    def test_resume_state_uses_only_real_matching_lesson_progress(self):
        resolver = compact(
            extract_method(self.resume_source, "resolveCourseResumeState")
        )

        self.assertNotIn("'cs101'", self.resume_source)
        self.assertIn("item.courseId !== courseId", resolver)
        self.assertIn("!topics.includes(item.topic)", resolver)
        self.assertIn("item.completedChunkIds.length === 0", resolver)
        self.assertIn("item.completedAt !== undefined", resolver)
        self.assertIn("item.updatedAt > recentUpdatedAt", resolver)

        completed_guard = resolver.find("if (item.completedAt !== undefined)")
        completed_continue = resolver.find("continue;", completed_guard)
        recent_update = resolver.find("recentTopic = item.topic", completed_continue)
        self.assertGreaterEqual(completed_guard, 0)
        self.assertGreater(completed_continue, completed_guard)
        self.assertGreater(recent_update, completed_continue)

    def test_resume_helpers_prioritize_recent_incomplete_topic(self):
        started = compact(extract_method(self.resume_source, "hasCourseStarted"))
        next_topic = compact(extract_method(self.resume_source, "resolveNextTopic"))
        action = compact(extract_method(self.resume_source, "resolveTopicAction"))

        self.assertIn("state.startedTopics.length > 0", started)
        self.assertRegex(
            next_topic,
            re.compile(
                r"if \(state\.recentTopic\.length > 0 && "
                r"!completedTopics\.includes\(state\.recentTopic\)\) "
                r"return state\.recentTopic;"
            ),
        )
        self.assertIn(
            "topics.find((topic: string): boolean => "
            "!completedTopics.includes(topic)) ?? ''",
            next_topic,
        )
        self.assertIn("if (completedTopics.includes(topic)) return '复习';", action)
        self.assertIn("if (state.startedTopics.includes(topic)) return '继续';", action)
        self.assertIn("if (topic === nextTopic) return '开始';", action)

    def test_course_cta_reads_lesson_progress_instead_of_only_aggregate_progress(self):
        load_courses = compact(extract_method(self.course_source, "loadCourses"))
        action_label = compact(extract_method(self.course_source, "courseActionLabel"))
        progress_label = compact(extract_method(self.course_source, "courseProgressLabel"))

        self.assertIn(
            "this.lessonProgress = await LocalLearningRepository.getLessonProgress();",
            load_courses,
        )
        self.assertIn("hasCourseStarted(this.resumeState(course))", action_label)
        self.assertIn("? '继续课程' : '进入课程'", action_label)
        self.assertIn("this.resumeState(course).recentTopic", progress_label)
        self.assertIn("'上次学到 · ' + recentTopic", progress_label)

    def test_course_detail_uses_scoped_progress_for_recent_and_completed_topics(self):
        load_progress = compact(extract_method(self.detail_source, "loadProgress"))
        next_topic = compact(extract_method(self.detail_source, "nextTopic"))
        next_hint = compact(extract_method(self.detail_source, "nextTopicHint"))

        self.assertIn(
            "this.lessonProgress = await "
            "LocalLearningRepository.getLessonProgress(this.courseId);",
            load_progress,
        )
        self.assertIn("for (const topic of this.resumeState().completedTopics)", load_progress)
        self.assertIn("resolveNextTopic(this.topics, this.completedTopics", next_topic)
        self.assertIn("this.resumeState().recentTopic", next_hint)
        self.assertIn("? '继续 · ' + topic : '下一步 · ' + topic", next_hint)


if __name__ == "__main__":
    unittest.main()
