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


class LessonActivityResumeContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = LESSON_PAGE.read_text(encoding="utf-8")
        cls.repository_source = LOCAL_REPOSITORY.read_text(encoding="utf-8")

    def test_restore_accepts_only_current_experience_activity_events(self):
        restore = compact(extract_method(self.source, "restoreActivityProgress"))

        self.assertIn(
            "const activityIds = this.experience.activities.map((activity: "
            "LearningActivity): string => activity.id);",
            restore,
        )
        self.assertRegex(
            restore,
            re.compile(
                r"if \(event\.type !== 'lesson_activity' \|\| "
                r"event\.courseId !== this\.courseId \|\| "
                r"event\.topic !== this\.topic \|\| "
                r"event\.taskId === undefined \|\| "
                r"!activityIds\.includes\(event\.taskId\) \|\| "
                r"attemptedIds\.includes\(event\.taskId\)\) "
                r"\{ continue; \}"
            ),
        )

    def test_restore_deduplicates_and_selects_the_first_unfinished_activity(self):
        restore = compact(extract_method(self.source, "restoreActivityProgress"))

        duplicate_guard = restore.find("attemptedIds.includes(event.taskId)")
        append = restore.find("attemptedIds.push(event.taskId)")
        publish = restore.find("this.attemptedActivityIds = attemptedIds")
        first_unfinished = restore.find(
            "!attemptedIds.includes(activity.id)", publish
        )
        select_index = restore.find(
            "this.activeActivityIndex = nextIndex >= 0 ? nextIndex : "
            "this.experience.activities.length - 1",
            first_unfinished,
        )

        self.assertGreaterEqual(duplicate_guard, 0)
        self.assertGreater(append, duplicate_guard)
        self.assertGreater(publish, append)
        self.assertGreater(first_unfinished, publish)
        self.assertGreater(select_index, first_unfinished)

    def test_resume_resets_stale_input_and_primary_action_focuses_activity(self):
        appear = compact(extract_method(self.source, "aboutToAppear"))
        restore = compact(extract_method(self.source, "restoreActivityProgress"))
        label = compact(extract_method(self.source, "finalActionLabel"))
        focus = compact(extract_method(self.source, "focusActiveActivity"))
        primary = compact(extract_method(self.source, "handlePrimaryAction"))

        self.assertIn("this.activeActivityIndex = 0", appear)
        self.assertIn("this.attemptedActivityIds = []", appear)
        self.assertIn("this.resetActivityInput()", appear)

        selected_activity = restore.find("this.activeActivityIndex = nextIndex")
        reset_input = restore.find("this.resetActivityInput()", selected_activity)
        self.assertGreaterEqual(selected_activity, 0)
        self.assertGreater(reset_input, selected_activity)

        self.assertIn("this.needsActivityResume()", label)
        self.assertIn("'继续互动 '", label)
        self.assertIn("this.activityOffset", focus)
        self.assertIn("this.contentScroller.scrollTo", focus)
        self.assertIn("this.contentScroller.scrollPage({ next: true })", focus)

        focus_call = primary.find("this.focusActiveActivity()")
        return_call = primary.find("return;", focus_call)
        complete_call = primary.find("this.completeCurrent()", return_call)
        self.assertGreaterEqual(focus_call, 0)
        self.assertGreater(return_call, focus_call)
        self.assertGreater(complete_call, return_call)

        self.assertIn(".onAreaChange((_: Area, newValue: Area): void =>", self.source)
        self.assertIn(".onClick((): void => { this.handlePrimaryAction(); })", self.source)

    def test_event_read_failure_preserves_the_loaded_lesson_content(self):
        appear = compact(extract_method(self.source, "aboutToAppear"))
        restore = compact(extract_method(self.source, "restoreActivityProgress"))

        load_chunks = appear.find("this.chunks = content")
        load_experience = appear.find(
            "this.experience = LearningContentRepository.getLessonExperience"
        )
        load_progress = appear.find("this.loadProgress()")
        self.assertGreaterEqual(load_chunks, 0)
        self.assertGreaterEqual(load_experience, 0)
        self.assertGreater(load_progress, load_chunks)
        self.assertGreater(load_progress, load_experience)

        catch_start = restore.find("catch (error)")
        self.assertGreaterEqual(catch_start, 0)
        failure_path = restore[catch_start:]
        self.assertIn(
            "if (this.message.length === 0) this.message = "
            "'互动断点读取失败，可继续当前练习'",
            failure_path,
        )
        for assignment in (
            "this.chunks =",
            "this.activeChunk =",
            "this.experience =",
            "this.completedChunkIds =",
            "this.currentIndex =",
            "this.attemptedActivityIds =",
            "this.activeActivityIndex =",
        ):
            self.assertNotIn(assignment, failure_path)

    def test_self_assessment_has_provenance_but_no_objective_mastery_fields(self):
        self_assess = compact(extract_method(self.source, "selfAssess"))
        persist = compact(extract_method(self.source, "persistActivityEvidence"))

        self.assertIn(
            "this.markActivityAttempted(activity, covered, true);",
            self_assess,
        )

        self_start = persist.find("if (selfAssessed) {")
        interactive_start = persist.find("} else {", self_start)
        append_start = persist.find(
            "LocalLearningRepository.appendStudyEvent(event)", interactive_start
        )
        self.assertGreaterEqual(self_start, 0)
        self.assertGreater(interactive_start, self_start)
        self.assertGreater(append_start, interactive_start)

        self_assessed_branch = persist[self_start:interactive_start]
        interactive_branch = persist[interactive_start:append_start]
        self.assertIn("type: 'lesson_activity'", self_assessed_branch)
        self.assertIn("source: 'lesson_self_assessment'", self_assessed_branch)
        self.assertIn("taskId: activity.id", self_assessed_branch)
        for objective_field in ("accuracy:", "totalQuestions:", "correctCount:"):
            self.assertNotIn(objective_field, self_assessed_branch)

        self.assertIn("source: 'lesson_interactive'", interactive_branch)
        self.assertIn("accuracy:", interactive_branch)
        self.assertIn("totalQuestions: 1", interactive_branch)
        self.assertIn("correctCount:", interactive_branch)

    def test_activity_is_completed_only_after_persistence_and_failure_can_retry(self):
        mark = compact(extract_method(self.source, "markActivityAttempted"))

        pending_guard = mark.find("this.pendingActivityIds.includes(activity.id)")
        persist = mark.find("this.persistActivityEvidence(activity, correct, selfAssessed)")
        success = mark.find(".then((): void =>", persist)
        publish = mark.find(
            "this.attemptedActivityIds = this.attemptedActivityIds.concat([activity.id])",
            success,
        )
        failure = mark.find(".catch((): void =>", publish)
        retry_message = mark.find(
            "'互动记录保存失败，请重试保存后再继续。'", failure
        )

        self.assertGreaterEqual(pending_guard, 0)
        self.assertGreater(persist, pending_guard)
        self.assertGreater(success, persist)
        self.assertGreater(publish, success)
        self.assertGreater(failure, publish)
        self.assertGreater(retry_message, failure)
        self.assertNotIn(
            "this.attemptedActivityIds = this.attemptedActivityIds.concat([activity.id])",
            mark[:success],
        )
        self.assertIn("Button('重试保存记录')", self.source)

    def test_tutor_handoff_preserves_bounded_learning_evidence(self):
        build_question = compact(
            extract_method(self.source, "buildTutorQuestion")
        )
        ask_tutor = compact(
            extract_method(self.source, "askTutorForActivity")
        )

        for evidence in (
            "this.tutorExcerpt(activity.prompt, 620)",
            "this.tutorExcerpt(this.topic, 80)",
            "this.tutorExcerpt(activity.focusTag, 24)",
            "this.tutorExcerpt(this.activityAnswerText(activity), 360)",
            "this.tutorExcerpt(activity.answer, 400)",
            "this.tutorExcerpt(activity.source, 160)",
        ):
            self.assertIn(evidence, build_question)
        self.assertIn("question.length <= 1800", build_question)
        self.assertIn("question.substring(0, 1797) + '...'", build_question)
        self.assertIn(
            "const question = this.buildTutorQuestion(activity);", ask_tutor
        )
        self.assertLess(
            ask_tutor.find("'pendingChatQuestion', question"),
            ask_tutor.find("url: 'pages/Chat'"),
        )

    def test_activity_focus_is_named_before_prompt_and_follow_up_actions(self):
        practice = compact(extract_method(self.source, "PracticeExperience"))

        focus_label = practice.find("Text('本练聚焦')")
        focus_value = practice.find("Text(this.activeActivity()!.focusTag)")
        prompt = practice.find("Text(this.activeActivity()!.prompt)")
        ask_tutor = practice.find("Button('问学伴讲解')")
        same_tag_quiz = practice.find("Button('同标签测验')")
        self.assertGreaterEqual(focus_label, 0)
        self.assertGreater(focus_value, focus_label)
        self.assertGreater(prompt, focus_value)
        self.assertGreater(ask_tutor, prompt)
        self.assertGreater(same_tag_quiz, ask_tutor)

    def test_self_assessment_is_not_aggregated_as_an_objective_question(self):
        insights = compact(
            extract_method(self.repository_source, "getTagInsights")
        )
        events_loop = insights.find(
            "const events = await LocalLearningRepository.getStudyEvents()"
        )
        source_guard = insights.find(
            "event.source === 'lesson_self_assessment'", events_loop
        )
        fallback = insights.find("event.totalQuestions ?? 1", source_guard)

        self.assertGreaterEqual(events_loop, 0)
        self.assertGreater(source_guard, events_loop)
        self.assertGreater(fallback, source_guard)

    def test_study_event_writes_are_serial_and_idempotent(self):
        append = compact(
            extract_method(self.repository_source, "appendStudyEvent")
        )

        queue = append.find("LocalLearningRepository.studyEventWriteQueue.then")
        read = append.find("LocalLearningRepository.getStudyEvents()", queue)
        duplicate_guard = append.find("value.id === event.id", read)
        write = append.find(
            "LocalLearningRepository.putValue<StudyEvent[]>(KEY_STUDY_EVENTS",
            duplicate_guard,
        )
        publish_queue = append.find(
            "LocalLearningRepository.studyEventWriteQueue = operation.catch", write
        )

        self.assertGreaterEqual(queue, 0)
        self.assertGreater(read, queue)
        self.assertGreater(duplicate_guard, read)
        self.assertGreater(write, duplicate_guard)
        self.assertGreater(publish_queue, write)


if __name__ == "__main__":
    unittest.main()
