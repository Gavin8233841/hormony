import type {
  QuizGradingItem,
  QuizPackage,
  QuizQuestionView,
  QuizResult,
  QuizResultDetail,
} from "@/lib/types";

export class QuizPackageValidationError extends Error {
  constructor(message = "云端返回的题组不完整，请重新生成") {
    super(message);
    this.name = "QuizPackageValidationError";
  }
}

const MAX_QUIZ_QUESTIONS = 20;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isDifficulty(value: unknown): boolean {
  return value === undefined || value === "easy" || value === "medium" || value === "hard";
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function isQuestion(value: unknown): value is QuizQuestionView {
  if (!isRecord(value)) return false;
  if (typeof value.id !== "string" || !value.id.trim()) return false;
  if (value.type !== "choice" && value.type !== "short") return false;
  if (typeof value.stem !== "string" || !value.stem.trim()) return false;
  if (
    !isDifficulty(value.difficulty) ||
    !isStringArray(value.tags) ||
    value.tags.length < 1 ||
    value.tags.length > 3 ||
    value.tags.some((tag) => tag.trim().length < 1 || tag.length > 12)
  ) return false;
  if (value.options !== undefined && !isStringArray(value.options)) return false;
  if (
    value.type === "choice" &&
    (
      !Array.isArray(value.options) ||
      value.options.length !== 4 ||
      value.options.some((option) => option.trim().length === 0) ||
      new Set(value.options).size !== value.options.length
    )
  ) return false;
  return true;
}

function isGradingItem(value: unknown): value is QuizGradingItem {
  if (!isRecord(value)) return false;
  return (
    typeof value.questionId === "string" && value.questionId.trim().length > 0 &&
    typeof value.answer === "string" && value.answer.trim().length > 0 &&
    typeof value.explanation === "string" && value.explanation.trim().length > 0 &&
    isDifficulty(value.difficulty) &&
    isStringArray(value.tags) &&
    value.tags.length >= 1 &&
    value.tags.length <= 3 &&
    value.tags.every((tag) => tag.trim().length >= 1 && tag.length <= 12)
  );
}

export function parseQuizPackage(value: unknown): QuizPackage {
  if (!isRecord(value)) throw new QuizPackageValidationError();
  if (
    typeof value.quizId !== "string" || !value.quizId.trim() ||
    typeof value.courseId !== "string" || !value.courseId.trim() ||
    typeof value.topic !== "string" || !value.topic.trim() ||
    (value.focusTag !== undefined && typeof value.focusTag !== "string") ||
    !Array.isArray(value.questions) ||
    value.questions.length === 0 ||
    value.questions.length > MAX_QUIZ_QUESTIONS ||
    !Array.isArray(value.grading) || value.questions.length !== value.grading.length ||
    !value.questions.every(isQuestion) ||
    !value.grading.every(isGradingItem)
  ) {
    throw new QuizPackageValidationError();
  }

  const questionIds = value.questions.map((question) => question.id);
  const gradingIds = value.grading.map((item) => item.questionId);
  if (
    new Set(questionIds).size !== questionIds.length ||
    new Set(gradingIds).size !== gradingIds.length ||
    gradingIds.some((id) => !questionIds.includes(id))
  ) {
    throw new QuizPackageValidationError();
  }

  const gradingByQuestion = new Map(
    value.grading.map((item) => [item.questionId, item])
  );
  for (const question of value.questions) {
    const grading = gradingByQuestion.get(question.id);
    if (
      !grading ||
      (question.type === "choice" && !/^[A-D]$/.test(grading.answer.trim().toUpperCase()))
    ) {
      throw new QuizPackageValidationError();
    }
  }

  return value as unknown as QuizPackage;
}

function answersMatch(question: QuizQuestionView, expected: string, userAnswer: string): boolean {
  const normalizedExpected = expected.trim();
  if (question.type === "choice" && question.options) {
    const selectedIndex = question.options.indexOf(userAnswer);
    const selectedKey = selectedIndex >= 0
      ? String.fromCharCode("A".charCodeAt(0) + selectedIndex)
      : userAnswer;
    const expectedIndex = question.options.indexOf(normalizedExpected);
    const expectedKey = expectedIndex >= 0
      ? String.fromCharCode("A".charCodeAt(0) + expectedIndex)
      : normalizedExpected;
    return selectedKey.trim().toUpperCase() === expectedKey.toUpperCase();
  }
  return userAnswer.toLocaleLowerCase() === normalizedExpected.toLocaleLowerCase();
}

function correctAnswerText(question: QuizQuestionView, answer: string): string {
  if (!question.options) return answer;
  const normalized = answer.trim().toUpperCase();
  const answerIndex = normalized.length === 1
    ? normalized.charCodeAt(0) - "A".charCodeAt(0)
    : question.options.indexOf(answer);
  return answerIndex >= 0 && answerIndex < question.options.length
    ? question.options[answerIndex]
    : answer;
}

export function scoreQuizLocally(
  quiz: QuizPackage,
  answers: Record<string, string>,
  userId: string,
  submittedAt = new Date(),
): QuizResult {
  const gradingByQuestion = new Map(quiz.grading.map((item) => [item.questionId, item]));
  const details: QuizResultDetail[] = quiz.questions.map((question) => {
    const grading = gradingByQuestion.get(question.id);
    if (!grading) throw new QuizPackageValidationError();
    const userAnswer = (answers[question.id] ?? "").trim();
    return {
      questionId: question.id,
      stem: question.stem,
      userAnswer,
      correctAnswer: correctAnswerText(question, grading.answer),
      isCorrect: answersMatch(question, grading.answer, userAnswer),
      explanation: grading.explanation,
      difficulty: grading.difficulty ?? question.difficulty,
      tags: grading.tags.length > 0 ? grading.tags : question.tags,
    };
  });

  const correctCount = details.filter((detail) => detail.isCorrect).length;
  const totalQuestions = details.length;
  const weakTopics = details
    .filter((detail) => !detail.isCorrect)
    .flatMap((detail) => detail.tags ?? [])
    .filter((tag, index, tags) => tag.trim().length > 0 && tags.indexOf(tag) === index)
    .slice(0, 5);

  return {
    quizId: quiz.quizId,
    userId,
    totalQuestions,
    correctCount,
    accuracy: totalQuestions > 0 ? correctCount / totalQuestions : 0,
    details,
    evaluation: "",
    weakTopics,
    submittedAt: submittedAt.toISOString(),
  };
}
