import { afterEach, describe, expect, it, vi } from "vitest";

const ragMock = vi.hoisted(() => ({
  retrieve: vi.fn(() => [
    {
      id: "mock-knowledge-001",
      courseId: "cs101",
      source: "mock-source",
      text: "数组与线性表的课程资料",
      score: 0.9,
    },
  ]),
  formatContext: vi.fn((chunks: unknown[]) =>
    chunks.length > 0 ? "mock formatted course context" : ""
  ),
}));

vi.mock("@/lib/rag", () => ragMock);

import { orchestrate } from "./orchestrator";

afterEach(() => {
  delete process.env.TEST_MODEL_RESPONSE;
  ragMock.retrieve.mockClear();
  ragMock.formatContext.mockClear();
});

describe("orchestrator 前置检索调度", () => {
  it("计划意图不应执行通用前置检索", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      {
        courseId: "cs101",
        topic: "数组与线性表",
        action: "lesson",
        title: "学习数组与线性表",
        reason: "先补齐线性结构基础",
        estimatedMin: 45,
      },
    ]);

    const result = await orchestrate({
      userId: "demo",
      message: "帮我制定数据结构复习计划",
    });

    expect(result.intent).toBe("plan");
    expect(ragMock.retrieve).toHaveBeenCalledTimes(0);
  });

  it("无答题记录的评估意图不应执行通用前置检索", async () => {
    const result = await orchestrate({
      userId: "demo",
      message: "分析我的薄弱知识点",
    });

    expect(result.intent).toBe("evaluate");
    expect(ragMock.retrieve).toHaveBeenCalledTimes(0);
  });

  it("测验意图只应由 Quiz Agent 执行一次主题检索", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify(
      Array.from({ length: 5 }, (_, index) => ({
        type: "choice",
        stem: `数组题目 ${index + 1}`,
        options: ["A. 正确选项", "B. 干扰项", "C. 干扰项", "D. 干扰项"],
        answer: "A",
        explanation: "依据课程资料可判断 A 正确。",
        tags: ["概念理解"],
      }))
    );

    const result = await orchestrate({
      userId: "demo",
      message: "围绕数组与线性表出题",
      context: { courseId: "cs101" },
    });

    expect(result.intent).toBe("quiz");
    expect(ragMock.retrieve).toHaveBeenCalledTimes(1);
    expect(ragMock.retrieve).toHaveBeenCalledWith("围绕数组与线性表出题", "cs101", 5);
  });
});
