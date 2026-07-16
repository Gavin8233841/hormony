import { afterEach, describe, expect, it } from "vitest";

import { runPlannerAgent } from "./planner-agent";

afterEach(() => {
  delete process.env.TEST_MODEL_RESPONSE;
});

describe("Planner Agent local start date", () => {
  it("uses the client local date as the first plan day", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      {
        courseId: "cs101",
        topic: "数组与线性表",
        action: "lesson",
        title: "学习数组与线性表",
        reason: "先补齐线性结构基础",
        estimatedMin: 45,
      },
      {
        courseId: "cs101",
        topic: "栈与队列",
        action: "practice",
        title: "练习栈与队列",
        reason: "用练习巩固受限线性结构",
        estimatedMin: 45,
      },
    ]);

    const plan = await runPlannerAgent(
      "demo",
      "复习数据结构",
      2,
      90,
      "2026-07-17"
    );

    expect(plan.tasks.map((task) => task.date)).toEqual([
      "2026-07-17",
      "2026-07-18",
    ]);
  });
});
