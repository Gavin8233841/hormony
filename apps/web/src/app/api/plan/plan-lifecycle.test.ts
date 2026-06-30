import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { GET as getPlan, POST as generatePlan } from "./route";
import { PATCH as updateTask } from "./save/route";
import type { StudyPlan } from "@/lib/types";

const originalModelKey = process.env.MODEL_API_KEY;

describe("学习计划生命周期", () => {
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

  it("生成计划后应可读取并打卡任务", async () => {
    const userId = "plan_lifecycle_user";
    const generateResponse = await generatePlan(
      new Request("http://localhost/api/plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId,
          goal: "两周复习数据结构",
          durationDays: 14,
          dailyMinutes: 90,
        }),
      })
    );
    const generated = (await generateResponse.json()) as StudyPlan;

    expect(generateResponse.status).toBe(200);
    expect(generated.tasks.length).toBeGreaterThan(0);

    const getResponse = await getPlan(
      new Request(`http://localhost/api/plan?userId=${userId}`)
    );
    const fetched = (await getResponse.json()) as StudyPlan;
    expect(fetched.planId).toBe(generated.planId);

    const taskId = fetched.tasks[0].id;
    const patchResponse = await updateTask(
      new Request("http://localhost/api/plan/save", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, taskId, done: true }),
      })
    );
    const updated = (await patchResponse.json()) as StudyPlan;

    expect(patchResponse.status).toBe(200);
    expect(updated.tasks.find((task) => task.id === taskId)?.done).toBe(true);
  });

  it("不存在的任务不应返回成功", async () => {
    const response = await updateTask(
      new Request("http://localhost/api/plan/save", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: "demo",
          taskId: "missing_task_id",
          done: true,
        }),
      })
    );

    await expect(response.json()).resolves.toMatchObject({ code: "NOT_FOUND" });
    expect(response.status).toBe(404);
  });
});
