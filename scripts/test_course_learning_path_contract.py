import re
import unittest
from pathlib import Path

from scripts.test_knowledge_navigation_contract import compact, extract_method


ROOT = Path(__file__).resolve().parents[1]
PAGES = ROOT / "apps/harmonyos/entry/src/main/ets/pages"


class CourseLearningPathContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.course_detail = (PAGES / "CourseDetail.ets").read_text(encoding="utf-8")
        cls.lesson = (PAGES / "Lesson.ets").read_text(encoding="utf-8")
        cls.quiz = (PAGES / "Quiz.ets").read_text(encoding="utf-8")
        cls.chat = (PAGES / "Chat.ets").read_text(encoding="utf-8")
        cls.practice = (PAGES / "Practice.ets").read_text(encoding="utf-8")

    def test_course_topic_opens_lesson_with_exact_context(self):
        open_topic = compact(extract_method(self.course_detail, "openTopic"))
        writes = [
            "'selectedCourseId', this.courseId",
            "'selectedCourseTitle', this.courseTitle",
            "'selectedContentTopic', topic",
        ]
        positions = [open_topic.find(value) for value in writes]
        route = open_topic.find("url: 'pages/Lesson'")

        self.assertTrue(all(position >= 0 for position in positions))
        self.assertEqual(positions, sorted(positions))
        self.assertGreater(route, positions[-1])

        appear = compact(extract_method(self.lesson, "aboutToAppear"))
        self.assertIn("'selectedCourseId'", appear)
        self.assertIn("'selectedCourseTitle'", appear)
        self.assertIn("'selectedContentTopic'", appear)
        self.assertLess(appear.find("'selectedCourseId'"), appear.find("this.loadProgress();"))
        self.assertLess(appear.find("'selectedContentTopic'"), appear.find("this.loadProgress();"))

    def test_lesson_activity_opens_same_topic_and_tag_quiz(self):
        primary_tag = compact(extract_method(self.lesson, "primaryActivityTag"))
        open_quiz = compact(
            extract_method(self.lesson, "openFocusedQuizForActivity")
        )

        self.assertEqual("return activity.focusTag;", primary_tag)
        guard = open_quiz.find(
            "if (!LearningContentRepository.getTopics(this.courseId).includes(this.topic))"
        )
        topic_write = open_quiz.find("'selectedQuizTopic', this.topic")
        tag_write = open_quiz.find(
            "'selectedQuizFocusTag', this.primaryActivityTag(activity)"
        )
        route = open_quiz.find("url: 'pages/Quiz'")
        self.assertGreaterEqual(guard, 0)
        self.assertIn("return;", open_quiz[guard:topic_write])
        self.assertGreater(topic_write, guard)
        self.assertGreater(tag_write, topic_write)
        self.assertGreater(route, tag_write)
        self.assertNotIn("'综合'", open_quiz)

    def test_quiz_consumes_route_focus_and_sends_it_to_generation(self):
        appear = compact(extract_method(self.quiz, "aboutToAppear"))
        generate = compact(extract_method(self.quiz, "generateQuiz"))

        topic_read = appear.find("'selectedQuizTopic'")
        topic_clear = appear.find("'selectedQuizTopic', ''", topic_read)
        focus_read = appear.find("'selectedQuizFocusTag'")
        focus_clear = appear.find("'selectedQuizFocusTag', ''", focus_read)
        self.assertGreaterEqual(topic_read, 0)
        self.assertGreater(topic_clear, topic_read)
        self.assertGreater(focus_read, topic_clear)
        self.assertGreater(focus_clear, focus_read)
        self.assertIn("this.topic = selectedTopic.trim();", appear)
        self.assertIn(
            "this.focusTag = selectedFocusTag.trim().substring(0, 12);",
            appear,
        )
        self.assertRegex(
            generate,
            re.compile(
                r"const request: QuizRequest = \{ .*"
                r"courseId: this\.courseId, topic: this\.topic, .*"
                r"focusTag: this\.focusTag\.length > 0 \? this\.focusTag : undefined,"
            ),
        )

    def test_lesson_activity_question_reaches_chat_once(self):
        ask_tutor = compact(extract_method(self.lesson, "askTutorForActivity"))
        chat_appear = compact(extract_method(self.chat, "aboutToAppear"))

        self.assertIn("activity.prompt", ask_tutor)
        self.assertIn("this.topic", ask_tutor)
        self.assertIn("this.activityAnswerText(activity)", ask_tutor)
        self.assertIn("activity.answer", ask_tutor)
        pending_write = ask_tutor.find("'pendingChatQuestion', question")
        route = ask_tutor.find("url: 'pages/Chat'")
        self.assertGreaterEqual(pending_write, 0)
        self.assertGreater(route, pending_write)

        pending_read = chat_appear.find("'pendingChatQuestion'")
        input_fill = chat_appear.find("pendingQuestion.trim()")
        pending_clear = chat_appear.find("'pendingChatQuestion', ''")
        self.assertGreaterEqual(pending_read, 0)
        self.assertGreater(input_fill, pending_read)
        self.assertGreater(pending_clear, input_fill)

    def test_completed_lesson_opens_exact_topic_practice(self):
        open_practice = compact(extract_method(self.lesson, "openPractice"))
        practice_appear = compact(extract_method(self.practice, "aboutToAppear"))
        load_questions = compact(extract_method(self.practice, "loadQuestions"))

        topic_write = open_practice.find("'selectedPracticeTopic', this.topic")
        route = open_practice.find("url: 'pages/Practice'")
        self.assertGreaterEqual(topic_write, 0)
        self.assertGreater(route, topic_write)
        self.assertNotIn("'综合'", open_practice)

        self.assertIn(
            "this.topic = AppStorage.get<string>('selectedPracticeTopic') ?? '';",
            practice_appear,
        )
        self.assertIn(
            "LearningContentRepository.getQuestions(this.courseId, this.topic)",
            load_questions,
        )


if __name__ == "__main__":
    unittest.main()
