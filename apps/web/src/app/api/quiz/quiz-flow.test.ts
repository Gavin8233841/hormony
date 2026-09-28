import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { GET as getQuizData, POST as generateQuiz } from "./route";
import { POST as submitQuiz } from "./submit/route";
import { GET as getResources } from "../resources/route";
import type { QuizPackage } from "@/lib/types";

const originalModelKey = process.env.MODEL_API_KEY;
const originalDeploymentMode = process.env.DEPLOYMENT_MODE;
const originalModelResponseSequence = process.env.TEST_MODEL_RESPONSE_SEQUENCE;
const originalModelResponseSequenceScope = process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE;

function modelQuestion(index: number, tags: string[] = ["概念理解"]) {
  return {
    type: "choice",
    stem: `模型分批题 ${index}`,
    options: ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
    answer: "A",
    explanation: "这是测试环境中用于验证模型分批与修复的固定解析。",
    tags,
  };
}

describe("题库与资源 API 闭环", () => {
  beforeEach(() => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = JSON.stringify(Array.from({ length: 5 }, (_, index) => ({
      type: "choice",
      stem: `测试题 ${index + 1}`,
      options: ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
      answer: "A",
      explanation: "这是测试环境中的固定解析。",
      tags: ["概念理解"],
    })));
  });

  afterEach(() => {
    if (originalModelKey === undefined) {
      delete process.env.MODEL_API_KEY;
    } else {
      process.env.MODEL_API_KEY = originalModelKey;
    }
    delete process.env.TEST_MODEL_RESPONSE;
    if (originalModelResponseSequence === undefined) delete process.env.TEST_MODEL_RESPONSE_SEQUENCE;
    else process.env.TEST_MODEL_RESPONSE_SEQUENCE = originalModelResponseSequence;
    if (originalModelResponseSequenceScope === undefined) delete process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE;
    else process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = originalModelResponseSequenceScope;
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
    expect(quiz.questions[0].difficulty).toBe("medium");
    expect(quiz.questions[0].tags).toEqual(["概念理解"]);
    expect(quiz.grading).toHaveLength(5);
    expect(quiz.grading[0]).toMatchObject({ difficulty: "medium", tags: ["概念理解"] });
    expect(new Set(quiz.grading.slice(0, 4).map((item) => item.answer))).toEqual(new Set(["A", "B", "C", "D"]));
    quiz.questions.forEach((question, index) => {
      expect(question.options?.[quiz.grading[index].answer.charCodeAt(0) - 65]).toBe(
        `${quiz.grading[index].answer}. 选项一`
      );
    });
  });

  it("生成接口应把重点标签写入题目与评分标签", async () => {
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "api_focus_user",
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 5,
          difficulty: "medium",
          focusTag: "边界条件",
        }),
      })
    );
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.focusTag).toBe("边界条件");
    expect(quiz.questions).toHaveLength(5);
    expect(quiz.questions.every((question) => question.tags.includes("边界条件"))).toBe(true);
    expect(quiz.grading.every((item) => item.tags.includes("边界条件"))).toBe(true);
  });

  it("Web 生成测验后应可立即提交服务端评分", async () => {
    const generateResponse = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "api_submit_user",
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 5,
          difficulty: "medium",
        }),
      })
    );
    const quiz = (await generateResponse.json()) as QuizPackage;
    const submitResponse = await submitQuiz(
      new Request("http://localhost/api/quiz/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "api_submit_user",
          quizId: quiz.quizId,
          answers: quiz.questions.map((question, index) => ({
            questionId: question.id,
            userAnswer: question.options?.[quiz.grading[index].answer.charCodeAt(0) - 65] ?? "",
          })),
        }),
      })
    );
    const result = await submitResponse.json();

    expect(submitResponse.status).toBe(200);
    expect(result).toMatchObject({
      quizId: quiz.quizId,
      userId: "api_submit_user",
      totalQuestions: 5,
      correctCount: 5,
    });
    expect(result.details[0]).toMatchObject({ tags: ["概念理解"] });
  });

  it("模型未配置时应返回明确 503", async () => {
    delete process.env.TEST_MODEL_RESPONSE;
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树与BST",
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

  it("应接受 questions 包装、中文选项标号和答案正文", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify({
      questions: [{
        type: "choice",
        stem: "二叉搜索树中序遍历的结果通常具有什么特征？",
        options: ["A、升序序列", "B：随机序列", "C) 层序序列", "D．逆拓扑序列"],
        answer: "升序序列",
        explanation: "根据二叉搜索树左小右大的性质，中序遍历先访问左子树、根节点、右子树，因此结果通常是升序序列。",
        tags: ["BST性质"],
      }],
    });
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
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(1);
    expect(quiz.questions[0]).not.toHaveProperty("answer");
    expect(quiz.grading[0]).toMatchObject({ tags: ["BST性质"] });
    expect(quiz.questions[0].options?.[quiz.grading[0].answer.charCodeAt(0) - 65]).toBe(`${quiz.grading[0].answer}. 升序序列`);
  });

  it("应跳过坏题并继续收集后续有效题", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      {
        type: "choice",
        stem: "坏题",
        options: ["选项一", "选项二", "选项三", "选项四"],
        answer: "A",
        explanation: "缺少 A-D 前缀。",
      },
      {
        type: "choice",
        stem: "完全二叉树顺序存储中，下标为 i 的左孩子下标是什么？",
        options: ["A. 2i+1", "B. 2i+2", "C. i/2", "D. i-1"],
        answer: "A",
        explanation: "在 0 基址顺序存储中，完全二叉树节点 i 的左孩子下标为 2i+1，右孩子下标为 2i+2。",
        tags: ["公式应用"],
      },
    ]);
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
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(1);
    expect(quiz.questions[0].stem).toContain("完全二叉树");
    expect(quiz.grading[0]).toMatchObject({ tags: ["公式应用"] });
    expect(quiz.questions[0].options?.[quiz.grading[0].answer.charCodeAt(0) - 65]).toBe(`${quiz.grading[0].answer}. 2i+1`);
  });

  it("超过单批题量时应分批调用真实模型并合并结果", async () => {
    process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = "重点标签：分批生成";
    process.env.TEST_MODEL_RESPONSE_SEQUENCE = JSON.stringify([
      Array.from({ length: 5 }, (_, index) => modelQuestion(index + 1, ["分批生成"])),
      [modelQuestion(6, ["分批生成"])],
    ]);
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 6,
          difficulty: "medium",
          focusTag: "分批生成",
        }),
      })
    );
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(6);
    expect(quiz.grading).toHaveLength(6);
    expect(quiz.questions.map((question) => question.stem)).toEqual([
      "模型分批题 1",
      "模型分批题 2",
      "模型分批题 3",
      "模型分批题 4",
      "模型分批题 5",
      "模型分批题 6",
    ]);
  });

  it("模型首轮格式损坏时应调用真实模型修复 JSON", async () => {
    process.env.TEST_MODEL_RESPONSE_SEQUENCE_SCOPE = "重点标签：修复序列";
    process.env.TEST_MODEL_RESPONSE_SEQUENCE = JSON.stringify([
      "这不是 JSON，但描述了二叉树题目。",
      [modelQuestion(1, ["格式修复"])],
    ]);
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树与BST",
          count: 1,
          difficulty: "medium",
          focusTag: "修复序列",
        }),
      })
    );
    const quiz = (await response.json()) as QuizPackage;

    expect(response.status).toBe(200);
    expect(quiz.questions).toHaveLength(1);
    expect(quiz.grading[0]).toMatchObject({ tags: ["修复序列", "格式修复"] });
    expect(quiz.questions[0].options?.[quiz.grading[0].answer.charCodeAt(0) - 65]).toBe(`${quiz.grading[0].answer}. 选项一`);
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

  it("模型生成题目未通过 Safety 时应返回明确 502", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      type: "choice",
      stem: "联系 13812345678 判断二叉树性质",
      options: ["A. 选项一", "B. 选项二", "C. 选项三", "D. 选项四"],
      answer: "A",
      explanation: "输出包含敏感信息。",
      tags: ["概念理解"],
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
    await expect(response.json()).resolves.toMatchObject({ code: "SAFETY_BLOCKED" });
  });

  it("应拒绝不属于课程的近似主题", async () => {
    const response = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "二叉树",
          count: 1,
          difficulty: "medium",
        }),
      })
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ code: "INVALID_TOPIC" });
  });

  it("应拒绝缺失主题或跨课程主题", async () => {
    const missingTopicResponse = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          count: 1,
          difficulty: "medium",
        }),
      })
    );
    const crossCourseResponse = await generateQuiz(
      new Request("http://localhost/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          courseId: "cs101",
          topic: "进程与线程",
          count: 1,
          difficulty: "medium",
        }),
      })
    );

    expect(missingTopicResponse.status).toBe(400);
    await expect(missingTopicResponse.json()).resolves.toMatchObject({ code: "INVALID_TOPIC" });
    expect(crossCourseResponse.status).toBe(400);
    await expect(crossCourseResponse.json()).resolves.toMatchObject({ code: "INVALID_TOPIC" });
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
