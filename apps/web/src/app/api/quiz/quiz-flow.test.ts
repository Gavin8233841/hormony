import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { GET as getQuizData, POST as generateQuiz } from "./route";
import { GET as getResources } from "../resources/route";
import type { QuizPackage } from "@/lib/types";

const originalModelKey = process.env.MODEL_API_KEY;
const originalDeploymentMode = process.env.DEPLOYMENT_MODE;

describe("题库与资源 API 闭环", () => {
  beforeEach(() => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = JSON.stringify(Array.from({ length: 5 }, (_, index) => ({
      type: "choice",
      stem: `测试题 ${index + 1}`,
      options: ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
      answer: "A",
      explanation: "这是测试环境中的固定解析。",
    })));
  });

  afterEach(() => {
    if (originalModelKey === undefined) {
      delete process.env.MODEL_API_KEY;
    } else {
      process.env.MODEL_API_KEY = originalModelKey;
    }
    delete process.env.TEST_MODEL_RESPONSE;
    if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
    else process.env.DEPLOYMENT_MODE = originalDeploymentMode;
  });

  it("生成接口应分离展示题目与本地评分数据", async () => {
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
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(5);
    expect(quiz.questions.every((question) => !("answer" in question))).toBe(true);
    expect(quiz.questions.every((question) => !("explanation" in question))).toBe(true);
    expect(quiz.grading).toHaveLength(5);
    expect(quiz.grading[0]).toMatchObject({ answer: "A" });
  });

  it("模型未配置时应返回明确 503", async () => {
    delete process.env.TEST_MODEL_RESPONSE;
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树",
        }),
      })
    );
    await expect(response.json()).resolves.toMatchObject({ code: "MODEL_UNAVAILABLE" });
    expect(response.status).toBe(503);
  });

  it("应拒绝选项数量或答案格式不合格的 AI 题目", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      type: "choice",
      stem: "不完整题目",
      options: ["A. 选项一", "B. 选项二"],
      answer: "Z",
      explanation: "测试解析。",
    }]);
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 1,
          difficulty: "medium",
        }),
      })
    );

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
  });

  it("应拒绝缺少 A-D 顺序前缀的 AI 选项", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      type: "choice",
      stem: "格式错误题目",
      options: ["选项一", "选项二", "选项三", "选项四"],
      answer: "A",
      explanation: "测试解析。",
    }]);
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 1,
          difficulty: "medium",
        }),
      })
    );

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
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

  it("无状态部署不得从服务端读取答题历史", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    const response = await getQuizData(new Request("http://localhost/api/quiz?userId=demo"));
    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toMatchObject({ code: "ENDPOINT_DISABLED" });
  });

  it("资源接口应拒绝未知类型", async () => {
    const response = await getResources(
      new Request("http://localhost/api/resources?type=unknown")
    );
    await expect(response.json()).resolves.toMatchObject({ code: "BAD_REQUEST" });
    expect(response.status).toBe(400);
  });
});
