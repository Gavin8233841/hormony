import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { GET as getQuizData, POST as generateQuiz } from "./route";
import { POST as submitQuiz } from "./submit/route";
import { GET as getResources } from "../resources/route";
import { store } from "@/lib/store/db";
import type { QuizResult, QuizView } from "@/lib/types";

const originalModelKey = process.env.MODEL_API_KEY;

describe("题库与资源 API 闭环", () => {
  beforeEach(() => {
    delete process.env.MODEL_API_KEY;
  });

  afterEach(() => {
    if (originalModelKey === undefined) {
      delete process.env.MODEL_API_KEY;
    } else {
      process.env.MODEL_API_KEY = originalModelKey;
    }
  });

  it("生成接口不应向客户端泄露答案或解析", async () => {
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "api_test_user",
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 5,
          difficulty: "medium",
        }),
      })
    );
    const quiz = (await response.json()) as QuizView;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(5);
    expect(quiz.questions.every((question) => !("answer" in question))).toBe(true);
    expect(quiz.questions.every((question) => !("explanation" in question))).toBe(true);
  });

  it("完整选项文本应正确评分，未提交题目应计入总题数", async () => {
    const generatedResponse = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "api_test_user",
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 5,
          difficulty: "medium",
        }),
      })
    );
    const quiz = (await generatedResponse.json()) as QuizView;
    const storedQuiz = store.getQuiz(quiz.quizId);
    expect(storedQuiz).toBeDefined();

    const firstQuestion = storedQuiz!.questions[0];
    const answerIndex = firstQuestion.answer.charCodeAt(0) - "A".charCodeAt(0);
    const correctOption = firstQuestion.options?.[answerIndex];
    expect(correctOption).toBeDefined();

    const submitResponse = await submitQuiz(
      new Request("http://localhost/api/quiz/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          quizId: quiz.quizId,
          userId: "api_test_user",
          answers: [
            { questionId: firstQuestion.id, userAnswer: correctOption },
          ],
        }),
      })
    );
    const result = (await submitResponse.json()) as QuizResult;

    expect(submitResponse.status).toBe(200);
    expect(result.totalQuestions).toBe(5);
    expect(result.correctCount).toBe(1);
    expect(result.details).toHaveLength(5);
    expect(result.details[0].isCorrect).toBe(true);
    expect(result.weakTopics.every((topic) => !topic.endsWith(".pdf"))).toBe(true);
  });

  it("课程题库目录不应返回题目答案", async () => {
    const response = await getQuizData(
      new Request("http://localhost/api/quiz?courseId=cs102")
    );
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.quizzes.length).toBeGreaterThan(0);
    expect(data.quizzes[0]).toMatchObject({ courseId: "cs102" });
    expect(data.quizzes[0]).toHaveProperty("questionCount");
    expect(data.quizzes[0]).not.toHaveProperty("questions");
  });

  it("资源接口应拒绝未知类型", async () => {
    const response = await getResources(
      new Request("http://localhost/api/resources?type=unknown")
    );
    await expect(response.json()).resolves.toMatchObject({ code: "BAD_REQUEST" });
    expect(response.status).toBe(400);
  });
});
