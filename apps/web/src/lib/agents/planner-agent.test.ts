import { afterEach, describe, expect, it } from "vitest";

import { runPlannerAgent } from "./planner-agent";

const originalModelResponse = process.env.TEST_MODEL_RESPONSE;
const START_DATE = "2026-07-17";

function modelTask(index: number) {
  return {
    courseId: "cs101",
    topic: "二叉树与BST",
    action: "review",
    title: `复习二叉树 ${index}`,
    reason: "先复盘树结构错题",
    estimatedMin: 30,
  };
}

afterEach(() => {
  if (originalModelResponse === undefined) delete process.env.TEST_MODEL_RESPONSE;
  else process.env.TEST_MODEL_RESPONSE = originalModelResponse;
});

describe("Planner Agent 模型输出边界", () => {
  it("拒绝超过计划周期可安排数量的任务，避免单日总时长越界", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([modelTask(1), modelTask(2)]);

    await expect(
      runPlannerAgent("planner_test", "复习数据结构", 1, 30, START_DATE)
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
  });

  it("拒绝超过十项的模型任务数组而不是静默截断", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify(
      Array.from({ length: 11 }, (_, index) => modelTask(index + 1))
    );

    await expect(
      runPlannerAgent("planner_test", "复习数据结构", 14, 90, START_DATE)
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
  });

  it("拒绝超过既有字段上限的任务文本", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      { ...modelTask(1), title: "题".repeat(121) },
    ]);

    await expect(
      runPlannerAgent("planner_test", "复习数据结构", 7, 90, START_DATE)
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
  });

  it("任一任务结构非法时拒绝整份计划而不是返回残缺任务", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      modelTask(1),
      { ...modelTask(2), action: "unknown" },
    ]);

    await expect(
      runPlannerAgent("planner_test", "复习数据结构", 7, 90, START_DATE)
    ).rejects.toMatchObject({ code: "MODEL_INVALID_RESPONSE" });
  });

  it("使用客户端本地日期作为计划首日", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([modelTask(1)]);

    const plan = await runPlannerAgent(
      "planner_test",
      "复习数据结构",
      7,
      90,
      "2032-02-29"
    );

    expect(plan.tasks[0]?.date).toBe("2032-02-29");
  });

  it("接受目录中的初级会计正式 Topic 并生成可执行任务", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([{
      courseId: "acc101",
      topic: "会计要素与会计等式",
      action: "lesson",
      title: "复盘会计等式交易影响",
      reason: "基线诊断后先补齐交易分析",
      estimatedMin: 30,
    }]);

    const plan = await runPlannerAgent(
      "planner_test",
      "两周掌握初级会计实务基础",
      7,
      90,
      START_DATE,
      {
        stage: "本科二年级",
        weakTopics: ["会计要素与会计等式"],
        strongTopics: [],
        learningStyle: "图文结合",
        stats: { totalQuestions: 5, accuracy: 0.4, studyDays: 1 },
      }
    );

    expect(plan.tasks[0]).toMatchObject({
      courseId: "acc101",
      topic: "会计要素与会计等式",
      action: "lesson",
    });
  });
});
