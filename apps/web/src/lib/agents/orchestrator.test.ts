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
  formatContext: vi.fn((chunks: unknown[]): string =>
    chunks.length > 0 ? "mock formatted course context" : ""
  ),
}));

vi.mock("@/lib/rag", () => ragMock);

import { orchestrate, orchestrateStream, orchestrateTutorOnly } from "./orchestrator";
import type { StreamEvent } from "@/lib/types";

afterEach(() => {
  delete process.env.TEST_MODEL_RESPONSE;
  ragMock.retrieve.mockClear();
  ragMock.formatContext.mockClear();
});

describe("orchestrator 前置检索调度", () => {
  it("小艺流式讲解固定进入 Tutor，不由计划和测验关键词改道", async () => {
    process.env.TEST_MODEL_RESPONSE = "数组通过连续存储位置保存元素。";
    const events: StreamEvent[] = [];
    await orchestrateStream({
      userId: "xiaoyi_guest", message: "解释数组并给我出题和学习计划", startDate: "2026-09-27",
    }, (event) => events.push(event), undefined, "tutor");

    expect(events).toContainEqual({ type: "thinking", agent: "Tutor" });
    expect(events.some((event) => event.type === "thinking" &&
      (event.agent === "Planner" || event.agent === "Quiz"))).toBe(false);
    expect(events).toContainEqual({ type: "delta", content: "数组通过连续存储位置保存元素。" });
  });

  it("外部讲解入口即使遇到计划、出题和成绩关键词也只调用 Tutor", async () => {
    process.env.TEST_MODEL_RESPONSE = "线性表按逻辑顺序组织元素，数组是常见的顺序存储方式。";

    const result = await orchestrateTutorOnly({
      userId: "external_guest",
      message: "解释数组与线性表的计划、出题和成绩评估分别是什么意思",
      startDate: "2026-09-27",
      courseId: "cs101",
      topic: "数组与线性表",
    });

    expect(result.intent).toBe("tutor");
    expect(result.agentResults.map((item) => item.agent)).toEqual([
      "Profile", "Retrieval", "Tutor", "Safety",
    ]);
    expect(result.safetyPassed).toBe(true);
    expect(result.action).toMatchObject({ kind: "lesson", courseId: "cs101", topic: "数组与线性表" });
  });

  it("已提交的具体作答优先进入 Evaluator，并给出可执行练习", async () => {
    process.env.TEST_MODEL_RESPONSE = "学生混淆了遍历访问顺序，应先演练队列变化。";
    const events: StreamEvent[] = [];
    await orchestrateStream({
      userId: "demo", message: "请解释这道题", startDate: "2026-09-25",
      context: { courseId: "cs101", topic: "图的表示与遍历", question: "BFS 的访问顺序？",
        userAnswer: "深度优先", correctAnswer: "广度优先", submitted: true },
    }, (event) => events.push(event));

    expect(events).toContainEqual({ type: "thinking", agent: "Evaluator" });
    expect(events).toContainEqual({ type: "action", action: {
      kind: "practice", courseId: "cs101", topic: "图的表示与遍历",
      title: "练习图的表示与遍历", reason: "再做一组本主题练习，检查刚才的错因",
    } });
    expect(events.at(-1)).toMatchObject({ type: "done" });
  });

  it("未提交题目只给提示，不进入评估或引用正确答案", async () => {
    process.env.TEST_MODEL_RESPONSE = "先观察队列中最早进入的节点。";
    const events: StreamEvent[] = [];
    await orchestrateStream({
      userId: "demo", message: "给我一个提示", startDate: "2026-09-25",
      context: { courseId: "cs101", topic: "图的表示与遍历", question: "BFS 下一步访问谁？",
        userAnswer: "节点 C", submitted: false },
    }, (event) => events.push(event));

    expect(events).toContainEqual({ type: "thinking", agent: "Tutor" });
    expect(events.some((event) => event.type === "thinking" && event.agent === "Evaluator")).toBe(false);
    expect(events).toContainEqual({ type: "action", action: expect.objectContaining({ kind: "lesson" }) });
  });
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
      startDate: "2026-07-17",
    });

    expect(result.intent).toBe("plan");
    expect(ragMock.retrieve).toHaveBeenCalledTimes(0);
  });

  it("无答题记录的评估意图不应执行通用前置检索", async () => {
    const result = await orchestrate({
      userId: "demo",
      message: "分析我的薄弱知识点",
      startDate: "2026-07-17",
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
      startDate: "2026-07-17",
      context: { courseId: "cs101" },
    });

    expect(result.intent).toBe("quiz");
    expect(ragMock.retrieve).toHaveBeenCalledTimes(1);
    expect(ragMock.retrieve).toHaveBeenCalledWith("围绕数组与线性表出题", "cs101", 5);
  });

  it("Tutor 应拒绝检索层意外返回的跨课程切片", async () => {
    ragMock.retrieve.mockReturnValueOnce([{
      id: "cross-course-chunk",
      courseId: "cs102",
      source: "操作系统课程资料",
      text: "进程调度算法决定就绪进程的运行顺序。",
      score: 0.9,
    }]);

    await expect(orchestrate({
        userId: "demo",
        message: "解释二叉树",
        startDate: "2026-07-17",
        context: { courseId: "cs101" },
      }))
      .rejects.toMatchObject({ name: "RetrievedChunkContractError" });

    expect(ragMock.formatContext).not.toHaveBeenCalled();
  });

  it("流式 trace 只应公开检索条数而非 RAG 正文", async () => {
    const privateContext = "INTERNAL_RAG_CONTEXT：数组与线性表的课程资料";
    process.env.TEST_MODEL_RESPONSE = "数组是按顺序存储的数据结构。";
    ragMock.formatContext.mockReturnValueOnce(privateContext);
    const events: StreamEvent[] = [];

    await orchestrateStream({
      userId: "demo",
      message: "解释数组",
      startDate: "2026-07-17",
      context: { courseId: "cs101" },
    }, (event) => events.push(event));

    expect(events).toContainEqual({
      type: "trace",
      agent: "Retrieval",
      content: "已完成课程资料检索（1 条）",
    });
    expect(JSON.stringify(events)).not.toContain(privateContext);
  });

  it("检索结果未通过 Safety 时不得进入 Tutor 或泄露到流", async () => {
    const unsafeContext = "PRIVATE_RAG_PAYLOAD：暴力伤害他人的具体步骤";
    ragMock.retrieve.mockReturnValueOnce([{
      id: "unsafe-course-chunk",
      courseId: "cs101",
      source: "数据结构课程资料",
      text: unsafeContext,
      score: 0.9,
    }]);
    ragMock.formatContext.mockReturnValueOnce(unsafeContext);
    const events: StreamEvent[] = [];

    await orchestrateStream({
      userId: "demo",
      message: "解释二叉树",
      startDate: "2026-07-17",
      context: { courseId: "cs101" },
    }, (event) => events.push(event));

    expect(JSON.stringify(events)).not.toContain("PRIVATE_RAG_PAYLOAD");
    expect(events.slice(-2)).toEqual([
      {
        type: "error",
        code: "SAFETY_BLOCKED",
        message: "本次回答未通过安全检查，请调整问题后重试。",
      },
      { type: "done", sessionId: expect.any(String) },
    ]);
    expect(events.some((event) => event.type === "delta")).toBe(false);
  });
});
