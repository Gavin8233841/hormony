import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { GET as getPlan, POST as generatePlan } from "./route";
import type { StudyPlan } from "@/lib/types";

const originalModelKey = process.env.MODEL_API_KEY;
const originalDeploymentMode = process.env.DEPLOYMENT_MODE;

describe("学习计划生命周期", () => {
  beforeEach(() => {
    delete process.env.MODEL_API_KEY;
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      { courseId: "cs101", topic: "二叉树与BST", action: "review", title: "复习二叉树", reason: "先复盘树结构错题", estimatedMin: 45 },
      { courseId: "cs101", topic: "图的表示与遍历", action: "practice", title: "完成章节练习", reason: "用遍历练习巩固搜索路径", estimatedMin: 30 },
    ]);
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

  it("应生成无状态计划并由客户端负责保存", async () => {
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
          startDate: "2032-02-29",
        }),
      })
    );
    const generated = (await generateResponse.json()) as StudyPlan;

    expect(generateResponse.status).toBe(200);
    expect(generated.tasks).toHaveLength(2);
    expect(generated.goal).toBe("两周复习数据结构");
    expect(generated.tasks[0]?.date).toBe("2032-02-29");
    expect(generated.tasks[0]).toMatchObject({
      courseId: "cs101",
      topic: "二叉树与BST",
      action: "review",
      type: "review",
      reason: "先复盘树结构错题",
    });
    expect(generated.agentTrace?.some((item) => item.includes("Planner Agent"))).toBe(true);
  });

  it("模型未配置时应返回明确 503", async () => {
    delete process.env.TEST_MODEL_RESPONSE;
    const response = await generatePlan(new Request("http://localhost/api/plan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ goal: "复习数据结构" }),
    }));
    await expect(response.json()).resolves.toMatchObject({ code: "MODEL_UNAVAILABLE" });
    expect(response.status).toBe(503);
  });

  it("模型生成计划未通过 Safety 时应返回明确 502", async () => {
    process.env.TEST_MODEL_RESPONSE = JSON.stringify([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        action: "review",
        title: "联系 13812345678 复习二叉树",
        reason: "输出包含敏感信息",
        estimatedMin: 45,
      },
    ]);
    const response = await generatePlan(new Request("http://localhost/api/plan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ goal: "复习数据结构" }),
    }));

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toMatchObject({ code: "SAFETY_BLOCKED" });
  });

  it("无状态部署不得从服务端读取计划", async () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    const response = await getPlan(new Request("http://localhost/api/plan?userId=demo"));
    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toMatchObject({ code: "ENDPOINT_DISABLED" });
  });
});
