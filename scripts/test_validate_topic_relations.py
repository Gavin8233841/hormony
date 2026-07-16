import copy
import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("validate-topic-relations.py")
SPEC = importlib.util.spec_from_file_location("validate_topic_relations", MODULE_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class LessonFlowContractTest(unittest.TestCase):
    def setUp(self):
        self.nodes = [{
            "id": "cs101_topic_a",
            "courseId": "cs101",
            "topic": "topic-a",
            "prerequisiteIds": [],
            "level": 0,
        }]
        self.chunks = [{
            "id": "chunk-1",
            "courseId": "cs101",
            "topic": "topic-a",
            "text": "knowledge",
            "source": "source",
        }]
        self.quizzes = [{
            "id": "question-1",
            "courseId": "cs101",
            "topic": "topic-a",
            "tags": ["状态推演"],
        }]
        self.experiences = [{
            "schemaVersion": 2,
            "courseId": "cs101",
            "topic": "topic-a",
            "visualTitle": "visual",
            "visualSteps": ["start", "finish"],
            "caseTitle": "case",
            "caseBody": "case body",
            "workedExampleTitle": "example",
            "workedExampleSteps": ["step 1"],
            "activities": [{
                "id": "activity-1",
                "type": "state_trace",
                "title": "状态推演",
                "focusTag": "状态推演",
                "prompt": "trace the state",
                "content": "state material",
                "language": "scratchpad",
                "interactionMode": "free_response",
                "options": [],
                "answerIndexes": [],
                "answer": "final state",
                "feedback": "feedback",
                "source": "source",
            }],
        }]

    def validate(self):
        return VALIDATOR.check_lesson_flow_contract(
            self.nodes,
            self.chunks,
            self.quizzes,
            self.experiences,
        )

    def test_accepts_complete_lesson_flow(self):
        self.assertEqual([], self.validate())

    def test_ignores_malformed_relation_key_after_schema_validation(self):
        self.nodes.append({
            "id": "broken",
            "courseId": None,
            "topic": "broken-topic",
            "prerequisiteIds": [],
            "level": 0,
        })

        self.assertEqual([], self.validate())

    def test_rejects_missing_and_unknown_lesson_references(self):
        self.experiences[0]["topic"] = "unknown-topic"

        errors = self.validate()

        self.assertTrue(any(
            "lessonExperience[0] cs101/unknown-topic: Topic not found" in error
            for error in errors
        ))
        self.assertIn(
            "cs101/topic-a: expected exactly 1 lesson experience, got 0",
            errors,
        )

    def test_rejects_focus_tags_that_the_quiz_api_would_truncate(self):
        self.experiences[0]["activities"][0]["focusTag"] = "1234567890123"

        errors = self.validate()

        self.assertTrue(any(
            "cs101/topic-a/activity-1: focusTag" in error and "exceeds 12" in error
            for error in errors
        ))

    def test_rejects_missing_focus_tag(self):
        self.experiences[0]["activities"][0].pop("focusTag")

        errors = self.validate()

        self.assertIn(
            'lessonExperience[0].activities[0] cs101/topic-a/activity-1: '
            '"focusTag" must be non-empty string',
            errors,
        )

    def test_rejects_focus_tag_without_same_topic_curated_question(self):
        self.experiences[0]["activities"][0]["focusTag"] = "代码填空"

        errors = self.validate()

        self.assertIn(
            'lessonExperience[0].activities[0] cs101/topic-a/activity-1: '
            'focusTag "代码填空" is absent from same-Topic curated question tags',
            errors,
        )

    def test_rejects_empty_free_response_answer(self):
        self.experiences[0]["activities"][0]["answer"] = ""

        errors = self.validate()

        self.assertIn(
            'lessonExperience[0].activities[0] cs101/topic-a/activity-1: "answer" must be non-empty string',
            errors,
        )

    def test_rejects_unanswerable_ordered_choice(self):
        activity = self.experiences[0]["activities"][0]
        activity.update({
            "type": "step_order",
            "title": "步骤排序",
            "interactionMode": "ordered_choice",
            "options": ["first", "second", "third"],
            "answerIndexes": [0, 2],
            "answer": "first -> second -> third",
        })

        errors = self.validate()

        self.assertIn(
            "lessonExperience[0].activities[0] cs101/topic-a/activity-1: "
            "ordered_choice answerIndexes must be a permutation of all options",
            errors,
        )

    def test_rejects_invalid_curated_question_tag(self):
        self.quizzes[0]["tags"] = ["1234567890123"]

        errors = self.validate()

        self.assertTrue(any(
            "quiz[0] cs101/topic-a/question-1: tag" in error and "exceeds 12" in error
            for error in errors
        ))

    def test_rejects_unreachable_lesson_and_next_step(self):
        self.chunks = []
        self.quizzes = []

        errors = self.validate()

        self.assertIn(
            "cs101/topic-a: Lesson and focused Quiz are unreachable without a knowledge chunk",
            errors,
        )
        self.assertIn(
            "cs101/topic-a: next-step local Practice is unreachable without a curated question",
            errors,
        )

    def test_rejects_duplicate_activity_ids(self):
        second = copy.deepcopy(self.experiences[0]["activities"][0])
        self.experiences[0]["activities"].append(second)

        errors = self.validate()

        self.assertTrue(any("duplicate activity id" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
